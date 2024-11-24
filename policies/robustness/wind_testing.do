**************************************************
/*       0. Program: PTC Wind subsidies    (TESTING)          */
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

local replacement = "${replacement}"
local corporate_discount = "no" // Either no or yes (yes if you want a special corporate discount rate)

local capacity_constant = "no" // Either no or yes, (yes if you want the capacity factor in 2007 to equal the capacity factor in 2020)

// global spec_type = "`4'"

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
		
		if "${spec_type}" == "baseline"{
			local dollar_year = ${policy_year}
		}
		
		if "${spec_type}" == "current"{
			local dollar_year = ${current_year}
		}
	restore
	
	if "${spec_type}" == "baseline_gen" {
		local dollar_year = ${feed_in_year}
	}
	
	if `dollar_year' > 2020 {
		local inflation_year = 2020
	}
	
	if `dollar_year' <= 2020 {
		local inflation_year = `dollar_year'
	}

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
	
	if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
		local capacity_factor = 0.29 // https://www.energy.gov/sites/default/files/2021-08/Land-Based%20Wind%20Market%20Report%202021%20Edition_Full%20Report_FINAL.pdf
		local average_size = 1.65 // in MW frrom https://pubs.usgs.gov/sir/2011/5036/sir2011-5036.pdf
		
		local current_ptc = 0.015 * (${cpi_`inflation_year'}/${cpi_1992}) // Enacted in 1992 and inflation adjusted
		
		if `dollar_year' > 2020 {
			local current_ptc = 0.026 * (${cpi_`inflation_year'}/${cpi_2021})
		}
	}
	local capacity_factor_context = 0.29

	// Just for the 2010 - 2030 harmonized version
	local capacity_factor = ${capacity_factor}
	local average_size = ${average_size}
	
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
local prod_cost = 1527704 * `average_size' * (${cpi_`inflation_year'}/${cpi_2021}) // per MW in 2020
local cum_sales = 742689 / `average_size' // 742689 2020 or 93924 2007, world numbers
local marg_sales = 92490 / `average_size' // 92490 for 2020 or 2007 is 19967, world numbers
local cost_per_mw = 1527704 * (${cpi_`inflation_year'}/${cpi_2021})
// local alpha = 0.61 // EIA Annual Energy Outlook

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	local prod_cost = 2129288 * `average_size' * (${cpi_`inflation_year'}/${cpi_2021}) // per MW in 2007
	local cum_sales = 93924 / `average_size'
	local marg_sales = 19967 / `average_size'
	local cost_per_mw = 2129288 * (${cpi_`inflation_year'}/${cpi_2021})
	
// 	local alpha = 0.851 // https://www.eia.gov/renewable/annual/trends/pdf/table1.pdf
}

local cost_per_mw_context = 2129288 * (${cpi_${policy_year}}/${cpi_2021}) // per MW in 2007


*Getting the elasticity
local pos_cap = 612
local zero_cap = 20908
// local semie = -`lpm'/(`pos_cap'/(`pos_cap' + `zero_cap'))
// di `semie'

local output_per_mw_context = (`hrs' * `capacity_factor_context' * 1000 * `credit_life') + (`hrs' * `capacity_factor_context' * (1 - `capacity_factor_context') * 1000 * (`lifetime' - `credit_life'))

local output_per_mw = (`hrs' * `capacity_factor' * 1000 * `credit_life') + (`hrs' * `capacity_factor' * (1 - `capacity_factor') * 1000 * (`lifetime' - `credit_life'))

// local epsilon = `semie' / (0.01/(`cost_per_mw_context'/`output_per_mw_context'))
local epsilon = -1 * ${feed_in_elas}
local semie = `epsilon' * (0.01 / (`cost_per_mw'/`output_per_mw'))

if "`capacity_constant'" == "yes" {
	local semie = `semie' * (`capacity_factor_context'/`capacity_factor')
}

local annual_kwh = `average_size' * `hrs'*`capacity_factor' * 1000 // After the first ten years we need to scale this down by the capacity reduction factor

rebound ${rebound}
local r = `r(r)'

* Social Costs
dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // First 10 years
local f10_local_pollutants = `r(local_enviro_ext)'
local f10_global_pollutants = `r(global_enviro_ext)'
local carbon = `r(carbon_content)'
	
local new_annual_kwh = (1 - `capacity_reduction') * `annual_kwh'

dynamic_grid `new_annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // Total 20 years
local t20_local_pollutants = `r(local_enviro_ext)'
local t20_global_pollutants = `r(global_enviro_ext)'
local carbon = `carbon' + `r(carbon_content)'

dynamic_grid `new_annual_kwh', starting_year(`dollar_year') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // First 10 years with lower capacity factor
local inter_local_pollutants = `r(local_enviro_ext)'
local inter_global_pollutants = `r(global_enviro_ext)'
local carbon = `carbon' - `r(carbon_content)'

local local_pollutants = `f10_local_pollutants' + (`t20_local_pollutants' - `inter_local_pollutants')
local global_pollutants = `f10_global_pollutants' + (`t20_global_pollutants' - `inter_global_pollutants')

local env_cost = (((`wind_emissions' * 1/1000000 * `annual_kwh' * (${sc_CO2_`dollar_year'} * ${cpi_${policy_year}}/${cpi_2020}))/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) /// first 10 years have a higher capacity factor than the next ten years
 + (((`wind_emissions' * 1/1000000 * `annual_kwh' * (${sc_CO2_`dollar_year'} * ${cpi_${policy_year}}/${cpi_2020}) * (1 - `capacity_reduction'))/`discount') * (1 - (1/(1+`discount')^(`lifetime'))) - ((`wind_emissions' * 1/1000000 * `annual_kwh' * (${sc_CO2_`dollar_year'} * ${cpi_${policy_year}}/${cpi_2020}) * (1 - `capacity_reduction'))/`discount') * (1 - (1/(1+`discount')^(`credit_life'))))) * `r'

local q_carbon = ((`carbon' * `r') + (`wind_emissions' * 1/1000000 * `annual_kwh' * `credit_life') + (`wind_emissions' * 1/1000000 * `annual_kwh' * (`lifetime' - `credit_life') * (1 - `capacity_reduction'))) * -`semie'

local val_local_pollutants = `local_pollutants' * -`semie'
local val_global_pollutants = `global_pollutants' * -`semie'
local rebound_local = `local_pollutants' * (1-`r') * -`semie'
local rebound_global = `global_pollutants' * (1-`r') * -`semie'

local val_env_cost = `env_cost' * -`semie'

*************************
/* 5. WTP Calculations */
*************************
* Society
local wtp_society = `val_local_pollutants' + `val_global_pollutants' - `val_env_cost' - `rebound_local' - `rebound_global'

* Private
local wtp_producers = ((`average_size' * `hrs'*`capacity_factor')/`corporate_disc') * (1 - (1/(1+`corporate_disc')^(`credit_life'))) * 1000 * 0.01

local wtp_private = `wtp_producers'

local enviro_ext = `local_pollutants' + `global_pollutants' - `env_cost' - ((`local_pollutants' + `global_pollutants') * (1-`r'))

local enviro_ext_global = (`global_pollutants' - (`global_pollutants') * (1-`r')) / `enviro_ext'


*temporary solution -> if bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0 {
	local epsilon = - 0.001
}

*Cost Curve Calculation
local program_cost = ((`average_size' * `hrs' * `capacity_factor' * 1000 * 0.01)/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) // for a $0.01 per kwh subsidy

cost_curve_mvpf, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') enviro_ext(`enviro_ext') cost(`prod_cost')
local cost_wtp = `r(cost_mvpf)' * `program_cost'
local enviro_wtp = `r(enviro_mvpf)' *  `program_cost'

local cost_curve_carbon = ((`q_carbon'/-`semie') / `enviro_ext') * `enviro_wtp'
local q_carbon = `q_carbon' + `cost_curve_carbon'

local WTP = `wtp_private' + `wtp_society'
local WTP_cc = `WTP' + `cost_wtp' + `enviro_wtp'

local WTP_USPres = `wtp_private' + `val_local_pollutants' - `rebound_local' + ((1-`enviro_ext_global') * `enviro_wtp')
local WTP_USFut = ${USShareFutureSSC} * (`val_global_pollutants' - `rebound_global' - `val_env_cost' + (`enviro_ext_global' * `enviro_wtp')) + `cost_wtp' * ${US_windshare}
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`val_global_pollutants' - `rebound_global' - `val_env_cost' + (`enviro_ext_global' * `enviro_wtp')) + `cost_wtp' * (1 - ${US_windshare})

**************************
/* 6. Cost Calculations  */
**************************
// local program_cost = ((`average_size' * `hrs' * `capacity_factor' * 1000 * 0.01)/`discount') * (1 - (1/(1+`discount')^(`credit_life'))) // for a $0.01 per kwh subsidy // Already added above

local fisc_ext_s = ((`average_size' * `hrs'* `capacity_factor' * 1000 * -`semie' * `current_ptc')/`discount') * (1 - (1/(1+`discount')^(`credit_life')))

local fisc_ext_t = 0 // Need to edit this to add rebound effect gov rev (should be negative)

local fisc_ext_lr = -1 * (`val_global_pollutants' - `rebound_global' + (`enviro_ext_global' * `enviro_wtp')) * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending =  `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = (`WTP'/`total_cost') + (`r(enviro_mvpf)' + `r(cost_mvpf)') * (`program_cost'/`total_cost')
local MVPF_no_cc = (`WTP_cc' - `cost_wtp' - `enviro_wtp')/`total_cost'

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
global MVPF_no_cc_`1' =  `MVPF_no_cc'

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
// global fisc_ext_`1' = `fiscal_externality'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

global wtp_private_`1' = `wtp_private'
global wtp_glob_`1' = `val_global_pollutants'
global wtp_loc_`1' = `val_local_pollutants'
global wtp_prod_`1' = `wtp_producers'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global'
global wtp_e_cost_`1' = -`val_env_cost'

global wtp_society_`1' = `wtp_society'

global wtp_consumers_`1' = 0
global env_cost_wtp_`1' = `enviro_wtp'
global cost_wtp_`1' = `cost_wtp'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

** for waterfall charts

global wtp_comps_`1' wtp_prod wtp_glob wtp_loc wtp_e_cost wtp_r_glob wtp_r_loc env_cost_wtp cost_wtp WTP_cc
global wtp_comps_`1'_commas "wtp_prod", "wtp_glob", "wtp_loc", "wtp_e_cost", "wtp_r_glob", "wtp_r_loc", "env_cost_wtp", "cost_wtp", "WTP_cc"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Hitaj PTC"
global `1'_ep = round(`epsilon', 0.001)

global `1'_xlab 1 `"Producers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `""Enviro" "Cost""' 5 `""Rebound" "Global""' 6 `""Rebound" "Local""' 7 `""Dynamic" "Enviro""' 8 `""Dynamic" "Price""' 9 `"Total WTP"' 11 `"Program Cost"' 12 `""FE" "Subsidies""' 13 `""FE" "Taxes""' 14 `""FE" "Long-Run""' 15 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 6
global color_group3_`1' = 8
global cost_color_start_`1' = 11
global color_group4_`1' = 14



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
di `total_cost'

di `WTP'/`total_cost'
di `MVPF_no_cc'

di `epsilon'
di `e_demand'
di `semie'
di `val_local_pollutants'
di `val_global_pollutants'
di `val_env_cost'
di `enviro_ext'
di `MVPF'
di `q_carbon'
di `carbon_reduction'
di `carbon_only_benefit'
di `cost_curve_carbon'
di `cost_curve_CO2'
di `q_carbon'
di `enviro_wtp'
di `enviro_ext_global'