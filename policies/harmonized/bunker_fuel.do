*************************************************************
/* 1. Program: Bunker fuel taxes									 */
*************************************************************
/*
Mundaca, Gabriela, Jon Strand, and Ian R. Young.
"Carbon pricing of international transport fuels: Impacts on carbon emissions and trade activity."
Journal of Environmental Economics and Management 110 (October 2021).
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


local low_high_toggle 			low // Choose whether to use low or high elasticity estimate.
local value_local_bunker_fuel 	no // Choose whether to value local pollutants.


if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	
	local dollar_year = ${policy_year}
	
}
if "`4'" == "current"{
	
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

*********************************
/* 3. Calculate Emission Rates */
*********************************
preserve

	* Save upstream emissions and markup for later.
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
	qui sum pct_markup if year == `dollar_year'
		local pct_markup = r(mean)
		
	 
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear		
	keep if year == `dollar_year'	

	ds *upstream*
	foreach var in `r(varlist)' {
		
		local name_ind = substr("`var'", 1, 3)
		if "`name_ind'" == "wtp" {
			
			local `var' = `var'
			
		}
		
		else {
			
			local name_ind = substr("`var'", 1, strlen("`var'") - strlen("_upstream"))
				local name_ind = substr("`name_ind'", strpos("`name_ind'", "_") + 1, .) + "_" + substr("`name_ind'", 1, strpos("`name_ind'", "_") - 1)
			
			local wtp_upstream_`name_ind' = `var'
						
		}

	}

	* Calculate Per-Gallon Emission Rates; All g/KWh to Start.
	import excel "${policy_assumptions}", first clear sheet("marine_emissions")
		gen kwh_per_gal = g_per_gal_heavy_fuel / g_per_kwh

		ds *_KWh
		foreach var in `r(varlist)' {
			
			replace `var' = (`var'/1000000) * kwh_per_gal
				local p_name = substr("`var'", 1, strpos("`var'", "_") - 1)

			if inlist("`p_name'", "NOx", "PM25", "SO2") {
				
				gen wtp_`p_name' = `var' * `social_cost_`p_name'_uw'
				
			} 
			
			if "`p_name'" == "CO2" {
				
				gen wtp_`p_name' = `var' * `social_cost_`p_name''
				
			}
			
			if inlist("`p_name'", "VOC", "CO") {
				
				gen wtp_`p_name'_local = `var'*`social_cost_`p_name'_uw'
				gen wtp_`p_name'_global = `var'*(${`p_name'_gwp}*`social_cost_CO2')
				
			}
			
		}
	collapse (mean) wtp_* g_per_gal_heavy_fuel [aw = vessel_count]
		order wtp_*
			
	* Add Upstream Emissions.
	ds wtp_*
	foreach var in `r(varlist)' {
		
		local p_name = substr("`var'", 5, .)
		replace `var' = `var' + `wtp_upstream_`p_name''
		
	}
		
	gen wtp_N2O = `wtp_upstream_N2O'
	gen wtp_CH4 = `wtp_upstream_CH4'
	gen wtp_NH3 = `wtp_upstream_NH3'
	
	di in red `wtp_upstream_CO2' + `wtp_upstream_CH4' + `wtp_upstream_N2O' + `wtp_upstream_NH3' + `wtp_upstream_NOx' + `wtp_upstream_SO2' + `wtp_upstream_PM25' + `wtp_upstream_CO' + `wtp_upstream_VOC'
	

	if "`value_local_bunker_fuel'" == "no" {

		replace wtp_CO_local = `wtp_upstream_CO_local'
	 
		replace wtp_NOx = `wtp_upstream_NOx'
		replace wtp_PM25 = `wtp_upstream_PM25'
		replace wtp_VOC_local = `wtp_upstream_VOC_local'
		
		replace wtp_SO2 = `wtp_upstream_SO2'

	}

	local soc_l = wtp_CO_local + wtp_VOC_local + wtp_NOx + wtp_PM25 + wtp_SO2 + wtp_NH3
	local soc_g = wtp_CO_global + wtp_VOC_global + wtp_CO2 + wtp_CH4 + wtp_N2O
			
	ds wtp*
	egen sum_check = rowtotal( `r(varlist)' )
		assert round(`soc_l' + `soc_g', 0.001) == round(sum_check, 0.001)
			drop sum_check	
	order wtp_*		
		
restore
	
****************************************************
/* 4. Calculate Components */
****************************************************
preserve
	import excel "${policy_assumptions}", first clear sheet("residual_fuel_prices")
		keep if year == `dollar_year'
			local consumer_price = residual_fuel_price
restore

local tax_rate = 0 // Heavy-fuel oil is not taxed when used by vessels that sail deep waters.

local semi_e_demand_bunker_tax = `e_demand_bunker_fuel_`low_high_toggle''/(`consumer_price')

local wtp_soc_global = `soc_g' * `semi_e_demand_bunker_tax'
					
local wtp_soc_local = `soc_l' * `semi_e_demand_bunker_tax' 

	local wtp_soc = `wtp_soc_local' + `wtp_soc_global'
				
assert round(`wtp_soc', 0.01) == round(`wtp_soc_local' + `wtp_soc_global', 0.01)

	
local semi_e_producer_prices_tax = 0 // Assuming = 0.
local wtp_consumers = 1 + (1 +`tax_rate')*`semi_e_producer_prices_tax'

* Producers
local fisc_ext_prod = (`consumer_price'*`pct_markup')*`semi_e_demand_bunker_tax'*(${gasoline_effective_corp_tax})
local wtp_producers = -(`consumer_price'*`pct_markup')*`semi_e_demand_bunker_tax'*(1 - ${gasoline_effective_corp_tax})

di in red `consumer_price'
di in red `consumer_price'*`pct_markup'
di in red (`consumer_price'*`pct_markup'*0.21)/`consumer_price'
di in red ((`consumer_price'*`pct_markup'*0.21))*`semi_e_demand_bunker_tax'
di in red `fisc_ext_prod'


if "${value_profits}" == "no" {
	
	local wtp_producers = 0 // Includes utilities and gas companies' profits. 
	local fisc_ext_prod = 0
	
}

local total_WTP = `wtp_consumers' + (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_local' + `wtp_producers'	

local WTP_USPres = `wtp_consumers' + `wtp_producers' + `wtp_soc_local' 
local WTP_USFut = `wtp_soc_global' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (1-(${USShareFutureSSC})) * `wtp_soc_global' 

**************************
/* 5. MVPF Calculations */
**************************
local program_cost = 1
	local fiscal_externality_lr = -`wtp_soc_global' * (${USShareFutureSSC} * ${USShareGovtFutureSCC})
	local fiscal_externality_tax = (`tax_rate' * `semi_e_demand_bunker_tax') + `fisc_ext_prod'
	local fiscal_externality_subsidy = -0.000000000000001
local p_spend = `program_cost' + `fiscal_externality_tax'
	
local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_subsidy' + `fiscal_externality_lr'

local MVPF = `total_WTP'/`total_cost'
di in red "`MVPF'"

	assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW')/`total_cost', 0.1) == round(`MVPF', 0.1)

global q_CO2_`1' = ((`wtp_soc_global')/${sc_CO2_`dollar_year'}) * -1
global q_CO2_no_`1' = ((`wtp_soc_global')/${sc_CO2_`dollar_year'}) * -1
global q_CO2_mck_`1' = ((`wtp_soc_global')/${sc_CO2_`dollar_year'})/`semi_e_demand_bunker_tax'
global q_CO2_mck_no_`1' = ((`wtp_soc_global')/${sc_CO2_`dollar_year'})/`semi_e_demand_bunker_tax'
	global resource_cost_`1' = `consumer_price'


*********************************
/* 6. Save Results and Waterfalls */
*********************************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `total_WTP'

global wtp_soc_`1' = `wtp_soc_local' + (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	global wtp_soc_l_`1' = `wtp_soc_local'
	global wtp_soc_g_`1' = (`wtp_soc_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
global wtp_soc_rbd_`1' = -0.00000000000000000001
	global wtp_soc_rbd_local_`1' = -0
	global wtp_soc_rbd_global_`1' = -0
		
global cost_wtp_`1' = -0
global env_cost_wtp_`1' = -0	
global env_cost_wtp_local_`1' = -0
global env_cost_wtp_global_`1' = -0
 
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
		round(${wtp_cons_`1'} + ${wtp_prod_`1'} + ${wtp_soc_`1'} + ${env_cost_wtp_`1'} + ${cost_wtp_`1'}, 0.0001) 


global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fiscal_externality_tax'
global fisc_ext_s_`1' = `fiscal_externality_subsidy'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global cost_`1' = `total_cost'

assert round(${cost_`1'}, 0.0001) == round(${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_s_`1'} + ${fisc_ext_lr_`1'}, 0.0001)
assert round(${MVPF_`1'}, 0.0001) == round(${WTP_`1'}/${cost_`1'}, 0.0001)

global wtp_comps_`1' wtp_cons wtp_soc_g wtp_soc_l wtp_soc_rbd wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_soc_g", "wtp_soc_l", "wtp_soc_rbd", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_t fisc_ext_s fisc_ext_lr cost 
global cost_comps_`1'_commas "program_cost", "fisc_ext_t", "fisc_ext_s", "fisc_ext_lr", "cost" 

global `1'_xlab 1 `""Transfer" "Cost""' 2 `""Enviro." "Damages," "Global""' 3 `" "Enviro." "Damages," "Local" "' 4 `" "Enviro." "Damages," "Rebound" "' 5 `""Gasoline" "Producers" "' 6 `""Total" "WTP""' 8 `""Program" "Cost""' 9 `"Taxes"' 10 `" "Subsidies" "' 11 `" "Climate" "F.E." "' 12 `""Gov't." "Cost""'
			
global color_group1_`1' = 1
global color_group2_`1' = 2
global color_group3_`1' = 5
global cost_color_start_`1' = 8
global color_group4_`1' = 11
