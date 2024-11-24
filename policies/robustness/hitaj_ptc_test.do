**************************************************
/*       0. Program: PTC Wind subsidies              */
**************************************************

/*
Hitaj, Claudia. 
"Wind power development in the United States." 
Journal of Environmental Economics and Management 65.3 (2013): 394-410.
*/

*Policy variation is at the $0.01 per kwh

********************************
/* 1. Pull Global Assumptions */
********************************
local discount = ${discount_rate}

local replacement = "average" // Either coal_mix, marginal, or average
local corporate_discount = "no" // Either no or yes (yes if you want a special corporate discount rate)


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
if "`bootstrap'" != "yes" {
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

	****************************************************
	/* 3a. Emissions Factors */
	****************************************************
	preserve
		
		if inlist("${spec_type}", "baseline", "baseline_general"){
			local dollar_year = ${policy_year}
		}
		
		if "${spec_type}" == "current"{
			local dollar_year = ${current_year}
		}
	restore

	****************************************************
	/* 3b. Policy Category Assumptions */
	****************************************************
	
	*i. Import Wind assumptions
	preserve
		import excel "${assumptions}/policy_category_assumptions_v1", first clear sheet("Wind")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local lifetime = ${lifetime}
		local capacity_factor = ${capacity_factor} // capacity factor for wind
		local average_size = ${average_size}
		local credit_life = ${credit_life}
		local current_ptc = ${current_ptc}
		local capacity_reduction = ${capacity_reduction}
		local wind_emissions = ${wind_emissions}

	restore
	
	if "${spec_type}" == "baseline" {
		local capacity_factor = 0.29 // https://www.energy.gov/sites/default/files/2021-08/Land-Based%20Wind%20Market%20Report%202021%20Edition_Full%20Report_FINAL.pdf
		local average_size = 1.65 // in MW frrom https://pubs.usgs.gov/sir/2011/5036/sir2011-5036.pdf
		local current_ptc = 0.015 * (${cpi_`dollar_year'}/${cpi_1992}) // Enacted in 1992 and inflation adjusted
	}
	
	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	local hrs = 8760 // hours per year
	local corporate_disc = `discount'
	
	if "`corporate_discount'" == "yes" {
		** lending
		local frac_debt = 0.3 // fraction of project financed with debt
		local i = 0.086 // corporate lending rate
		local tau = 0.393 // effective tax rate
		local pi = 0.03 // inflation rate
		local E = 0.07 // equity rate of return

		** discounting
		local corporate_disc = `frac_debt'*[`i'*(1-`tau')-`pi']+(1-`frac_debt')*`E' // corporate discount rate
		local dep = 0.0303 // economic depreciation
	}

*********************************
/* 4. Intermediate Calculations */
*********************************

*Learning by Doing Assumptions
local prod_cost = 1527704 * `average_size' * (${cpi_`dollar_year'}/${cpi_2021}) // per MW in 2020
local cum_sales = 742689 / `average_size' // 742689 2020 or 93924 2007, world numbers
local marg_sales = 92490 / `average_size' // 92490 for 2020 or 2007 is 19967, world numbers

if "${spec_type} "== "baseline" {
	local prod_cost = 2129288 * `average_size' * (${cpi_`dollar_year'}/${cpi_2021})// per MW in 2007
	local cum_sales = 93924 / `average_size'
	local marg_sales = 19967 / `average_size'
}

*Getting the elasticity
local pos_cap = 612
local zero_cap = 20908
local semie = -`lpm'/(`pos_cap'/(`pos_cap' + `zero_cap'))

local output_per_mw = (`hrs' * `capacity_factor' * 1000 * `credit_life') + (`hrs' * `capacity_factor' * (1 - `capacity_reduction') * 1000 * (`lifetime' - `credit_life'))

local epsilon = `semie' * (1/(0.01 / (`prod_cost' / `output_per_mw'))) // ratio of subsidy to cost of production

if "`replacement'" == "coal_mix"{
	local l_env_benefit = ${local_kwh_HIGH_`dollar_year'}
	local g_env_benefit = ${global_kwh_HIGH_`dollar_year'}
}

if "`replacement'" == "marginal" {
	local l_env_benefit = ${local_wind_${State}_`dollar_year'}
	local g_env_benefit = ${global_wind_${State}_`dollar_year'}
}

if "`replacement'" == "average" {
	local l_env_benefit = ${local_kwh_${State}_`dollar_year'}
	local g_env_benefit = ${global_kwh_${State}_`dollar_year'}
}

if ${discount_rate} == 0.03{
	local dr = 3
}
if ${discount_rate} == 0.025{
	local dr = 25
}
if ${discount_rate} == 0.05{
	local dr = 5
}

local annual_kwh = `average_size' * `hrs'*`capacity_factor' * 1000 // After the first ten years we need to scale this down by the capacity reduction factor

* Social Costs
local local_pollutants = ((`l_env_benefit' * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) /// first 10 years have a higher capacity factor than the next ten years
 + (((`l_env_benefit' * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`lifetime'))) - ((`l_env_benefit' * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))))


local global_pollutants = ((`g_env_benefit' * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) /// first 10 years have a higher capacity factor than the next ten years
 + (((`g_env_benefit' * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`lifetime'))) - ((`g_env_benefit' * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))))
 
local env_cost = ((`wind_emissions' * 1/1000000 * `annual_kwh' * ${baseline_scc_`dollar_year'_`dr'})/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) /// first 10 years have a higher capacity factor than the next ten years
 + (((`wind_emissions' * 1/1000000 * `annual_kwh' * ${baseline_scc_`dollar_year'_`dr'} * (1 - `capacity_reduction'))/`discount') * (1 - (1/(1+`discount')^(`lifetime'))) - ((`wind_emissions' * 1/1000000 * `annual_kwh' * ${baseline_scc_`dollar_year'_`dr'} * (1 - `capacity_reduction'))/`discount') * (1 - (1/(1+`discount')^(`credit_life'))))

local carbon_only_benefit = ((${sc_kwh_carbon_${State}_`dollar_year'} * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) /// first 10 years have a higher capacity factor than the next ten years
 + (((${sc_kwh_carbon_${State}_`dollar_year'} * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`lifetime'))) - ((${sc_kwh_carbon_${State}_`dollar_year'} * (1 - `capacity_reduction') * `annual_kwh')/`discount') * (1 - (1/(1+`discount')^(`credit_life'))))


local carbon_reduction = (${carbon_kwh_${State}_`dollar_year'} * `annual_kwh' * `credit_life') + (${carbon_kwh_${State}_`dollar_year'} * `annual_kwh' * (1 - `capacity_reduction') * (`lifetime' - `credit_life'))

local val_local_pollutants = `local_pollutants' * -`semie'
local val_global_pollutants = `global_pollutants' * -`semie'
local val_env_cost = `env_cost' * -`semie'

**************************
/* 5. Cost Calculations  */
**************************
local program_cost = ((`average_size' * `hrs' * `capacity_factor' * 1000 * 0.01)/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) // for a $0.01 per kwh subsidy

local fiscal_externality = ((`average_size' * `hrs'* `capacity_factor' * 1000 * -`semie' * `current_ptc')/`discount') * (1 - (1/(1+`discount')^(`credit_life')))

local total_cost = `program_cost' + `fiscal_externality'

*************************
/* 6. WTP Calculations */
*************************
* Society
local wtp_society = `val_local_pollutants' + `val_global_pollutants' - `val_env_cost'

* Private
local wtp_producers = ((`average_size' * `hrs'*`capacity_factor')/`corporate_disc') * (1 - (1/(1+`corporate_disc')^(`credit_life'))) * 1000 * 0.01

local wtp_private = `wtp_producers'

local enviro_ext = `local_pollutants' + `global_pollutants' - `env_cost'

*Cost Curve Calculation
cost_curve_mvpf, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') enviro_ext(`enviro_ext') cost(`prod_cost')
local cost_wtp = `r(cost_mvpf)' * `program_cost'
local enviro_wtp = `r(enviro_mvpf)' *  `program_cost'

local WTP = `wtp_private' + `wtp_society'
local WTP_cc = `WTP' + `cost_wtp' + `enviro_wtp'

local WTP_USPres = `wtp_private' + `val_local_pollutants' + `cost_wtp'
local WTP_USFut = ${USShareFutureSSC} * (`val_global_pollutants' + `enviro_wtp')
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`val_global_pollutants' + `enviro_wtp')

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = (`WTP'/`total_cost') + (`r(enviro_mvpf)' + `r(cost_mvpf)') * (`program_cost'/`total_cost')
local MVPF_no_cc = (`WTP_cc' - `cost_wtp' - `enviro_wtp')/`total_cost'
local CE = `program_cost'/`carbon_reduction'

****************
/* 9. Outputs */
****************

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global WTP_cc_`1' = `WTP_cc'
global enviro_mvpf_`1' = `r(enviro_mvpf)'
global cost_mvpf_`1' = `r(cost_mvpf)'
global epsilon_`1' = round(`epsilon', 0.001)

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
global fisc_ext_`1' = `fiscal_externality'

global wtp_private_`1' = `wtp_private'

global wtp_society_`1' = `wtp_society'
global CE_`1' = `CE' // $/ton abated

global wtp_consumers_`1' = 0
global env_cost_wtp_`1' = `enviro_wtp'
global cost_wtp_`1' = `cost_wtp'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'



di "`1'"
di `wtp_private'
di `CE'
di `r(enviro_mvpf)'
di `r(cost_mvpf)'

di `wtp_producers'
di `wtp_society'

di `enviro_wtp'
di `cost_wtp'
di `WTP_cc'

di `program_cost'
di `fiscal_externality'
di `total_cost'
di `MVPF'

di `WTP'/`total_cost'
di `MVPF_no_cc'

di `epsilon'
di `e_demand'
di `semie'
di `val_local_pollutants'
di `val_global_pollutants'
di `val_env_cost'
di `enviro_ext'
