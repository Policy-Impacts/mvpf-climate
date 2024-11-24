*************************************************************************************
/*       0. Program:  Peak Energy Reports           */
*************************************************************************************

/*
"The Impact of Demand Response
on Energy Consumption and Economic Welfare" 
https://www.rmetcalfe.net/_files/ugd/fe9abe_1407ffb825d44414846a665885c513a5.pdf
*/

/*
"Testing for crowd out in social nudges: 
Evidence from a natural field experiment in the market for electricity"
https://www.pnas.org/doi/10.1073/pnas.1802874115
*/
********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}
local replacement = "${replacement}"
global spec_type = "`4'"

local mc_assumption = "high" // can be low, high, or vll

if "${PER_robustness}" == "yes" {
	local mc_assumption = "${PER_mc}"
}

/* The low case represents a marginal cost of 0.5 for the next kwh whereas high represents a marginal cost of 1 for 
the next kwh. The vll case assumes there will be blackout so it is transferring a kwh from one person to another person 
valued at the vll */

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

*i. Import energy rebate assumptions
preserve
	import excel "${policy_assumptions}", first clear sheet("energy_rebate")
	
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}
		
restore


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
local tons_per_lb = 0.000453592

*We are assuming the marginal kWh during peak times is coming from coal
*All emissions factors are from eGRID 2020
local ch4_coal = 0.2412 * `tons_per_lb' // tons/MWh
local nox_coal = 1.401 * `tons_per_lb' // tons/MWh
local so2_coal = 1.959 * `tons_per_lb' // tons/MWh
local co2_coal = 2165.370 * `tons_per_lb' // tons/MWh

// Unweighted == weighted by electricity generation, not VMT.
local so2_cost = ${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
local nox_cost = ${md_NOx_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})

local co2_cost = ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
local ch4_cost = ${sc_CH4_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})


local env_local_per_kwh = ((`nox_cost' * `nox_coal') + (`so2_coal' * `so2_cost')) / 1000 

local env_global_per_kwh = ((`ch4_coal' * `ch4_cost') + (`co2_coal' * `co2_cost')) / 1000 // Total enviro ends up being about 2 times higher than the AVERT marginal kwh enviro benefit

local marginal_cost = 0.5 // cost of the next kwh during peak times

if "`mc_assumption'" == "high" {
	local marginal_cost = 1 // cost of the next kwh during peak times
}

local baseline_consumption = 0.65 // kWh/hr from paper, exp(-0.428) from Figure 5 of Brandon et al. 

local hours = 5 // Length of the peak times from the paper
local cost = 0.1 // direct cost of the intervention per person

local vll = 4.292 * (${cpi_`dollar_year'}/${cpi_2020}) // $/kWh - Value of Lost Load. Converted from /MWh to /KWh. Reported in 2020 dollars. https://media.rff.org/documents/WP_23-10.pdf


*********************************
/* 4. Intermediate Calculations */
*********************************
local kwh_reduction = `baseline_consumption' * `hours' * `ATE' * -1

*Using standard assumptions that 28% of utilities are public and a 10% profit tax
local profit_loss_private = (${kwh_price_2020_US} - `marginal_cost') * (1 - ${utility_public}) * (1 - ${utility_profit}) * `kwh_reduction'
local kwh_price = ${kwh_price_2020_US} // for Latex

local profit_loss_public =  ((${kwh_price_2020_US} - `marginal_cost') * ${utility_public} * `kwh_reduction') + ///
							((${kwh_price_2020_US} - `marginal_cost') * (1 - ${utility_public}) * ${utility_profit} * `kwh_reduction')
local profit_pub_rev = (${kwh_price_2020_US} - `marginal_cost') * ${utility_public} * `kwh_reduction' // for Latex
local profit_pri_rev = (${kwh_price_2020_US} - `marginal_cost') * (1 - ${utility_public}) * ${utility_profit} * `kwh_reduction' // for Latex

if "`mc_assumption'" == "vll" {
	local profit_loss_private = 0 
	local profit_loss_public = 0
}

local program_cost = `cost'

*************************
/* 5. WTP Calculations */
*************************
local wtp_consumers = 0

local wtp_producers = -1 * `profit_loss_private' // They lose money in the absence of this policy so they have a positive wtp. Don't do same for public loss b/c cost decreases. 
local wtp_prod_n = `wtp_producers' / `program_cost' // for Latex

* Social Costs
local local_pollutants = `kwh_reduction' * `env_local_per_kwh'
local local_pollutants_n = `local_pollutants' / `program_cost' // for Latex

local global_pollutants = `kwh_reduction' * `env_global_per_kwh'
local wtp_glob = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local wtp_glob_n = `wtp_glob' / `program_cost' // for Latex

if "`mc_assumption'" == "vll" {
	local wtp_consumers = `vll' * `kwh_reduction'
	local local_pollutants = 0
	local global_pollutants = 0
}

local wtp_consumers_n = `wtp_consumers' / `program_cost' // for Latex

* Social benefits from reduced carbon
local wtp_society = `global_pollutants' + `local_pollutants'
local wtp_soc = `wtp_glob' + `local_pollutants'
local wtp_soc_n = `wtp_soc' / `program_cost' 

local q_carbon = (`co2_coal' / 1000) * `kwh_reduction'

if "`mc_assumption'" == "vll" {
	local q_carbon = 0
}

* Total WTP
local WTP = `wtp_consumers' + `wtp_society' + `wtp_producers' - (`global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC})
local WTP_n = `WTP' / `program_cost' // for Latex

// Quick decomposition
local WTP_USPres = `wtp_consumers' + `local_pollutants' + `wtp_producers'
local WTP_USFut  =     ${USShareFutureSSC}  * (`global_pollutants' - (`global_pollutants' * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * `global_pollutants'

**************************
/* 6. Cost Calculations  */
**************************


local fisc_ext_t = `profit_loss_public' // Saves government money b/c utilities don't lose as much.
local fisc_ext_t_n = `fisc_ext_t' / `program_cost' // for Latex

local fisc_ext_s = 0

local fisc_ext_lr = -1 * `global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
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
local energy_cost = 1

local energy_savings = `kwh_reduction' * `energy_cost'

local per_cost = `program_cost'

local resource_cost = `per_cost' - `energy_savings'
local per_price = `program_cost'
local kwh_reduc = `kwh_reduction'

local q_carbon_mck = `kwh_reduction' * (`ch4_coal' + `co2_coal') / 1000

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon_mck'

****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'
global wtp_soc_`1' = `wtp_society'
global wtp_cons_`1' = `wtp_consumers'
global wtp_glob_`1' = `wtp_glob'
global wtp_loc_`1' = `local_pollutants'

global wtp_prod_`1' = `wtp_producers'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global q_CO2_`1' = `q_carbon'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "PER - `mc_assumption'"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `"Producers"' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 3
global color_group3_`1' = 4
global color_group4_`1' = 4
global cost_color_start_`1' = 7
global color_group5_`1' = 10


global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1

di `MVPF'
di `total_cost'
di `WTP'
di `global_pollutants' + `local_pollutants'
di `kwh_reduction'
di `WTP_USPres' + `WTP_USFut' + `WTP_RoW'


if "${latex}" == "yes"{
	if ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs kwh_reduction wtp_glob local_pollutants wtp_soc local_pollutants_n wtp_glob_n wtp_soc_n wtp_prod_n ///
			  util_producer_surplus WTP_n tax_rate utility_fisc_ext fisc_ext_lr_n MVPF total_cost_n program_cost env_local_per_kwh ///
			  env_global_per_kwh global_pollutants kwh_price profit_loss_private profit_pub_rev profit_pri_rev fisc_ext_t_n ///
			  wtp_consumers_n
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy/macros_`1'_`4'_`mc_assumption'.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'_`mc_assumption'}" _n
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
			local command = "\newcommand{\\`newname'`1'`4'`mc_assumption'}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}

}