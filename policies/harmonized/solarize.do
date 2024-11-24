********************************************************************************
/*       0. Program: Solarize Program                                         */
********************************************************************************

/*
Social Learning and Solar Photovoltaic Adoption: Evidence from a Field Experiment
Kenneth Gillingham & Bryan Bollinger
*https://resources.environment.yale.edu/gillingham/GillinghamBollinger_SocialLearningPV.pdf
*/

display `"All the arguments, as typed by the user, are: `0'"'

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}


global solar_lca_co2e 40 // grams of CO2e per KWh, from NREL  https://www.nrel.gov/docs/fy13osti/56487.pdf
local solar_lca_co2e = ${solar_lca_co2e} / 1000000 // in g/kWh, so need to divide by 1e6 to get t/kWh

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
	
	****************************************************
	/* 3b. Policy Category Assumptions */
	****************************************************

	*i. Import Solar assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("Solar")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local system_capacity = ${system_capacity}
		local annual_output = ${output} / (${system_capacity} * 1000)
		local lifetime = ${lifetime}
		local federal_subsidy = 0.26
		local cost_per_watt = ${cost_per_watt}
		local marginal_val = ${marginal_val}
		local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'}/${cpi_2022})
	restore
	
	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	
	** Cost assumptions
	local cost_per_install = 860 // bottom of page 7108 in 2014$
	local avg_rebate_rate = 0 // Assume that there is no state tax credit for US-wide specs
	
	
	if "${spec_type}" == "baseline" {
		local federal_subsidy = 0.30 // 30% ITC
		local system_capacity =  6.972 // Using Gillingham Hurdles & Steps paper
		local annual_output =  32.26 / 25 // kWh/Watt, output per unit of installed capacity over 25-year lifespan (pg 302) of Hurdles & Steps paper
		local avg_rebate_rate = 1.25 // From page 33
		local cost_per_watt = 4.63 * (${cpi_`dollar_year'}/${cpi_2014}) // 2014 value from paper
	}
	
	local price_disc = -`price_disc'
	local price_disc_spillover = -`price_disc_spillover'
	
	local price_discount = `price_disc' / 4.63 // price discount from treatment, Table 2
	local price_reduction = `price_discount' * `cost_per_watt' // price discount in dollars per watt
	
	local price_discount_spill = `price_disc_spillover' / 4.63 // price discount from treatment
	local price_reduction_spill = `price_discount_spill' * `cost_per_watt' // price discount in dollars per watt
	
	if "${spec_type}" == "baseline_gen" {
		local federal_subsidy = 0.30 // 30% ITC
		local system_capacity =  ${system_capacity}
		local annual_output =  ${output} / (${system_capacity} * 1000)
		local avg_rebate_rate = 0
		local cost_per_watt = 5.40 // NREL 2012 cost
	}
	****************************************************
	/* 3d. Inflation Adjusted Values */
	****************************************************
	*Convert rebate to current dollars
	local adj_cost_per_install= `cost_per_install' * (${cpi_`dollar_year'}/${cpi_${policy_year}})
	
	
*********************************
/* 4. Intermediate Calculations */
*********************************

rebound ${rebound}
local r = `r(r)'

local rebound_percent = (1 - `r') * 100 // for Latex
	
local installs = `installs' * 5.6 // treatment effect times number of months
local spillover = `spillover' * 5.6 // treatment effect times number of months
	
local kwh_per_install = `system_capacity' * `annual_output' * 1000
local annual_kwh = `kwh_per_install' * (`installs' + `spillover')

* Social Costs
dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("solar") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants = `r(local_enviro_ext)'
local global_pollutants = `r(global_enviro_ext)'
local carbon = `r(carbon_content)'

local rebound_local = `local_pollutants' * (1-`r')
local rebound_global = `global_pollutants' * (1-`r')

local lca_annual = `annual_kwh' * `solar_lca_co2e' * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}))
	
local lca_ext = `lca_annual' + (`lca_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1 )))

// LCA externality
local wtp_society_lca = -`lca_ext'

local q_carbon = ((`carbon' * `r') - (`annual_kwh' * `solar_lca_co2e' * `lifetime'))
local q_carbon_mck = ((`carbon' * `r') - (`annual_kwh' * `solar_lca_co2e' * `lifetime'))

**************************
/* 5. Cost Calculations  */
**************************

local program_cost = `adj_cost_per_install' * `installs' // Price to encourage installs
local state_fisc_ext = `avg_rebate_rate' * `system_capacity' * 1000 * (`installs' + `spillover') // each additional subsidy costs CT $1.25 per Watt
local state_fisc_ext_n = `state_fisc_ext' / `program_cost' // for Latex

local federal_fisc_ext = ((`cost_per_watt' - `price_reduction') * `system_capacity' * 1000 * (`installs') * `federal_subsidy') + ///
						 ((`cost_per_watt' - `price_reduction_spill') * `system_capacity' * 1000 * (`spillover') * `federal_subsidy')

local treated_muni_cost = (`cost_per_watt' - `price_reduction') * `system_capacity' * 1000 // for Latex
local treated_muni_fed_fe = `treated_muni_cost' * `installs' * `federal_subsidy' // for Latex

local spill_muni_fed_fe = (`cost_per_watt' - `price_reduction_spill') * `system_capacity' * 1000 * (`spillover') * `federal_subsidy' // for Latex

local fed_fisc_ext_n = `federal_fisc_ext' / `program_cost' // for Latex

local annual_fe_t = `annual_kwh' * ${government_revenue_`dollar_year'_${State}}
local gov_rev = ${government_revenue_`dollar_year'_${State}} // for Latex

local fisc_ext_t = `annual_fe_t' + (`annual_fe_t' / `discount') * (1 - (1 / (1 + `discount')^(`lifetime' - 1))) * `r'
local fisc_ext_t_n = `fisc_ext_t' / `program_cost' // for Latex

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = `state_fisc_ext' + `federal_fisc_ext'

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global' + `wtp_society_lca') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
local fisc_ext_lr_n = `fisc_ext_lr' / `program_cost' // for Latex

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'
local total_cost_n = `total_cost' / `program_cost' // for Latex

*************************
/* 6. WTP Calculations */
*************************
* Society
local wtp_society_raw = `local_pollutants' + `global_pollutants' - `rebound_local' - `rebound_global'
local wtp_glob = (`global_pollutants' * (1 - ${USShareGovtFutureSCC} * ${USShareFutureSSC})) / `program_cost' // for Latex
local wtp_loc = `local_pollutants' / `program_cost' // for Latex
local wtp_r_glob = (-`rebound_global' * (1 - ${USShareGovtFutureSCC} * ${USShareFutureSSC})) / `program_cost' // for Latex
local wtp_r_loc = -`rebound_local' / `program_cost' // for Latex

local wtp_society = `wtp_society_raw' + `wtp_society_lca'

* Private
local wtp_consumers = (`marginal_val' * `system_capacity' * 1000 * `installs' * `price_reduction') + ///
					  (`marginal_val' * `system_capacity' * 1000 * `spillover' * `price_reduction_spill') // They value half of the price reduction

local wtp_consumers_n = `wtp_consumers' / `program_cost' // for Latex

local wtp_cons_treat = `marginal_val' * `system_capacity' * 1000 * `installs' * `price_reduction' // for Latex
local wtp_cons_treat_n = `wtp_cons_treat' / `program_cost' // for Latex
local wtp_cons_spill = `marginal_val' * `system_capacity' * 1000 * `spillover' * `price_reduction_spill' // for Latex
local wtp_cons_spill_n = `wtp_cons_spill' / `program_cost' // for Latex

local c_savings = 0

if "${value_savings}" == "yes" {
	
	local annual_savings = `annual_kwh' * ${kwh_price_`dollar_year'_${State}}
	local c_savings = `annual_savings' + (`annual_savings'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) // No rebound effect here. 

}

local wtp_producers = ((`annual_kwh' * ${producer_surplus_`dollar_year'_${State}}) + ///
					  ((`annual_kwh' * ${producer_surplus_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `r'

local wtp_prod = -`wtp_producers' / `program_cost' // for Latex

local markup = ${producer_surplus_`dollar_year'_${State}} // for Latex


if "${value_profits}" == "no" {
	local wtp_producers = 0
}

local wtp_private = `wtp_consumers' - `wtp_producers'


* Total WTP
local WTP = `wtp_private' + `wtp_society' + `c_savings' - ((`global_pollutants' + `wtp_society_lca' - `rebound_global') * ${USShareGovtFutureSCC} * ${USShareFutureSSC})  // not including learning-by-doing
local WTP_n = `WTP' / `program_cost' // for Latex

// local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp'
local WTP_USPres = `wtp_private' + `local_pollutants' - `rebound_local'
local WTP_USFut =      ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global' + `wtp_society_lca') - ((`global_pollutants' + `wtp_society_lca' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global' + `wtp_society_lca')


local ratio = `wtp_glob' / (`fisc_ext_s' / `program_cost')

di in red "ratio is `ratio'"
pause
**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${kwh_price_2020_US} - ${producer_surplus_2020_US} - ${government_revenue_2020_US}

local energy_savings = `kwh_per_install' * `energy_cost' * (((1 + `discount')^`lifetime' - 1) / (`discount' * (1 + `discount')^(`lifetime' - 1)))

local solar_cost = `adj_cost_per_install' + `cost_per_watt_baseline' * (`system_capacity' * 1000)

local resource_cost = `solar_cost' - `energy_savings'
local solarize_price = `solar_cost'
local kwh_reduc = `kwh_per_install'

dynamic_grid `kwh_per_install', starting_year(2020) lifetime(`lifetime') discount_rate(`discount') ef("marginal") type("solar") geo("US") grid_specify("yes") model("midpoint")
local carbon = `r(carbon_content)'

local q_carbon_mck = `carbon' - (`kwh_per_install' * `solar_lca_co2e' * `lifetime')

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = (`carbon' * `r') - (`kwh_per_install' * `solar_lca_co2e' * `lifetime')
****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'
global wtp_soc_`1' = `wtp_society'
global wtp_cons_`1' = `wtp_consumers'
global c_savings_`1' = `c_savings'
global wtp_private_`1' = `wtp_private'
global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'

global wtp_prod_`1' = -`wtp_producers'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_e_cost_`1' = `wtp_society_lca' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'
global q_CO2_mck_`1' = `q_carbon_mck'
global resource_cost_`1' = `cost_per_watt_baseline' * (`system_capacity'*1000)

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_e_cost wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "wtp_e_cost", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "cost"
global `1'_name "Solarize CT"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `""Enviro" "Cost""' 5 `""Rebound" "Local""' 6 `""Rebound" "Global""' 7 `"Producers"' 8 `"Total WTP"' 10 `""Program" "Cost""' 11 `""FE" "Subsidies""' 12 `""FE" "Taxes""' 13 `""FE" "Long-Run""' 14 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 5
global color_group3_`1' = 7
global color_group4_`1' = 7
global cost_color_start_`1' = 10
global color_group5_`1' = 13

global normalize_`1' = 1


di "`1'"
di `wtp_private'
di `wtp_society_raw'
di `wtp_society_lca'
di `CE'

di `global_pollutants'
di `local_pollutants'
di `wtp_consumers'
di `wtp_producers'
di `wtp_society'
di `WTP'
di `program_cost'
di `fisc_ext'
di `total_cost'
di `MVPF'
di `wtp_society_lca'
di `WTP'

if "${latex}" == "yes"{
	if ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs wtp_cons_treat wtp_cons_spill wtp_consumers system_capacity kwh_per_install annual_kwh wtp_glob wtp_loc ///
		              rebound_percent wtp_r_glob wtp_r_loc markup wtp_prod WTP_n global_pollutants local_pollutants fed_fisc_ext_n ///
					  state_fisc_ext_n program_cost gov_rev fisc_ext_t fisc_ext_t_n fisc_ext_lr_n total_cost_n MVPF wtp_cons_treat_n ///
					  wtp_cons_spill_n wtp_consumers_n cost_per_watt treated_muni_cost treated_muni_fed_fe spill_muni_fed_fe
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy/macros_`1'_`4'.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'}" _n
		foreach i of local outputs{

			local original = "`i'"
			local newname = "`i'"

			// Remove underscores from the variable name
			while strpos("`newname'", "_"){
				local newname = subinstr("`newname'", "_", "", .)
			}
			local 1 = subinstr("`1'", "_", "", .)
			local 4 = subinstr("`4'", "_", "", .)

			if inlist("`i'", "kwh_per_install", "annual_kwh", "fisc_ext_t", "program_cost", "global_pollutants", "local_pollutants", "wtp_cons_treat", "wtp", "treated_muni_cost") | ///
			   inlist("`i'", "spill_muni_fed_fe", "treated_muni_fed_fe"){
				local `original' = trim("`: display %9.0fc ``original'''")
			}
			else if inlist("`i'", "wtp_cons_spill_n"){
				local `original' = trim("`: display %5.3fc ``original'''")
			}
			else{
				local `original' = trim("`: display %5.2fc ``original'''")
			}
			local command = "\newcommand{\\`newname'`1'`4'}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}

}
	