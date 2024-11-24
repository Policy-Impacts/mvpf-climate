********************************************************************************
/*       0. Program: Nudging Energy Efficiency Audits RCT                     */
********************************************************************************

/*
Kenneth Gillingham, Tsvetan Tsvetanov. 
"Nudging energy efficiency audits: Evidence from a field experiment." 
Journal of Environmental Economics and Management, Volume 90, 2018, Pages 303-316, ISSN 0095-0696.
* https://doi.org/10.1016/j.jeem.2018.06.009
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
	

	****************************************************
	/* 3b. Policy Category Assumptions */
	****************************************************	
	local annual_energy_use = 10566 // US 2020: https://www.eia.gov/consumption/residential/
	
	
	if "${spec_type}" == "baseline" {
		local annual_energy_use = 7794 // Electricity consumption in Connecticut in 2020 from https://www.eia.gov/consumption/residential/ (consumption is fairly stable over time) // Deviates from what the paper reports
	}

	*Paper assumes that an audit leads to 5% energy reduction and the impacts last for 5 years (Section 4.3)
	local audit_savings = 0.05
	local years_impact = 5

	* cost
	local cost_per_card = 2.40 * (${cpi_`dollar_year'}/${cpi_${policy_year}}) // (Section 4.3)

*********************************
/* 4. Intermediate Calculations */
*********************************

*Number of cards needed to cause one successful audit
local audit_estimate = 1 - (1 - `audit_impact')^6 // The paper does not give enough information to precisely convert their reduced form estimate to a impact on overall likelihood to apply. Using the footnote on pg 312 and using the fact that their estimate leads to a 6.5 percentage point reduction, I can estimate T (days) to be 6.

local cards_for_audit = 1 / `audit_estimate' // This is the number of treated units for every successful audit
local program_cost = `cost_per_card' * `cards_for_audit'

*Benefits of one audit
local kwh_reduced_annual = `audit_savings' * `annual_energy_use'

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
	local c_savings = (`kwh_reduced_annual' * ${kwh_price_`dollar_year'_${State}}) + (((`kwh_reduced_annual' * ${kwh_price_`dollar_year'_${State}}))/`discount') * (1 - (1/(1+`discount')^(`years_impact' - 1)))
}

*Producers
local corporate_loss = ((`kwh_reduced_annual' * ${producer_surplus_`dollar_year'_${State}}) + (((`kwh_reduced_annual' * ${producer_surplus_`dollar_year'_${State}}))/`discount') * (1 - (1/(1+`discount')^(`years_impact' - 1)))) * `r'
local util_producer_surplus = ${producer_surplus_`dollar_year'_${State}} // for Latex

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

local wtp_prod_n = -`corporate_loss' / `program_cost' // for Latex

* Social Costs
dynamic_grid `kwh_reduced_annual', starting_year(`dollar_year') lifetime(`years_impact') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
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
local annual_fe_t = `kwh_reduced_annual' * ${government_revenue_`dollar_year'_${State}}
local gov_rev = ${government_revenue_`dollar_year'_${State}} // for Latex

local fisc_ext_t = `annual_fe_t' + (`annual_fe_t' / `discount') * (1 - (1 / (1 + `discount')^(`years_impact' - 1))) * `r'
local tax_rate = ${government_revenue_`dollar_year'_${State}} // for Latex
local utility_fisc_ext = `fisc_ext_t' / `program_cost' // for Latex
local fisc_ext_t_n = `fisc_ext_t' / `program_cost' // for Latex

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = ((99 * (0.571)) + (75 * (1 - 0.571))) * (${cpi_`dollar_year'} / ${cpi_${policy_year}}) // Need to take into account cost of audit

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

local energy_savings = `kwh_reduced_annual' * `years_impact' * `energy_cost'

local nudge_cost = `program_cost'

local resource_cost = `nudge_cost' - `energy_savings'
local nudge_price = `program_cost'
local kwh_reduc = `kwh_reduced_annual' * `years_impact'

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
global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'

global wtp_prod_`1' = -`corporate_loss'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

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
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Energy Audit Nudge"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `""Rebound" "Local""' 5 `""Rebound" "Global""' 6 `"Producers"' 7 `"Total WTP"' 9 `""Program" "Cost""' 10 `""FE" "Subsidies""' 11 `""FE" "Taxes""' 12 `""FE" "Long-Run""' 13 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 5
global color_group3_`1' = 6
global cost_color_start_`1' = 9
global color_group4_`1' = 12


di `program_cost'
di `fiscal_externality'
di `total_cost'
di `WTP'
di `wtp_consumers'
di `corporate_loss'
di `wtp_society'
di `total_cost'
di `MVPF'
di `local_pollutants'
di `global_pollutants'

if "${latex}" == "yes"{
	if ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs kwh_reduced_annual wtp_consumers wtp_glob wtp_loc wtp_r_glob wtp_r_loc wtp_prod WTP_n global_pollutants local_pollutants ///
					  program_cost gov_rev fisc_ext_t fisc_ext_t_n fisc_ext_lr_n total_cost_n MVPF wtp_glob_n local_pollutants_n wtp_soc_rbd_n ///
					  wtp_society_n util_producer_surplus wtp_prod_n tax_rate utility_fisc_ext audit_estimate cards_for_audit
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

			if inlist("`i'", "fisc_ext_t", "global_pollutants", "local_pollutants"){
				local `original' = trim("`: display %9.0fc ``original'''")
			}
			else if inlist("`i'", "audit_estimate"){
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
