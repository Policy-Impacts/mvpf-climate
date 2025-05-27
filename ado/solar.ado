cap prog drop solar
prog def solar, rclass


syntax [anything], ///
	policy_year(integer) /// policy year
	spec(string) /// "current" "baseline" etc...
	semie(real) /// semi-elasticity
	replacement(string) /// Set equal to the local replacement
	p_name(string) /// equal to `1'
	marg_sales(real) ///
	cum_sales(real) ///
	annual_output(real) ///
	system_capacity(real) ///
	pre_cost_per_watt(real) /// Net of the state subsidy but not federal subsidy
	avg_state_rebate(real) ///
	e_demand(real) ///
	pass_through(real) ///
	farmer_theta(real) ///
	federal_subsidy(real) ///
	[policy(string)] /// If there are policy specific changes
	
	
	// Setting the dollar year
		
	if "`spec'" == "baseline"{
		local dollar_year = `policy_year'
	}

	if "`spec'" == "current"{
		local dollar_year = ${current_year}
	}

	local discount = ${discount_rate}
	
	global solar_lca_co2e 40 // grams of CO2e per KWh, from NREL  https://www.nrel.gov/docs/fy13osti/56487.pdf

	****************************************************
	/* 1. Policy Category Assumptions */
	****************************************************

	*i. Import Solar assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("Solar")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
			local `val' = `r(mean)'
		}
		
		local lifetime = ${lifetime}
	restore
	
	if "${solar_output_change}" == "yes" {
		local annual_output = `annual_output' * ${output_scalar}
	}
	
	if "${lifetime_change}" == "yes" {
		local lifetime = `lifetime' * ${lifetime_scalar}
	}
	
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = `avg_state_rebate'
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'

	local solar_lca_co2e = ${solar_lca_co2e} / 1000000 // in g/kWh, so need to divide by 1e6 to get t/kWh
	local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022}) // Expressed in 2022 dollars initially.
	local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022}) // Expressed in 2022 dollars initially.

	*********************************
	/* 2. Intermediate Calculations */
	*********************************
	local annual_kwh = `system_capacity' * `annual_output' * 1000 // Same as output. kWh/Year
	
	rebound ${rebound}
	local r = `r(r)'

	* Social Costs
	if "${spec_type}" == "baseline" & "`p_name'" == "ne_solar" {
		preserve
		import excel "${policy_assumptions}", first clear sheet("solar_mix") // Weighted across NE states by population. 

		foreach s in CT DC DE MA MD ME NH NJ NY PA RI VT WV {
			qui sum Share if State == "`s'"
			local `s'_share = `r(mean)'
			
			dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("solar") geo("`s'") grid_specify("yes") model("${grid_model}")
			local local_pollutants = `local_pollutants' + `r(local_enviro_ext)' * ``s'_share'
			local global_pollutants = `global_pollutants' + `r(global_enviro_ext)' * ``s'_share'
			local carbon = `carbon' + `r(carbon_content)' * ``s'_share'
			local government_revenue_MIX = `government_revenue_MIX' + ${government_revenue_`dollar_year'_`s'} * ``s'_share'
			local producer_surplus_MIX = `producer_surplus_MIX' + ${producer_surplus_`dollar_year'_`s'} * ``s'_share'
		}
		global government_revenue_`dollar_year'_MIX = `government_revenue_MIX'
		global producer_surplus_`dollar_year'_MIX = `producer_surplus_MIX'
		restore
	}
	
	else {
		dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("solar") geo("${State}") grid_specify("yes") model("${grid_model}")
		local local_pollutants = `r(local_enviro_ext)'
		local global_pollutants = `r(global_enviro_ext)'
		local carbon = `r(carbon_content)'
	}

	local lca_annual = `annual_kwh' * `solar_lca_co2e' * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}))
	
	local lca_ext = `lca_annual' + (`lca_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1 )))

	local epsilon = `e_demand'

	*if bootstrap gets a positive elasticity, hardcode epsilon
	if `epsilon' > 0 {
		local epsilon = - 0.00001
	}

	local q_carbon = ((`carbon' * `r') - (`annual_kwh' * `solar_lca_co2e' * `lifetime')) * -`semie' * `pass_through'
	local val_local_pollutants = `local_pollutants' * -`semie' * `pass_through'
	local val_global_pollutants = `global_pollutants' * -`semie' * `pass_through'
	local rebound_local = `local_pollutants' * (1-`r') * -`semie' * `pass_through'
	local rebound_global = `global_pollutants' * (1-`r') * -`semie' * `pass_through'
	
*************************
/* 3. WTP Calculations */
*************************
* Society
local wtp_soc_raw = `val_local_pollutants' + `val_global_pollutants'

// LCA externality
local wtp_soc_lca = -`semie' * `lca_ext' * `pass_through'

local wtp_soc = `wtp_soc_raw' - `wtp_soc_lca' - `rebound_local' - `rebound_global'


local enviro_ext = `local_pollutants' + `global_pollutants' - `lca_ext' - ((`local_pollutants' + `global_pollutants') * (1-`r')) // externality for the system to use in cost curve estimate

local enviro_ext_global = ((`global_pollutants' * `r') - `lca_ext') / `enviro_ext'


* Private
local wtp_cons = `pass_through' * `system_capacity' * 1000 // Proportion of $1 increase in rebate captured by consumers.

local producer_price = `pre_cost_per_watt' + `avg_state_rebate' // the amount producers make (p + tau in the formula).
local marginal_cost = `pre_cost_per_watt' - `markup' * `pre_cost_per_watt' // (c in the formula)
local wtp_install = (1 + (-1 * (1 - `pass_through')) * (1 + `epsilon' * ((`producer_price'-`marginal_cost')/`producer_price'))) *  `system_capacity' * 1000

local prod_annual = -`semie' * `pass_through' * `annual_kwh' * ${producer_surplus_`dollar_year'_${State}}

local wtp_prod = `prod_annual' + (`prod_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) * `r' // Applying rebound too.

local c_savings = 0

if "${value_savings}" == "yes" {
	local annual_savings = -`semie' * `pass_through' * `annual_kwh' * ${kwh_price_`dollar_year'_${State}}
	local c_savings = `annual_savings' + (`annual_savings'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) // No rebound effect here. 
}

if "${value_profits}" == "no" {
	local wtp_prod = 0
	local markup = 0
	local wtp_install = (1 - `pass_through') * `system_capacity' * 1000  // Proportion of $1 increase in rebate captured by installers.
	
	if `wtp_install' < 0 {
		local wtp_install = 0
	}

}

if "${solar_markups}" == "no" {
	local markup = 0
	local wtp_install = (1 - `pass_through') * `system_capacity' * 1000  // Proportion of $1 increase in rebate captured by installers.
	
	if `wtp_install' < 0 {
		local wtp_install = 0
	}
}

if "${cost_shifting}" == "yes" {
	local wtp_prod = 0
	 // calling it wtp_prod but actually probably ratepayers
	local prod_annual = -`semie' * `pass_through' * `annual_kwh' * (${energy_cost} + 0.032)

	local wtp_prod = `prod_annual' + (`prod_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) * `r' // Applying rebound too.
}

local wtp_private = `wtp_cons' + `wtp_install' - `wtp_prod'

* learning by doing
local prod_cost = (`pre_cost_per_watt') * `system_capacity' * 1000
local subsidy_max = `federal_subsidy' * `prod_cost' 
local program_cost = 1 * `system_capacity' * 1000 // $1/W change in subsidy converted to subsidy per solar system. Sum of installers' and consumers' WTP.

*Change elasticity for cost curve for Hughes
local scale = 1
if "`p_name'" == "hughes_csi" {
	local epsilon = -1.138091 // Pless HO Epsilon
	local scale = (`e_demand' / `epsilon')
}


if "${lbd}" == "yes" {
	if "${spec_type}" != "baseline" & "`replacement'" == "marginal" & "${grid_model}" != "sta" {
		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("solar_local") markup(`markup') passthrough(-`pass_through') subsidy_max(`subsidy_max') scc(${scc_import_check}) time_path_age(`lifetime')
		local enviro_mvpf_raw = `r(enviro_mvpf)' * `scale'
		local env_cost_wtp_local = `enviro_mvpf_raw' * `program_cost'
		
		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("solar_global") markup(`markup') passthrough(-`pass_through') subsidy_max(`subsidy_max') scc(${scc_import_check}) time_path_age(`lifetime')
		local env_cost_wtp_global = (`r(enviro_mvpf)' * `scale') * `program_cost'
		local enviro_mvpf_raw = (`r(enviro_mvpf)' * `scale') + `enviro_mvpf_raw'

		local enviro_ext_global = (`env_cost_wtp_global') / (`env_cost_wtp_global' + `env_cost_wtp_local')

	}


	if "${spec_type}" == "baseline" | "`replacement'" != "marginal" | "${grid_model}" == "sta" {
		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("constant_`enviro_ext'") markup(`markup') passthrough(-`pass_through') subsidy_max(`subsidy_max') scc(${scc_import_check})
		local env_cost_wtp_global = (`r(enviro_mvpf)' * `scale' * `program_cost') * `enviro_ext_global'
		local env_cost_wtp_local = (`r(enviro_mvpf)' * `scale' * `program_cost') * (1 - `enviro_ext_global')
		local enviro_mvpf_raw = `r(enviro_mvpf)' * `scale'
		
	}

	local cost_wtp = `r(cost_mvpf)' * `scale' * `program_cost'
	local env_cost_wtp = `env_cost_wtp_local' + `env_cost_wtp_global'
	local firm_cost_wtp = `r(firm_mvpf)' * `program_cost'
	// local gov_fe = `r(dynamic_fe)' * `program_cost'
	local gov_fe = 0
	local cost_mvpf = `r(cost_mvpf)' * `scale'
	local firm_cost_no_prog_cost = `r(firm_mvpf)'
	
	local enviro_raw_local = `env_cost_wtp_local' / (`program_cost')
	local enviro_raw_global = (`env_cost_wtp_global' / (`program_cost')) * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
}

if "${lbd}" == "no" {
	local cost_mvpf = 0
	local cost_wtp = 0
	local env_cost_wtp = 0
	local env_cost_wtp_global = 0
	local env_cost_wtp_local = 0
	local enviro_mvpf_raw = 0
	local firm_cost_wtp = 0
	local gov_fe = 0
	local enviro_mvpf_raw = 0
	local firm_cost_no_prog_cost = 0
	local enviro_raw_local = 0
	local enviro_raw_global = 0
}

// Quick Decomposition

/* Assumptions:

	- wtp_private, cost_wtp -> US Present
	- wtp_soc, env_cost_wtp -> US Future & Rest of the World

*/

local g_latex = ((`val_global_pollutants' - `wtp_soc_lca') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) / 7150
local l_latex = `val_local_pollutants'/7150
local gr_latex = ((`rebound_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) / 7150
local lr_latex = `rebound_local'/7150

	di "Global Benefits: `g_latex'"
	di "Local Benefits: `l_latex'"
	di "Global Rebound: `gr_latex'"
	di "Local Rebound: `lr_latex'"



local enviro_latex = (`env_cost_wtp_local' + (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))) / 7150
local price_latex = `cost_wtp' / 7150
local prod_latex = `wtp_prod' / 7150
di "Dynamic Price: `price_latex'"
di "Dynamic Enviro: `enviro_latex'"
di "Producer Loss: `prod_latex'"

* Total WTP
local WTP = `wtp_private' + `c_savings' + (`val_local_pollutants' - `rebound_local') + ((`val_global_pollutants' - `rebound_global' - `wtp_soc_lca') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp_local' + (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `firm_cost_wtp'

di "WTP_cc: `WTP_cc'"

local WTP_USPres = `wtp_private' + (`val_local_pollutants' - `rebound_local') + `env_cost_wtp_local' + `c_savings'
local WTP_USFut = ((`val_global_pollutants' - `rebound_global' + `env_cost_wtp_global' - `wtp_soc_lca') * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + ((`cost_wtp' + `firm_cost_wtp') * ${US_solarshare})
local WTP_RoW = ((`val_global_pollutants' - `rebound_global' + `env_cost_wtp_global' - `wtp_soc_lca') * (1 - ${USShareFutureSSC})) + ((`cost_wtp' + `firm_cost_wtp') * (1 - ${US_solarshare}))
// assert round(`WTP_USPres' + `WTP_USFut' + `WTP_RoW', 0.1) == round(`WTP_cc', 0.1)

	
**************************
/* 6. Cost Calculations  */
**************************
local annual_fe_t = -`semie' * `pass_through' * `annual_kwh' * ${government_revenue_`dollar_year'_${State}}

local fisc_ext_t = `annual_fe_t' + (`annual_fe_t'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) * `r'

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

if "${cost_shifting}" == "yes" {
	local fisc_ext_t = 0
}

local gov_state_spending = `avg_state_rebate' * `system_capacity' * 1000 * -`semie' * `pass_through' // each additional subsidy costs the state gov $3.43/W at a 6.972 kW capacity system and costs the federal gov 30% of total spending, when calculating in-context. 

local gov_fed_spending = `avg_fed_rebate' * `system_capacity' * 1000 * -`semie' * `pass_through' // Recall: avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'

local fisc_ext_s = `gov_state_spending' + `gov_fed_spending' + `gov_fe'

local fisc_ext_lr = -1 * (`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`env_cost_wtp_global')) * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

local q_carbon_mck = ((`carbon' * `r') - (`annual_kwh' * `solar_lca_co2e' * `lifetime')) // q_carbon without semie * pass_through




**************************
/* 7. MVPF Calculations */
**************************
local MVPF = (`WTP'/`total_cost') + (`enviro_raw_local' + `cost_mvpf' + `firm_cost_no_prog_cost' + `enviro_raw_global') * (`program_cost'/`total_cost')
di `MVPF'

local MVPF_no_cc = (`WTP_cc' - `cost_wtp' - `env_cost_wtp' - `firm_cost_wtp') / `total_cost'

// assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW') / `total_cost', 0.1) == round(`MVPF', 0.1)
****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}

local solar_cost = (`pre_cost_per_watt' / 25) / `annual_output'

local resource_cost = `solar_cost' - `energy_cost'

dynamic_split_grid 1, starting_year(`dollar_year') ext_year(`dollar_year') discount_rate(`discount') ef("`replacement'") type("solar") geo("US") grid_specify("yes") model("${grid_model}")
local kwh_carbon = `r(carbon_content)'

local q_carbon_mck = `kwh_carbon' - `solar_lca_co2e' // q_carbon without semie * pass_through or rebound

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = -`semie' * `pass_through' * ((`kwh_carbon' * `r') - `solar_lca_co2e')

****************
/* 9. Outputs */
****************
global normalize_`p_name' = 1

global MVPF_`p_name' = `MVPF'
global cost_`p_name' = `total_cost'
global WTP_`p_name' = `WTP'
global WTP_cc_`p_name' = `WTP_cc'
global enviro_mvpf_`p_name' = `enviro_raw_local' + `enviro_raw_global'
global cost_mvpf_`p_name' = `cost_mvpf'
global firm_mvpf_`p_name' = `firm_cost_no_prog_cost' // Same as `r(firm_mvpf)'
global wtp_private_`p_name' = `wtp_private'
global wtp_cons_`p_name' = `wtp_cons'
global wtp_install_`p_name' = `wtp_install'
global wtp_prod_`p_name' = -`wtp_prod'
global wtp_glob_`p_name' = `val_global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`p_name' = `val_local_pollutants'

global wtp_r_loc_`p_name' = -`rebound_local'
global wtp_r_glob_`p_name' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_e_cost_`p_name' = -`wtp_soc_lca' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global program_cost_`p_name' = `program_cost'

global env_cost_wtp_`p_name' = `env_cost_wtp_local' + (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))  
global env_cost_wtp_g_`p_name' = (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global env_cost_wtp_l_`p_name' = `env_cost_wtp_local'

global cost_wtp_`p_name' = `cost_wtp'
global firm_cost_wtp_`p_name' = `firm_cost_wtp'

global c_savings_`p_name' = `c_savings'

global wtp_soc_`p_name' = `wtp_soc'

// 	assert round(${wtp_prod_`p_name'} + ${wtp_cons_`p_name'} + ${wtp_install_`p_name'} + ${wtp_glob_`p_name'} + ${wtp_loc_`p_name'} + ${wtp_r_loc_`p_name'} + ${wtp_r_glob_`p_name'} + ${env_cost_wtp_g_`p_name'} + ${env_cost_wtp_l_`p_name'} + ${cost_wtp_`p_name'} + ${wtp_e_cost_`p_name'}, 0.01) == round(${WTP_cc_`p_name'}, 0.01)

global wtp_soc_raw_`p_name' = `wtp_soc_raw'
global wtp_soc_lca_`p_name' = -`wtp_soc_lca'

global fisc_ext_t_`p_name' = `fisc_ext_t'
global fisc_ext_s_`p_name' = `fisc_ext_s'
global fisc_ext_lr_`p_name' = `fisc_ext_lr'

global p_spend_`p_name' = `policy_spending'
global q_CO2_`p_name' = `q_carbon'
global q_CO2_mck_`p_name' = `q_carbon_mck'
global resource_cost_`p_name' = `cost_per_watt_baseline' * (`system_capacity'*1000)


global WTP_USPres_`p_name' = `WTP_USPres'
global WTP_USFut_`p_name'  = `WTP_USFut'
global WTP_RoW_`p_name'    = `WTP_RoW'

global gov_carbon_`p_name' = `gov_carbon'
global resource_ce_`p_name' = `resource_ce'
global q_carbon_mck_`p_name' = `q_carbon_mck'
global semie_`p_name' = `semie' // need for resource cost per ton including LBD
global pass_through_`p_name' = `pass_through'

** for waterfall charts
global wtp_comps_`p_name' wtp_cons wtp_install wtp_glob wtp_loc wtp_r_glob wtp_r_loc wtp_e_cost env_cost_wtp cost_wtp wtp_prod WTP_cc
global wtp_comps_`p_name'_commas "wtp_cons", "wtp_install", "wtp_glob", "wtp_loc", "wtp_r_glob", "wtp_r_loc"

global wtp_comps_`p_name'_commas2 "wtp_e_cost", "env_cost_wtp", "cost_wtp", "wtp_prod",  "WTP_cc"

global cost_comps_`p_name' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr cost
global cost_comps_`p_name'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "cost"
global `p_name'_name "`p_name'"
global `p_name'_ep = round(`epsilon', 0.001)

global `p_name'_xlab 1 `"Cons."' 2 `"Installers"' 3 `""Global" "Enviro""' 4 `""Local" "Enviro""' 5 `""Rebound" "Global""' 6 `""Rebound" "Local""' 7 `""Enviro" "Cost""' 8 `""Dynamic" "Enviro""' 9 `""Dynamic" "Price""' 10 `"Producers"' 11 `"Total WTP"' 13 `""Program" "Cost""' 14 `""FE" "Subsidies""' 15 `""FE" "Taxes""' 16 `""FE" "Long-Run""' 17 `"Total Cost"' ///

*color groupings
global color_group1_`p_name' = 2
global color_group2_`p_name' = 7
global color_group3_`p_name' = 9
global color_group4_`p_name' = 10
global cost_color_start_`p_name' = 13
global color_group5_`p_name' = 16

end