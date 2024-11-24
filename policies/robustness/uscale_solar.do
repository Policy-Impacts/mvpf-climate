**************************************************
/*       0. Program: Utility-Scale Solar              */
**************************************************

*Using elasticity from metcalf

********************************
/* 1. Pull Global Assumptions */
********************************
local discount = ${discount_rate}
local replacement = "${replacement}"
global spec_type = "`4'"

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

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************
	if "${spec_type}" == "baseline"{
		local dollar_year = ${policy_year}
	}

	if "${spec_type}" == "current"{
		local dollar_year = ${current_year}
	}
	
	local corporate_disc = `discount'

	****************************************************
	/* 3b. Policy Category Assumptions */
	****************************************************
	local hours = 8760
	local capacity_factor = 0.24 // https://emp.lbl.gov/publications/utility-scale-solar-2021-edition
	local lifetime = 25 
	local lcoe_itc = 0.028 // https://emp.lbl.gov/publications/utility-scale-solar-2021-edition
	local lcoe_ptc = 0.019
	local lcoe = 0.034 // https://emp.lbl.gov/publications/utility-scale-solar-2021-edition
	local credit_life = 10
	local current_ptc = 0.015
	
	local average_size = 1
	local annual_kwh = 1 * `hours' * `capacity_factor' * 1000
	
	*Assume 1 MW Solar
	*Capacity factor = 0.2547
	*kwh_output = 8760 * 0.2547 * 1 * 1000
	*LCOE ~34 (maybe use lcoe inclusive of ITC)
	*lifetime: use 25 years to be conservative
	
	
	
***************************************
/* 4. Calculating Semie & Elasticity */
***************************************

* learning by doing
local cum_sales = 713918
local marg_sales = 128050.40

local epsilon = -1.3
local semie = (0.01/(`lcoe_ptc')) * `epsilon' 

local prod_cost = `lcoe' * `annual_kwh' * `lifetime'
local subsidy_max = `annual_kwh' * `current_ptc' * `credit_life' 


	*********************************
	/* 2. Intermediate Calculations */
	*********************************
	rebound ${rebound}
	local r = `r(r)'
	
	* Social Costs
	dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("solar") geo("${State}") grid_specify("yes") model("${grid_model}")
	local local_pollutants = `r(local_enviro_ext)'
	local global_pollutants = `r(global_enviro_ext)'
	local carbon = `r(carbon_content)'
	
	local sc_cost_2020 = ${sc_CO2_`dollar_year'} * ${cpi_`dollar_year'}/${cpi_${sc_dollar_year}}

	local solar_lca_co2e = ${solar_lca_co2e} / 1000000 // in g/kWh, so need to divide by 1e6 to get t/kWh
// 	local lca_ext = ((`annual_kwh' * `solar_lca_co2e' * `sc_cost_2020')/`discount') * (1 - (1/(1+`discount')^(`lifetime')))
	
		local lca_annual = `annual_kwh' * `solar_lca_co2e' * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}))
	
	local lca_ext = `lca_annual' + (`lca_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1 )))


	local q_carbon = ((`carbon' * `r') - (`annual_kwh' * `solar_lca_co2e' * `lifetime')) * -`semie'
	
	local val_local_pollutants = `local_pollutants' * -`semie'
	local val_global_pollutants = `global_pollutants' * -`semie'
	local rebound_local = `local_pollutants' * (1-`r') * -`semie'
	local rebound_global = `global_pollutants' * (1-`r') * -`semie'
	
*************************
/* 3. WTP Calculations */
*************************
local wtp_soc_raw = `val_local_pollutants' + `val_global_pollutants'

// LCA externality
local wtp_soc_lca = -`semie' * `lca_ext'

local wtp_society = `wtp_soc_raw' - `wtp_soc_lca' - `rebound_local' - `rebound_global'
local enviro_ext = `local_pollutants' + `global_pollutants' - `lca_ext' - ((`local_pollutants' + `global_pollutants') * (1-`r')) // externality for the system to use in cost curve estimate
local enviro_ext_global = (`global_pollutants' * `r') / `enviro_ext'

* Private
local wtp_producers = (`annual_kwh' * 0.01) + ((`annual_kwh' * 0.01)/`corporate_disc') * (1 - (1/(1+`corporate_disc')^(`credit_life' - 1)))

local wtp_private = `wtp_producers'

*Cost Curve Calculation
local program_cost = (`annual_kwh' * 0.01) + ((`annual_kwh' * 0.01)/`discount') * (1 - (1/(1+`discount')^(`credit_life' - 1))) // for a $0.01 per kwh subsidy

// if "${lbd}" == "yes" { 
// 	if "`replacement'" == "marginal" & "${grid_model}" != "sta" {
// 		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("solar_local") scc(${sc_CO2_2020}) subsidy_max(`subsidy_max')
// 		local env_cost_wtp_local = `r(enviro_mvpf)' * `program_cost'
// 		local enviro_mvpf_raw = `r(enviro_mvpf)'
//
// 		cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("solar_global") scc(${sc_CO2_2020}) subsidy_max(`subsidy_max')
// 		local env_cost_wtp_global = `r(enviro_mvpf)' * `program_cost'
// 		local enviro_mvpf_raw = `r(enviro_mvpf)' + `enviro_mvpf_raw'
// 	}
	
// di `enviro_ext'
// di `program_cost'
// di `enviro_ext_global'
// di `marg_sales'
// di `subsidy_max'
// di `prod_cost'
// di `farmer_theta'
// di `marg_sales'
// e
if "${lbd}" == "yes" {
	cost_curve_masterfile,  demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("constant_`enviro_ext'") subsidy_max(`subsidy_max') scc(${sc_CO2_2020})
	local env_cost_wtp_global = (`r(enviro_mvpf)' * `program_cost') * `enviro_ext_global'
	local env_cost_wtp_local = (`r(enviro_mvpf)' * `program_cost') * (1 - `enviro_ext_global')
	local enviro_mvpf_raw = `r(enviro_mvpf)'
	
	local cost_mvpf = `r(cost_mvpf)'
	local cost_wtp = `r(cost_mvpf)' * `program_cost'
	local enviro_wtp = `env_cost_wtp_local' + `env_cost_wtp_global'
}

if "${lbd}" == "no" {
	local cost_mvpf = 0
	local cost_wtp = 0
	local enviro_wtp = 0
	local env_cost_wtp_global = 0
	local env_cost_wtp_local = 0
	local enviro_mvpf_raw = 0
}

local WTP = `wtp_private' + `wtp_society' - ((`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`enviro_ext_global' * `enviro_wtp')) * ${USShareFutureSSC} * ${USShareGovtFutureSCC})
local WTP_cc = `WTP' + `cost_wtp' + `enviro_wtp'

local WTP_USPres = `wtp_private' + `val_local_pollutants' - `rebound_local' + ((1-`enviro_ext_global') * `enviro_wtp')
local WTP_USFut = ${USShareFutureSSC} * (`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`enviro_ext_global' * `enviro_wtp') - ((`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`enviro_ext_global' * `enviro_wtp')) * ${USShareGovtFutureSCC})) + `cost_wtp' * ${US_solarshare}
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`enviro_ext_global' * `enviro_wtp')) + `cost_wtp' * (1 - ${US_solarshare})

**************************
/* 6. Cost Calculations  */
**************************
// local program_cost = ((`average_size' * `hrs' * `capacity_factor' * 1000 * 0.01)/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) // for a $0.01 per kwh subsidy // Already added above

local fisc_ext_s = (`average_size' * `hours'* `capacity_factor' * 1000 * -`semie' * `current_ptc') + ((`average_size' * `hours'* `capacity_factor' * 1000 * -`semie' * `current_ptc')/`discount') * (1 - (1/(1+`discount')^(`credit_life' - 1)))

local fisc_ext_t = 0 // Need to edit this to add rebound effect gov rev (should be negative)

local fisc_ext_lr = -1 * (`val_global_pollutants' - `rebound_global' - `wtp_soc_lca' + (`enviro_ext_global' * `enviro_wtp')) * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local fisc_ext_nocc = -1 * (`val_global_pollutants' - `rebound_global' - `wtp_soc_lca') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending =  `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

local total_cost_nocc = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_nocc'

**************************
/* 7. MVPF Calculations */
**************************
local p_name = "`1'"
local MVPF = (`WTP'/`total_cost') + (`enviro_mvpf_raw' + `cost_mvpf') * (`program_cost'/`total_cost')

local MVPF_no_cc = (`WTP_cc' - `cost_wtp' - `enviro_wtp')/`total_cost_nocc'

global MVPF_`p_name' = `MVPF'
global MVPF_no_cc_`p_name' =  `MVPF_no_cc'

global cost_`p_name' = `total_cost'
global WTP_`p_name' = `WTP'
global WTP_cc_`p_name' = `WTP_cc'
global enviro_mvpf_`p_name' = `enviro_mvpf_raw'
global cost_mvpf_`p_name' = `cost_mvpf'
global epsilon_`p_name' = round(`epsilon', 0.001)

global program_cost_`p_name' = `program_cost'
global total_cost_`p_name' = `total_cost'

global fisc_ext_t_`p_name' = `fisc_ext_t'
global fisc_ext_s_`p_name' = `fisc_ext_s'
global fisc_ext_lr_`p_name' = `fisc_ext_lr'

global p_spend_`p_name' = `policy_spending'
global q_CO2_`p_name' = `q_carbon'

global wtp_soc_rbd_`p_name' = -`rebound_local' - `rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global wtp_private_`p_name' = `wtp_private'
global wtp_glob_`p_name' = `val_global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})) -`wtp_soc_lca' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`p_name' = `val_local_pollutants'
global wtp_prod_`p_name' = `wtp_producers'
global wtp_r_loc_`p_name' = -`rebound_local'
global wtp_r_glob_`p_name' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_e_cost_`p_name' = 0
global env_cost_wtp_g_`p_name' = `env_cost_wtp_global'  * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global wtp_society_`p_name' = `wtp_society'

global wtp_consumers_`p_name' = 0
global env_cost_wtp_`p_name' = (`enviro_wtp' * (1 - `enviro_ext_global')) + (`enviro_wtp' * `enviro_ext_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global cost_wtp_`p_name' = `cost_wtp'

global WTP_USPres_`p_name' = `WTP_USPres'
global WTP_USFut_`p_name'  = `WTP_USFut'
global WTP_RoW_`p_name'    = `WTP_RoW'

** for waterfall charts
global wtp_comps_`p_name' wtp_prod wtp_glob wtp_loc wtp_soc_rbd env_cost_wtp cost_wtp WTP_cc
global wtp_comps_`p_name'_commas "wtp_prod", "wtp_glob", "wtp_loc", "wtp_soc_rbd", "env_cost_wtp", "cost_wtp", "WTP_cc"

global cost_comps_`p_name' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`p_name'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"

global `p_name'_xlab 1 `"Producers"' 2 `""Global" "Env""' 3 `""Local" "Env""' 4 `"Rebound"' 5 `""Dynamic" "Env""' 6 `""Dynamic" "Price""' 7 `"Total WTP"' 9 `"Program Cost"' 10 `"Subsidies"' 11 `"Taxes"' 12 `""Climate" "FE""' 13 `""Govt" "Cost""' ///

*color groupings
global color_group1_`p_name' = 1
global color_group2_`p_name' = 4
global color_group3_`p_name' = 6
global cost_color_start_`p_name' = 9
global color_group4_`p_name' = 12

global note_`p_name' = `""'
global normalize_`p_name' = 1

di `MVPF'