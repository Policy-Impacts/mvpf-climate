*************************************************************************************
/*       0. Program:  OPOWER Home Energy Report letters - Aggregated         */
*************************************************************************************

/*
Allcott, Hunt. 
"Social norms and energy conservation." 
Journal of public Economics 95, no. 9-10 (2011): 1082-1095.
* https://www.sciencedirect.com/science/article/pii/S0047272711000478
*/

display `"All the arguments, as typed by the user, are: `0'"'

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
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

	****************************************************
	/* 3a. Emissions Factors */
	****************************************************
	if "${spec_type}" == "baseline"{
		local dollar_year = ${policy_year}
	}
	
	if "${spec_type}" == "current"{
		local dollar_year = ${current_year}
	}
	
*********************************
/* 4. Intermediate Calculations */
*********************************
preserve

	import excel "${assumptions}/policy_category_assumptions_MASTER", first clear sheet("her_compiled")
	replace cost_effectiveness = cost_effectiveness * (${cpi_2009} / ${cpi_2008}) if year == 2008
	
	gen kwh_reduced = .
	gen kwh_weighted = .
	gen cost_weighted = .
	levelsof Experiment, local(levels)	
	foreach exp of local levels {
		replace kwh_reduced = baseline_daily * 365 * `treat_`exp'' if Experiment == "`exp'"
	}
	
	replace kwh_weighted = kwh_reduced * experiment_weight // weighted by treatment size
	replace cost_weighted = experiment_weight * number_nudges
		
	qui sum kwh_weighted
	local kwh_reduced_annual = `r(sum)'
	
	qui sum cost_weighted
	local nominal_cost = `r(sum)'
	local program_cost = `nominal_cost' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})

restore

rebound ${rebound}
local r = `r(r)'
	
*************************
/* 5. WTP Calculations */
*************************
*Consumers
local inframarginal = 0
local marginal = 0
local wtp_consumers = `marginal' + `inframarginal'

*Energy Savings
local c_savings = 0

if "${value_savings}" == "yes" {
	local c_savings = `kwh_reduced_annual' * ${kwh_price_`dollar_year'_${State}}
}

*Producers
local corporate_loss = `kwh_reduced_annual' * ${producer_surplus_`dollar_year'_${State}} * `r'
local util_producer_surplus = ${producer_surplus_`dollar_year'_${State}} // for Latex

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

local wtp_prod_n = -`corporate_loss' / `program_cost' // for Latex

* Social Costs
dynamic_grid `kwh_reduced_annual', starting_year(`dollar_year') lifetime(1) discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants = `r(local_enviro_ext)'
local local_pollutants_n = `local_pollutants' / `program_cost' // for Latex

local global_pollutants = `r(global_enviro_ext)'
local wtp_glob = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local wtp_glob_n = `wtp_glob' / `program_cost' // for Latex
local carbon = `r(carbon_content)'

local q_carbon = `carbon' * `r'

local rebound_local = `local_pollutants' * (1 - `r')
local rebound_local_n = `rebound_local' / `program_cost'

local rebound_global = `global_pollutants' * (1 - `r')
local wtp_r_glob = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local wtp_r_glob_n = `wtp_r_glob' / `program_cost'

local wtp_soc_rbd_n = (-`rebound_local' + `wtp_r_glob') / `program_cost'

* Social benefits from reduced carbon
local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'
local wtp_society_n = `wtp_society' / `program_cost'

* Total WTP
local WTP = `marginal' + `inframarginal' + `wtp_society' - `corporate_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})
local WTP_n = `WTP' / `program_cost' // for Latex

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings'
local WTP_USFut  =     ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************

local fisc_ext_t = `kwh_reduced_annual' * ${government_revenue_`dollar_year'_${State}} * `r'
local tax_rate = ${government_revenue_`dollar_year'_${State}} // for Latex
local utility_fisc_ext = `fisc_ext_t' / `program_cost' // for Latex

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
local fisc_ext_lr_n = `fisc_ext_lr' / `program_cost' // for Latex

local policy_spending = `program_cost'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'
local total_cost_n = `total_cost' / `program_cost' // for Latex

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}

local energy_savings = `kwh_reduced_annual' * `energy_cost'

local her_cost = `program_cost'

local resource_cost = `her_cost' - `energy_savings'
local her_price = `program_cost'
local kwh_reduc = `kwh_reduced_annual'

local q_carbon_mck = `carbon'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon_mck' * `r'

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
global wtp_glob_`1' = `wtp_glob'
global wtp_loc_`1' = `local_pollutants'

global wtp_prod_`1' = -`corporate_loss'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = `wtp_r_glob'
global wtp_soc_rbd_`1' = -`rebound_local' + `wtp_r_glob'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_r_glob wtp_r_loc wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "wtp_r_glob", "wtp_r_loc", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_t fisc_ext_lr cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_t", "fisc_ext_lr", "cost"
global `1'_name "Alcott HERs - Electricity"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `""Rebound" "Global""' 5 `""Rebound" "Local""' 6 `"Utilities"' 7 `"Total WTP"' 9 `""Program" "Cost""' 10 `"Taxes"' 11 `""Climate" "FE""' 12 `""Govt" "Cost""' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 5
global color_group3_`1' = 6
global color_group4_`1' = 6
global cost_color_start_`1' = 9
global color_group5_`1' = 11

// global note_`1' = `"Publication: " "SCC: `scc'" "Description: Cost curve - `cc_def', MVPF definition - `mvpf_def', Subsidy value - `s_def', Grid - `grid_def', Replacement - `replacement_def'," "Grid Model - `grid_model_def', Electricity supply elasticity - `elec_sup_elas'"'
global normalize_`1' = 1

di `MVPF'

if "${latex}" == "yes"{
	if ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs kwh_reduced_annual wtp_glob local_pollutants wtp_r_glob rebound_local wtp_society local_pollutants_n wtp_glob_n rebound_local_n wtp_r_glob_n wtp_soc_rbd_n wtp_society_n wtp_prod_n ///
			  util_producer_surplus WTP_n tax_rate utility_fisc_ext fisc_ext_lr_n MVPF total_cost_n nominal_cost program_cost
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

			local `original' = trim("`: display %5.2fc ``original'''")
			local command = "\newcommand{\\`newname'`1'`4'}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}

}