*************************************************************************************
/*       1. Program: Jet fuel taxes						              			 */
*************************************************************************************

/*Fukui, Hideki and Miyoshi, Chikage. 
"The impact of aviation fuel tax on fuel consumption and carbon emissions: The case of the US airline industry."
Transportation Research Part D: Transport and Environment 50 (January 2017): 234--253.
*/

display `"All the arguments, as typed by the user, are: `0'"'

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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************
if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "${spec_type}" == "current"{
	local dollar_year = ${today_year}
}

global value_local_jet_fuel 	no


****************************************************
/* 4. Calculate Annual Emissions per Gallon of Jet Fuel */
****************************************************
preserve 

	* Save local emissions and markup for later.
	import excel "${policy_assumptions}", first clear sheet("aviation_local_emissions")
	tempfile local_damages
	save "`local_damages'", replace		
	
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear	
	qui sum pct_markup if year == `dollar_year'
	local pct_markup = r(mean)
	
		
	* Save upstream emissions for later. 
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear
		keep if year == `dollar_year'
	
	ds *upstream*
	foreach var in `r(varlist)' {
		di in red "var is `var'"
		local name_ind = substr("`var'", 1, 3)
		di in red "name index is `name_ind'"
		if "`name_ind'" == "wtp" {
			
			local `var' = `var'
			
		}
		
		else {
			
			local name_ind = substr("`var'", 1, strlen("`var'") - strlen("_upstream"))
			local name_ind = substr("`name_ind'", strpos("`name_ind'", "_") + 1, .) + "_" + substr("`name_ind'", 1, strpos("`name_ind'", "_") - 1)
			
			local wtp_upstream_`name_ind' = `var'
						
		}
	
	}
	
	* Calculate average state tax on jet fuel.
	import excel "${policy_assumptions}", first clear sheet("state_jet_fuel_taxes")
		replace rate = "0" if rate == "X"
		destring rate, replace
	collapse (mean) rate [aw = consumption]
		local state_avg_jet_fuel_tax = rate // Add to federal tax rate.

	
	* Calculate total annual gallons of jet fuel consumed. 
	import excel "${policy_assumptions}", first clear sheet("aviation_prices")

	sum jet_fuel_price if year == `dollar_year'
		local consumer_price = r(mean)
	sum jet_fuel_tax if year == `dollar_year'
		local tax_rate = r(mean) + `state_avg_jet_fuel_tax' // NOT inflation adjusting since fuel taxes typically not indexed.
		
	
	*  Want to Consider Local Emissions.
	replace jet_fuel_quantity = jet_fuel_quantity * 1000 * 42	
	replace aviation_gas_quantity = aviation_gas_quantity * 1000 * 42
	// Both denoted in thousands of barrels produced for a given year. Converting to total gallons.
	
	gen jet_fuel_share = jet_fuel_quantity / (jet_fuel_quantity + aviation_gas_quantity)
	
	merge 1:1 year using "`local_damages'", keep(3) nogen
	if "${spec_type}" == "baseline" {
		keep if year == 2014 // Closest year in NEI to baseline year.
	}	
	if "${spec_type}" == "current" {
		keep if year == `dollar_year'
	}
			
	ds *_st
	foreach var in `r(varlist)' {
		
		replace `var' = ((`var'*0.907185)/jet_fuel_quantity) * jet_fuel_share
	
		// 1. Converting from short tons to metric tons. All 5 local pollutants reported in short tons. 
		// 2. Divide by gallons of jet fuel consumed to get avg. emissions per gallon burned
		// 3. Assuming emissions b/w aviation gas and jet fuel proportional to gallons consumed. Multiply by share jet fuel.
		local newname = substr("`var'", 1, strlen("`var'") - 3)
		rename `var' `newname'_mt
		
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

	
	* Calculate WTP for In-Air Pollution
	drop *quantity
	ds aviation_*
	foreach var in `r(varlist)' {
		
		local unit_check = substr("`var'", (strlen("`var'") - 1), .)
			assert "`unit_check'" == "mt"
			
		local p_name = substr(substr("`var'", 10, .), 1, strpos(substr("`var'", 10, .), "_") - 1)
			
		if "`p_name'" == "VOC" | "`p_name'" == "CO" {
			
			gen wtp_`p_name'_local = `var'*`social_cost_`p_name'_uw'
			gen wtp_`p_name'_global = `var'*(${`p_name'_gwp}*`social_cost_CO2')

		}			
		else {
			
			if !inlist("`p_name'", "CH4", "N2O") {
		
				gen wtp_`p_name' = `var' * `social_cost_`p_name'_uw'
				
			}
			else {
				
				gen wtp_`p_name' = `var' * `social_cost_`p_name''			
				
			}
			
		}
		
		drop `var'
		
	}
			
	* Add Upstream Emissions on top of In-Air Emissions. 
	ds wtp*
	foreach var in `r(varlist)' {
		
		local p = substr("`var'", 5, .)
		di in red "p is `p'"
		di in red "wtp upstream `p' is `wtp_upstream_`p''"
			
		replace `var' = `var' + `wtp_upstream_`p''
			
	}
	
	gen wtp_CO2 = ((9752.236 / 1000000) * `social_cost_CO2')  + `wtp_upstream_CO2' // EIA (2023b), Carbon Dioxide Emissions Coefficients, Technical report, US Energy Information Administration
	gen wtp_SO2 = (((600 * 0.00305672062)/1000000) * `social_cost_SO2_uw') + `wtp_upstream_SO2' // sulfur concentration to SO2 per gallon
	
	/* 1 ppm =  Assume 600ppm, and assume density of 807.5 kg/m^3 for jet fuel.
	https://lae.mit.edu/2012/03/01/study-released-on-the-costs-and-benefits-of-desulfurizing-jet-fuel/ */
	
	gen wtp_N2O = `wtp_upstream_N2O'
	gen wtp_CH4 = `wtp_upstream_CH4'
	gen wtp_NH3 = `wtp_upstream_NH3'
	
	if "${value_local_jet_fuel}" == "no" {
		
		replace wtp_CO_local = `wtp_upstream_CO_local'
		replace wtp_CO_global = `wtp_upstream_CO_global'
		replace wtp_NOx = `wtp_upstream_NOx'
		replace wtp_PM25 = `wtp_upstream_PM25'
		replace wtp_VOC_local = `wtp_upstream_VOC_local'
		replace wtp_VOC_global = `wtp_upstream_VOC_global'
		replace wtp_SO2 = `wtp_upstream_SO2'
		
	}	
	

	local soc_l = wtp_CO_local + wtp_VOC_local + wtp_NOx + wtp_PM25 + wtp_SO2 + wtp_NH3
	local soc_g = wtp_CO_global + wtp_VOC_global + wtp_CO2 + wtp_CH4 + wtp_N2O
	
	di in red `wtp_upstream_CO_local' + `wtp_upstream_CO_global' + `wtp_upstream_NOx' + `wtp_upstream_PM25' + `wtp_upstream_VOC_local' + `wtp_upstream_VOC_global' + `wtp_upstream_SO2' + `wtp_upstream_CO2' + `wtp_upstream_CH4' + `wtp_upstream_N2O' + `wtp_upstream_NH3'
	
	di in red `soc_l' + wtp_CO_global + wtp_VOC_global + wtp_CH4 + wtp_N2O + `wtp_upstream_CO2'
	
	di in red (`soc_l' + (`soc_g'* (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))/`consumer_price'
		
	di in red ((9752.236 / 1000000) * `social_cost_CO2')	
		
	ds wtp*
	egen sum_check = rowtotal( `r(varlist)' )
		assert round(`soc_l' + `soc_g', 0.1) == round(sum_check, 0.1)
			drop sum_check	
		
restore
	
****************************************************
/* 5. Calculate Components */
****************************************************
local semi_e_demand_jet_tax = `e_demand_jet_fuel'/`consumer_price'


local wtp_soc_g = `soc_g' * `semi_e_demand_jet_tax'
					
local wtp_soc_l = `soc_l' * `semi_e_demand_jet_tax' 

	local wtp_soc = `wtp_soc_l' + `wtp_soc_g'

	
local semi_e_producer_prices_tax = 0 // Assuming = 0.
local wtp_consumers = 1 + (1 +`tax_rate')*`semi_e_producer_prices_tax'

* Producers
local wtp_producers = -(`consumer_price'*`pct_markup')*`semi_e_demand_jet_tax'*(1 - ${gasoline_effective_corp_tax})
// 	assert `wtp_producers' >= 0
local fisc_ext_prod = (`consumer_price'*`pct_markup')*`semi_e_demand_jet_tax'*(${gasoline_effective_corp_tax})
// 	assert `fisc_ext_prod' <= 0

	
if "${value_profits}" == "no" {
	
	local wtp_producers = 0 // Includes utilities and gas companies' profits. 
	local fisc_ext_prod = 0
	
}

local total_WTP = `wtp_consumers' + (`wtp_soc_g'* (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_l' + `wtp_producers'	

local WTP_USPres = `wtp_consumers' + `wtp_producers' + `wtp_soc_l' 
local WTP_USFut = `wtp_soc_g' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (1-(${USShareFutureSSC})) * `wtp_soc_g' 

**************************
/* 6. MVPF Calculations */
**************************
local program_cost = 1
local fiscal_externality_tax = (`tax_rate' * `semi_e_demand_jet_tax') + `fisc_ext_prod'

local fiscal_externality_subsidy = 0
local fiscal_externality_lr = -`wtp_soc_g' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_lr' + `fiscal_externality_subsidy' 

local p_spend = `program_cost' + `fiscal_externality_tax'
local MVPF = `total_WTP'/`total_cost'

****************************************
/* 7. Cost-Effectiveness Calculations */
****************************************
local q_carbon_mck = ((`wtp_soc_g') / ${sc_CO2_`dollar_year'}) / `semi_e_demand_jet_tax'
di in red "consumer price is `consumer_price'"
local jet_fuel_markup = `consumer_price'*`pct_markup'
di in red "jet fuel markup is `jet_fuel_markup'"
di in red "tax rate is `tax_rate'"
local resource_cost = 0.92 * `consumer_price' - `jet_fuel_markup' - `tax_rate' //economy-wide 8% markup from De Loecker et al. (2020)
di in red "resource cost is `resource_cost'"

local resource_ce = -`resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"
di in red "consumer price is `consumer_price'"
di in red "carbon is `q_carbon_mck'"

local resource_cost = -`consumer_price'
local gov_carbon = `wtp_soc_g' / ${sc_CO2_`dollar_year'}


**************************
/* 8. Output */
**************************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `total_WTP'

global wtp_soc_`1' = `wtp_soc_l' + (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global wtp_loc_`1' = `wtp_soc_l'
global wtp_glob_`1' = (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))

global wtp_cons_`1' = `wtp_consumers'

global wtp_prod_s_`1' = `wtp_producers'

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fiscal_externality_tax'
global fisc_ext_s_`1' = `fiscal_externality_subsidy'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global cost_`1' = `total_cost'

global q_CO2_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'}) * -1
global q_CO2_no_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'}) * -1
global q_CO2_mck_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'})/`semi_e_demand_jet_tax'
global q_CO2_mck_no_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'})/`semi_e_demand_jet_tax'
global resource_cost_`1' = `consumer_price'
global cost_wtp_`1' = -0
global env_cost_wtp_`1' = -0	
global env_cost_wtp_local_`1' = -0
global env_cost_wtp_global_`1' = -0

global wtp_prod_`1' = `wtp_producers'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'
global semie_`1' = `semi_e_demand_jet_tax'


if "${value_profits}" == "no" {

	global wtp_prod_`1' = 0 
		global wtp_prod_s_`1' = 0
		global wtp_prod_u_`1' = 0
}


di in red `tax_rate'* `semi_e_demand_jet_tax'
di in red `consumer_price'
