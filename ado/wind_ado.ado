cap prog drop wind_ado
prog def wind_ado, rclass


syntax [anything], ///
	policy_year(integer) /// policy year
	inflation_year(integer) /// usually same as policy year
	spec(string) /// "current" "baseline" etc...
	semie(real) /// semi-elasticity
	capacity_factor_context(real) /// annual
	size_context(real) /// not including FEs
	replacement(string) /// Set equal to the local replacement
	p_name(string) /// equal to `1'
	marg_sales(real) ///
	cum_sales(real) ///
	prod_cost(real) ///
	epsilon(real) ///
	farmer_theta(real) ///
	subsidy_max(real) ///
	current_ptc(real) ///
	[policy(string)] /// If there are policy specific changes
	
	
// Setting the dollar year
	
if "`spec'" == "baseline"{
	local dollar_year = `policy_year'
}

if "`spec'" == "current"{
	local dollar_year = ${current_year}
}

local discount = ${discount_rate}

	****************************************************
	/* 1. Policy Category Assumptions */
	****************************************************

	*i. Import Wind assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("Wind")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
			local `val' = `r(mean)'
		}
		

		local lifetime = ${lifetime}
		
		local capacity_factor = ${capacity_factor} // capacity factor for wind. XX Can drop this parameter b/c MVPF is independent of it. 
		// Capacity factor doesn't matter b/c it affects WTP and cost identically. 
		
		local average_size = ${average_size}
		local credit_life = ${credit_life}
		local capacity_reduction = ${capacity_reduction}
		local wind_emissions = ${wind_emissions}
		local hrs = 8760 // hours per year
		local corporate_disc = 0.0673
		
		if "`spec'" == "baseline"{
			local capacity_factor = `capacity_factor_context' // https://www.energy.gov/sites/default/files/2021-08/Land-Based%20Wind%20Market%20Report%202021%20Edition_Full%20Report_FINAL.pdf
			local average_size = `size_context' // in MW frrom https://pubs.usgs.gov/sir/2011/5036/sir2011-5036.pdf
		}
	
	restore
	
	if "${wind_emissions_change}" == "yes" {
	
		local wind_emissions = `wind_emissions' * ${emissions_scalar}
		
		
}

	if "${lifetime_change}" == "yes" {
	
		local lifetime = `lifetime' * ${lifetime_scalar}
		
		
}

	if "${no_cap_reduction}" == "yes" {
	
		local capacity_reduction = 0.00000000001
		
		
}
	*********************************
	/* 2. Intermediate Calculations */
	*********************************
	local annual_kwh = `average_size' * `hrs' * `capacity_factor' * 1000 // After the first ten years we need to scale this down by the capacity reduction factor
	
	local average_size = 1
	local hrs = 1
	local capacity_factor = 1
	local annual_kwh = 1000

	rebound ${rebound}
	local r = `r(r)'
	
	* Social Costs
	*First 10 years
	dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}")
	local f10_local_pollutants = `r(local_enviro_ext)'
	local f10_global_pollutants = `r(global_enviro_ext)'
	local carbon = `r(carbon_content)'
		
	local new_annual_kwh = (1 - `capacity_reduction') * `annual_kwh'

	*Full Lifetime with lower capacity factor
	dynamic_grid `new_annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // Total 20 years
	local t20_local_pollutants = `r(local_enviro_ext)'
	local t20_global_pollutants = `r(global_enviro_ext)'
	local carbon = `carbon' + `r(carbon_content)'

	* Running and then netting out the first 10 years with lower capacity factor
	dynamic_grid `new_annual_kwh', starting_year(`dollar_year') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // First 10 years with lower capacity factor
	local inter_local_pollutants = `r(local_enviro_ext)'
	local inter_global_pollutants = `r(global_enviro_ext)'
	local carbon = `carbon' - `r(carbon_content)'

	local local_pollutants = `f10_local_pollutants' + (`t20_local_pollutants' - `inter_local_pollutants')
	local global_pollutants = `f10_global_pollutants' + (`t20_global_pollutants' - `inter_global_pollutants')
	
	*Calculating lifecycle costs of wind --> Take place in first year of turbine's life (e.g., fixed enviro. costs--do not vary over lifetime despite being denoted in g/KWh)
	local sc_cost_2020 = ${sc_CO2_`dollar_year'} * ${cpi_`dollar_year'}/${cpi_${sc_dollar_year}} // SCC for year of interest converted to correct dollar year.

	local env_cost = ((`wind_emissions' * 1/1000000 * `annual_kwh' * `credit_life') + (`wind_emissions' * 1/1000000 * `annual_kwh' * (1 - `capacity_reduction') * (`lifetime' - `credit_life'))) * `sc_cost_2020'	
	
	*Calculating carbon quantities for resouce cost
	local q_carbon = ((`carbon' * `r') - (`wind_emissions' * 1/1000000 * `annual_kwh' * `credit_life') - (`wind_emissions' * 1/1000000 * `annual_kwh' * (`lifetime' - `credit_life') * (1 - `capacity_reduction'))) * -`semie'

	global q_carbon_wind = `q_carbon' / (-`semie') // For wind non-marginal analysis

	local q_carbon_mck = ((`carbon') - (`wind_emissions' * 1/1000000 * `annual_kwh' * `credit_life') + (`wind_emissions' * 1/1000000 * `annual_kwh' * (`lifetime' - `credit_life') * (1 - `capacity_reduction')))

	*Scaling environmental externalities by the semie
	local val_local_pollutants = `local_pollutants' * -`semie' // Does NOT include rebound.
	local val_global_pollutants = `global_pollutants' * -`semie' // Does NOT include rebound.
	local rebound_local = `local_pollutants' * (1-`r') * -`semie' // Just rebound component, so summing with above component yields net value.
	local rebound_global = `global_pollutants' * (1-`r') * -`semie' // Just rebound component, so summing with above component yields net value.
	local val_env_cost = `env_cost' * -`semie'	

*************************
/* 3. WTP Calculations */
*************************
* Society
local wtp_society = `val_local_pollutants' + `val_global_pollutants' - `val_env_cost' - `rebound_local' - `rebound_global'

* Private
local wtp_producers = (`average_size' * `hrs'*`capacity_factor') + ((`average_size' * `hrs'*`capacity_factor')/`discount') * (1 - (1/(1+`discount')^(`credit_life' - 1))) * 1000 * 0.01 // The 0.01 is the change in the $/KWh PTC --> a 1 cent change. 
	// Calculate for wtp_producers is same as subsidy max, but substitute actual subsidy size for the delta PTC (0.01). Also, we discount wtp producers.
local wtp_private = `wtp_producers'

// Two pieces needed if running cost curve w/o using time paths.
local enviro_ext = `local_pollutants' + `global_pollutants' - `env_cost' - ((`local_pollutants' + `global_pollutants') * (1-`r')) // ANY ROBUSTNESS WILL USE THIS APPROACH - CHANGES IN SCC DO NOT.

local enviro_ext_global = ((`global_pollutants' * `r') - `env_cost') / `enviro_ext' // Share of environmental externality that is global pollutants

*Cost Curve Calculation
local program_cost = (`average_size' * `hrs'*`capacity_factor') + ((`average_size' * `hrs'*`capacity_factor')/`discount') * (1 - (1/(1+`discount')^(`credit_life' - 1))) * 1000 * 0.01 // for a $0.01 per kwh subsidy
	
if "${lbd}" == "yes" { 
	if "`replacement'" == "marginal" & "${grid_model}" != "sta" { // If the replacement is marginal and the grid is NOT static, use forecasted damage / benefit timepaths. Run twice (for global and local).
		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("wind_local") scc(${scc_import_check}) subsidy_max(`subsidy_max') time_path_age(25)
		local env_cost_wtp_local = `r(enviro_mvpf)' * `program_cost'
		local enviro_mvpf_raw = `r(enviro_mvpf)'

		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("wind_global") scc(${scc_import_check}) subsidy_max(`subsidy_max') time_path_age(25)
		local env_cost_wtp_global = `r(enviro_mvpf)' * `program_cost'
		local enviro_mvpf_raw = `r(enviro_mvpf)' + `enviro_mvpf_raw'
	}

	if "`replacement'" != "marginal" | "${grid_model}" == "sta" { // If the grid is static, need to assume a constant enviro. externality and keep the wedge held fixed off into the future. Global / Local split therefore constant, only one run needed. 
		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("constant_`enviro_ext'") scc(${scc_import_check})
		
		local env_cost_wtp_global = (`r(enviro_mvpf)' * `program_cost') * `enviro_ext_global' // Multiplying by shares rather than running twice.
		local env_cost_wtp_local = (`r(enviro_mvpf)' * `program_cost') * (1 - `enviro_ext_global') // Multiplying by shares rather than running twice.
		local enviro_mvpf_raw = `r(enviro_mvpf)'
	}

	local cost_mvpf = `r(cost_mvpf)'
	local cost_wtp = `r(cost_mvpf)' * `program_cost'
	local enviro_wtp = `env_cost_wtp_local' + `env_cost_wtp_global'
	local enviro_ext_global = `env_cost_wtp_global' / `enviro_wtp'
}

if "${lbd}" == "no" {
	local cost_mvpf = 0
	local cost_wtp = 0
	local enviro_wtp = 0
	local env_cost_wtp_global = 0 
	local env_cost_wtp_local = 0
	local enviro_mvpf_raw = 0
}


* Total WTP
local WTP = `wtp_private' + (`val_local_pollutants' - `rebound_local') + ((`val_global_pollutants' - `rebound_global' - `val_env_cost') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) // WTP Private = WTP Producers
local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp_local' + (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))


local WTP_USPres = `wtp_private' + (`val_local_pollutants' - `rebound_local') + `env_cost_wtp_local'
local WTP_USFut = ((`val_global_pollutants' + `env_cost_wtp_global' - `rebound_global' - `val_env_cost') * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + (`cost_wtp' * ${US_windshare})
local WTP_RoW = ((`val_global_pollutants' + `env_cost_wtp_global' - `rebound_global' - `val_env_cost') * (1 - ${USShareFutureSSC})) + (`cost_wtp' * (1 - ${US_windshare}))
// 	assert round(`WTP_USPres' + `WTP_USFut' + `WTP_RoW', 0.1) == round(`WTP_cc', 0.1)

**************************
/* 6. Cost Calculations  */
**************************
local fisc_ext_s = (`average_size' * `hrs'* `capacity_factor' * 1000 * -`semie' * `current_ptc') + ((`average_size' * `hrs'* `capacity_factor' * 1000 * -`semie' * `current_ptc')/`discount') * (1 - (1/(1+`discount')^(`credit_life' - 1))) // Same as producers' WTP but using current PTC.

local fisc_ext_t = 0

local fisc_ext_lr = -1 * (`val_global_pollutants' + `env_cost_wtp_global' - `rebound_global' - `val_env_cost') * (${USShareFutureSSC} * ${USShareGovtFutureSCC})

local fisc_ext_nocc = -1 * (`val_global_pollutants' - `rebound_global' - `val_env_cost') * (${USShareFutureSSC} * ${USShareGovtFutureSCC}) // Climate FE w/o LBD Global Pollution.


local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'
local total_cost_nocc = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_nocc'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = (`WTP_cc'/`total_cost')

local MVPF_no_cc = (`WTP_cc' - `cost_wtp' - `enviro_wtp') / `total_cost_nocc'
	// `WTP_cc' - `cost_wtp' - `enviro_wtp' = `WTP'

assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW') / `total_cost', 0.1) == round(`MVPF', 0.1)

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${ng_lcoe} // counterfactual is just natural gas
local wind_cost = ${wind_lcoe}

local resource_cost = `wind_cost' - `energy_cost'

local tons_per_lb = 0.000453592
local ng_carbon = 0.898122 * `tons_per_lb'

local q_carbon_mck = `ng_carbon' - `wind_emissions' * 1/1000000

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = -`semie' * ((`ng_carbon' * `r') - (`wind_emissions' * 1/1000000))

****************
/* 9. Outputs */
****************
global MVPF_`p_name' = `MVPF'
global MVPF_no_cc_`p_name' =  `MVPF_no_cc'

global cost_`p_name' = `total_cost'
global WTP_`p_name' = `WTP'
global WTP_cc_`p_name' = `WTP_cc'
global enviro_mvpf_`p_name' = `enviro_mvpf_raw'

global enviro_mvpf_`p_name' = (`enviro_mvpf_raw' * `enviro_ext_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + (`enviro_mvpf_raw' * (1 - `enviro_ext_global'))


global cost_mvpf_`p_name' = `cost_mvpf'

global wtp_private_`p_name' = `wtp_private'
global wtp_cons_`p_name' = 0

global wtp_prod_`p_name' = `wtp_producers'
global wtp_glob_`p_name' = (`val_global_pollutants'-`rebound_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`p_name' = `val_local_pollutants' -`rebound_local'

global wtp_r_loc_`p_name' = -`rebound_local'
global wtp_r_glob_`p_name' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global wtp_e_cost_`p_name' = - `val_env_cost' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})) // To be consistent w/ solar, remove val_env_cost from wtp_glob and add this bar XX


global program_cost_`p_name' = `program_cost'

global env_cost_wtp_`p_name' = `env_cost_wtp_local' + (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global env_cost_wtp_g_`p_name' = (`env_cost_wtp_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global env_cost_wtp_l_`p_name' = `env_cost_wtp_local'

global cost_wtp_`p_name' = `cost_wtp'

global wtp_soc_`p_name' = `wtp_society'

global wind_g_wf_`p_name' = (`val_global_pollutants') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wind_l_wf_`p_name' = `val_local_pollutants'

// 	assert round(${wtp_prod_`p_name'} + ${wtp_glob_`p_name'} + ${wtp_loc_`p_name'} + ${wtp_r_loc_`p_name'} + ${wtp_r_glob_`p_name'} + ${env_cost_wtp_g_`p_name'} + ${env_cost_wtp_l_`p_name'} + ${cost_wtp_`p_name'}, 0.01) == round(${WTP_cc_`p_name'}, 0.01)

global epsilon_`p_name' = round(`epsilon', 0.001)
global `p_name'_ep = round(`epsilon', 0.001)
global adj_elas_`p_name' = `epsilon'

global total_cost_`p_name' = `total_cost'

global fisc_ext_t_`p_name' = `fisc_ext_t'
global fisc_ext_s_`p_name' = `fisc_ext_s'
global fisc_ext_lr_`p_name' = `fisc_ext_lr'

global p_spend_`p_name' = `policy_spending'
global q_CO2_`p_name' = `q_carbon'
global q_CO2_mck_`p_name' = `q_carbon_mck'
global resource_cost_`p_name' = ${average_size} * (${installed_cost_per_kwh}*1000) // Both in MWh after unit conversions.
global wtp_soc_rbd_`p_name' = -`rebound_local' - `rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global WTP_USPres_`p_name' = `WTP_USPres'
global WTP_USFut_`p_name'  = `WTP_USFut'
global WTP_RoW_`p_name'    = `WTP_RoW'

global gov_carbon_`p_name' = `gov_carbon'
global resource_ce_`p_name' = `resource_ce'
global q_carbon_mck_`p_name' = `q_carbon_mck'
global semie_`p_name' = `semie'

** for waterfall charts
global wtp_comps_`p_name' wtp_prod wind_g_wf wind_l_wf wtp_r_glob wtp_r_loc wtp_e_cost env_cost_wtp cost_wtp WTP_cc
global wtp_comps_`p_name'_commas "wtp_prod", "wind_g_wf", "wind_l_wf", "wtp_r_glob", "wtp_r_loc", "wtp_e_cost", "env_cost_wtp", "cost_wtp", "WTP_cc"

global cost_comps_`p_name' program_cost fisc_ext_s fisc_ext_lr total_cost
global cost_comps_`p_name'_commas "program_cost", "fisc_ext_s", "fisc_ext_lr", "total_cost"

global `p_name'_xlab 1 `"Producers"' 2 `""Global" "Env""' 3 `""Local" "Env""' 4 `""Rebound" "Global""' 5 `""Rebound" "Local""' 6 `""Lifecycle" "Costs""' 7 `""Dynamic" "Env""' 8 `""Dynamic" "Price""' 9 `"Total WTP"' 11 `"Program Cost"' 12 `"Subsidies"' 13 `""Climate" "FE""' 14 `""Govt" "Cost""' ///

*color groupings
global color_group1_`p_name' = 1
global color_group2_`p_name' = 6
global color_group3_`p_name' = 8
global color_group4_`p_name' = 8
global cost_color_start_`p_name' = 11
global color_group5_`p_name' = 13

global note_`p_name' = `""'
global normalize_`p_name' = 1

end