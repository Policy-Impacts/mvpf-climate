*************************************************************
/* 1. Program: E85 fuel taxes									 */
*************************************************************
/*
Anderson, Soren T.
"The demand for ethanol as a gasoline substitute." March 2012.
Journal of Environmental Economics and Management 63(2): 151--168.
*/
*********************************
/* 2. Estimates from Paper */
*********************************
/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates. */

if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
*	if ${draw_number} ==1 {
		preserve
			use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
			qui ds draw_number, not 
			global estimates_${name} = r(varlist)
			
			mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
		restore
*	}
	local ests ${estimates_${name}}
	foreach var in `ests' {
		matrix temp = draws_${name}["${draw_number}", "`var'"]
		local `var' = temp[1,1]
	}
}
if "`bootstrap'" == "no" {
	preserve
		
qui import excel "${code_files}/2a_causal_estimates_papers/${folder_name}/${name}.xlsx", clear sheet("wrapper_ready") firstrow		

levelsof estimate, local(estimates)
		foreach est in `estimates' {
			su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}
if "`bootstrap'" == "pe_ci" {
	preserve
		use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}_ci_pe.dta", clear
		
levelsof estimate, local(estimates)


		foreach est in `estimates' {
			sum ${val} if estimate == "`est'"
			local `est' = r(mean)
		}
	restore 
}

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "${spec_type}" == "current"{
	local dollar_year = ${today_year}
}

* Social Costs. 
local ghg CO2 CH4 N2O
foreach g of local ghg {
	
	local social_cost_`g' = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
		
}	

local md_u SO2 PM25 NOx VOC NH3 CO
foreach p of local md_u  {
	
	local social_cost_`p'_uw = ${md_`p'_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
	
}

// Transform reported point estimate to price elasticity.
local e_demand_ethanol = (`ethanol_response' / 10) * ((0.10 / 2.37)^(-1))
// Author reports a $0.10 increase in price of ethanol leads to a 16.22% decrease (`ethanol_response') in quantity demanded.
// Translate $0.10 increase to percent change using author's sample average retail E85 price, $2.37, to calculate elasticity.

*********************************
/* 3. Calculate Price Difference b/w Gasoline and E85 */
*********************************
preserve

	import excel "${policy_assumptions}", first clear sheet("e85_prices")
		gen year = year(date)
		gen month = month(date)
	
	merge 1:1 month year using "${gas_price_data}/gas_data_monthly", keep(3) nogen	
		sort date
	collapse (mean) *_price pct_markup avg_tax_rate [aw=gas_consumption], by(year)
	
	keep if year == `dollar_year'
		local ethanol_price = e85_price
		
restore	

*********************************
/* 4. Adjust Per-Gallon Gasoline Externality for E85 */
*********************************
preserve

	* Save Ethanol Assumptions.
	import excel "${policy_assumptions}", first clear sheet("ethanol_assumptions")
		levelsof(parameter), local(parameter_loop)
		foreach p of local parameter_loop {
			
			qui sum value if parameter == "`p'"
				local `p' = r(mean)
			
		}

	* Bring in baseline, average gasoline externalities without including ethanol effects.
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear
		keep if year == `dollar_year'
			drop wtp_upstream_VOC wtp_upstream_CO wtp_VOC wtp_CO
		
	*********************************
	/* 4a. Adjust MPG. */
	*********************************
	local gas_mpg = mpg
	replace mpg = mpg * (1 - `ethanol_mpg_penalty')
			
	************************************************************
	/* 4b. Adjust On-Road CO2 Emissions for Ethanol Content. */
	************************************************************	
	replace wtp_CO2 = (wtp_CO2 * (1 - `share_ethanol_fuel')) + (`share_ethanol_fuel'*`ethanol_CO2_factor'*`social_cost_CO2')
	/* For on-road CO2 and SO2 emissions, we assume emissions are proportional to the share of fuel that remains gasoline. Since E85
	   fuel is 17% gasoline and 83% ethanol, we scale CO2 and SO2 emissions down by 0.17 */
	  	   
	*************************************************************
	/* 4c. Adjust On-Road Local Emissions for Ethanol Content. */
	*************************************************************	
	local local_adj			NOx CO VOC
	foreach p of local local_adj {
		
		if inlist("`p'", "VOC", "CO") {
			
			replace local_`p' = (local_`p' * (1 + ``p'_change_e85') * (`share_ethanol_fuel' / 0.801)) // Tests used fuel w/ 80.1% ethanol, not 83% in E85.
			replace global_`p' = (global_`p' * (1 + ``p'_change_e85') * (`share_ethanol_fuel' / 0.801)) // Tests used fuel w/ 80.1% ethanol, not 83% in E85.
			
		}
		
		if !inlist("`p'", "VOC", "CO") {
			
			replace wtp_`p' = (wtp_`p' * (1 + ``p'_change_e85') * (`share_ethanol_fuel' / 0.801))  
			
		}
		
	}
			   	   
	*************************************************************
	/* 4d. Adjust Upstream Emissions for Ethanol Share. */
	*************************************************************		
	ds *upstream* wtp_CH4 wtp_N2O
	foreach var in `r(varlist)' {
		
		replace `var' = `var' * (1 - `share_ethanol_fuel')
		
	}
	replace wtp_upstream_CO2 = wtp_upstream_CO2 + (((`upstream_CO2_intensity_`dollar_year'' + `luc_CO2_intensity')/1000000)*`mj_per_gal_ethanol'*`social_cost_CO2'*`share_ethanol_fuel')
	/* A gallon of E85 contains ~17% gasoline. Upstream emissions associated with producing a gallon of ethanol should therefore be
	   proportional to the amount of gasoline needed to produce the gallon of E85 fuel. */	
	  	   
	*************************************************************
	/* 4e. Compare Externalities. */
	*************************************************************
	gen fuel_type = "Ethanol"
		order fuel_type
	
	// Average externality from gallon of gasoline, accounting for share ethanol. 
	append using "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta"
		keep if year == `dollar_year'
			replace fuel_type = "Gasoline" if fuel_type != "Ethanol"
	assert _N == 2		
	drop wtp_total wtp_global wtp_local wtp_upstream_VOC wtp_upstream_CO wtp_VOC wtp_CO CO2_total share_ethanol
		
	// Checking unadjusted components sum.
	assert wtp_PM25_exhaust[1] == wtp_PM25_exhaust[2]
	assert wtp_SO2[1] == wtp_SO2[2]
	
	drop wtp_accidents wtp_congestion wtp_PM25_TBW // Assuming same VMT.
		
	local resum    CO VOC
	foreach p of local resum {
		
		gen wtp_`p' = local_`p' + global_`p' + local_`p'_upstream + global_`p'_upstream
 		
	}
	
	// Calculate Total WTP, and Local / Global WTP
	gen wtp_local = 0
	foreach val of global damages_local {
					
		if "`val'" == "NOx" | "`val'" == "SO2" {
				
			replace wtp_local = wtp_local + wtp_`val' + wtp_upstream_`val'
				
		}
			
		if "`val'" == "PM25" {
				
			replace wtp_local =	wtp_local + wtp_upstream_`val' + wtp_`val'_exhaust // Do NOT want to include driving externalities.
				
		}
			
		if "`val'" == "NH3" {
				
			replace wtp_local =	wtp_local + wtp_upstream_`val' 
				
		}
			
		if "`val'" == "local_VOC"| "`val'" == "local_CO" {
				
			replace wtp_local =	wtp_local + `val' + `val'_upstream
				
		}

		if "`val'" == "accidents" | "`val'" == "congestion" {
				
			replace wtp_local = wtp_local // Do NOT want to include driving externalities.
				
		}	
	}

	gen wtp_global = 0 
	foreach val of global damages_global {
			
		if !inlist("`val'", "global_VOC", "global_CO") {
				
			replace wtp_global = wtp_global + wtp_`val' + wtp_upstream_`val'
				
		}
		else {
				
			replace wtp_global = wtp_global + `val' + `val'_upstream
				
		}
		
	}

	assert round(wtp_local[2], 0.001) == round(${gas_ldv_ext_local_no_vmt_`dollar_year'}, 0.001)
	assert round(wtp_global[2], 0.001) == round(${gas_ldv_ext_global_`dollar_year'}, 0.001)
	
	gen wtp_total = wtp_local + wtp_global
	keep fuel_type year mpg wtp_total wtp_local wtp_global
	
	di in red wtp_total[1]
	di in red wtp_global[1]
	di in red wtp_local[1]
		
	*************************************************************
	/* 4f. Adjust Quantity Differences and Compare. */
	*************************************************************
	gen price = .
		replace price = ${nominal_gas_price_`dollar_year'} if fuel_type == "Gasoline"
		replace price = `ethanol_price' if fuel_type == "Ethanol"	
	gen spending = price
		
	gen tax = ${nominal_gas_tax_`dollar_year'} 
	gen markup = price * (${nominal_gas_markup_`dollar_year'} / ${nominal_gas_price_`dollar_year'}) // Assume same pct markup b/w E85 and gasoline.
		di in red "Markup Pct is ${nominal_gas_markup_`dollar_year'} / ${nominal_gas_price_`dollar_year'}"
		
	ds wtp* spending tax markup
	foreach var in `r(varlist)' {
		
		assert fuel_type == "Gasoline" if _n == 2
		
		local old_var = `var'[1]
		
		replace `var' = `var' * (mpg[2] / mpg[1]) if _n == 1
			assert round(`old_var' / (1 - `ethanol_mpg_penalty'), 0.0001) == round(`var', 0.0001) if _n == 1
		
	}
	
	local soc_l = (wtp_local[1] - wtp_local[2]) 
	local soc_g = (wtp_global[1] - wtp_global[2]) 
	
		di in red `soc_l'
		di in red `soc_g'
		di in red `soc_l' + `soc_g'
			
		di in red "Per-Dollar"
		di in red (`soc_l' + `soc_g') / price[1]
						
	local tax_difference = tax[1] - tax[2]	
		di in red `tax_difference'
		di in red `tax_difference' / `ethanol_price'
		assert `tax_difference' > 0
	local markup_difference = markup[1] - markup[2]
		di in red `markup_difference'
		di in red `markup_difference' / `ethanol_price'
		assert `markup_difference' > 0 
				
restore		
		
****************************************************
/* 5. Calculate Components */
****************************************************
local semi_e_demand_ethanol = `e_demand_ethanol' / `ethanol_price' 
	assert `semi_e_demand_ethanol' < 0
	// Elasticity from the fact that a $0.10 increase in price differential leads to a 16.2% decline in ethanol consumption. 

local wtp_soc_global = `soc_g' * `semi_e_demand_ethanol'
local wtp_soc_local = `soc_l' * `semi_e_demand_ethanol' 
	local wtp_soc = `wtp_soc_local' + `wtp_soc_global'
		assert round(`wtp_soc', 0.01) == round(`wtp_soc_local' + `wtp_soc_global', 0.01)
		assert `wtp_soc' >= 0 // Positive WTP since ethanol is cleaner than gasoline in our analysis.
	
local wtp_consumers = 1

* Producers
local wtp_producers = -(`markup_difference')*`semi_e_demand_ethanol'*(1 - ${gasoline_effective_corp_tax})
	assert `wtp_producers' >= 0 
	/* Producers want you to remove the tax b/c they benefit from people consuming more gallons of E85;
	   same percent markup on E85 and gasoline, but E85 requires more ethanol consumed to travel same distance. 
	   Price of E85 also higher. */
	
local fisc_ext_prod = (`markup_difference')*`semi_e_demand_ethanol'*(${gasoline_effective_corp_tax})
	assert `fisc_ext_prod' <= 0 // Lowers cost to government removing tax b/c gain revenue from 
	
	
if "${value_profits}" == "no" {
	
	local wtp_producers = 0 // Includes utilities and gas companies' profits. 
	local fisc_ext_prod = 0
	
}

local total_WTP = `wtp_consumers' + (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_local' + `wtp_producers'	
	di in red `total_WTP'

local WTP_USPres = `wtp_consumers' + `wtp_producers' + `wtp_soc_local' 
local WTP_USFut = `wtp_soc_global' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (1-(${USShareFutureSSC})) * `wtp_soc_global' 

**************************
/* 6. MVPF Calculations */
**************************

local program_cost = 1
	local fiscal_externality_lr = `wtp_soc_global' * (${USShareFutureSSC} * ${USShareGovtFutureSCC})
		assert `fiscal_externality_lr' >= 0
		
	local fiscal_externality_tax = (`tax_difference' * `semi_e_demand_ethanol') + `fisc_ext_prod'
		assert (`tax_difference' * `semi_e_demand_ethanol') <= 0
		assert `fisc_ext_prod' <= 0
		
		di in red (`tax_difference' * `semi_e_demand_ethanol')
		di in red `fisc_ext_prod'
		
		di in red `wtp_soc_global'
		di in red `fiscal_externality_lr' 			
	
local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_lr'

local MVPF = `total_WTP'/`total_cost'
di in red "`MVPF'"

	assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW')/`total_cost', 0.1) == round(`MVPF', 0.1)	

*********************************
/* 7. Save Results and Waterfalls */
*********************************
global MVPF_`1' = `MVPF'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `total_WTP'

global wtp_soc_`1' = `wtp_soc_local' + (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	global wtp_soc_l_`1' = `wtp_soc_local'
	global wtp_soc_g_`1' = (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
		
 
global wtp_cons_`1' = `wtp_consumers'

global wtp_prod_`1' = `wtp_producers'
	global wtp_prod_s_`1' = `wtp_producers'
	global wtp_prod_u_`1' = 0

if "${value_profits}" == "no" {

	global wtp_prod_`1' = 0 
		global wtp_prod_s_`1' = 0
		global wtp_prod_u_`1' = 0
}

assert round(${wtp_prod_`1'}, 0.001) == round(${wtp_prod_u_`1'} + ${wtp_prod_s_`1'}, 0.001)

assert round(${WTP_`1'}, 0.0001) == ///
		round(${wtp_cons_`1'} + ${wtp_prod_`1'} + ${wtp_soc_`1'}, 0.0001) 


global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fiscal_externality_tax'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global cost_`1' = `total_cost'

assert round(${cost_`1'}, 0.0001) == round(${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_lr_`1'}, 0.0001)
assert round(${MVPF_`1'}, 0.0001) == round(${WTP_`1'}/${cost_`1'}, 0.0001)