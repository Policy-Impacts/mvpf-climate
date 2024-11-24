*************************************************************************************
/*    0. Program:  Critical Peak Pricing - Passive Joiners          */
*************************************************************************************

/*
"Default Effects and Follow-On Behaviour: Evidence from An Electricity Pricing Program"
Fowlie, M, Wolfram, C, Baylis, P, et al 
https://escholarship.org/content/qt3wv2r6t2/qt3wv2r6t2.pdf
*/

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}
local replacement = "${replacement}"

global spec_type = "`4'"

local mc_assumption = "high" // can be low, high, or vll

*The low case represents a marginal cost of 0.5 for the next kwh whereas high represents a marginal cost of 1 for the next kwh. The vll case assumes there will be blackout so it is transferring a kwh from one person to another person valued at the vll

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
if "`4'" == "baseline"{
	local dollar_year = ${policy_year}
}
	
if "`4'" == "current"{
	local dollar_year = ${current_year}
}


****************************************************
/* 3b. Policy Specific Assumptions */
****************************************************
local tons_per_lb = 0.0004536

*We are assuming the marginal KWh during peak times is coming from Coal
*All emissions factors are from eGRID 2020
local ch4_coal = 0.2412 * `tons_per_lb' // tons/MWh
local nox_coal = 1.401 * `tons_per_lb' // tons/MWh
local so2_coal = 1.959 * `tons_per_lb' // tons/MWh
local co2_coal = 2165.370 * `tons_per_lb' // tons/MWh


// Unweighted == weighted by electricity generation, not VMT.
local so2_cost = ${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'}/${cpi_${md_dollar_year}})
local nox_cost = ${md_NOx_`dollar_year'_unweighted} * (${cpi_`dollar_year'}/${cpi_${md_dollar_year}})

local co2_cost = ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}})
local ch4_cost = ${sc_CH4_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}})

local env_local_per_kwh = ((`nox_cost' * `nox_coal') + (`so2_coal' * `so2_cost')) / 1000 

local env_global_per_kwh = ((`ch4_coal' * ${sc_CH4_2020}) + (`co2_coal' * ${sc_CO2_2020})) / 1000 // Total enviro ends up being about 2 times higher than the AVERT marginal kwh enviro benefit

local marginal_cost = 0.5 // cost of the next kwh during peak times from Rob - this is somewhere betwen 0.5 and 1

if "`mc_assumption'" == "high" {
	local marginal_cost = 1 // cost of the next kwh during peak times from Rob - this is somewhere betwen 0.5 and 1
}

local vll = 4.292 // $/kWh - Value of Lost Load


*********************************
/* 4. Intermediate Calculations */
*********************************
*Using standard assumptions that 28% of utilities are public and a 10% profit tax
local profit_loss_private = (${kwh_price_2020_US} - `marginal_cost') * (1 - ${utility_public}) * (1 - ${utility_profit})

local profit_loss_public =  ((${kwh_price_2020_US} - `marginal_cost') * ${utility_public}) + ((${kwh_price_2020_US} - `marginal_cost') * (1 - ${utility_public}) * ${utility_profit})

if "`mc_assumption'" == "vll" {
	local profit_loss_private = 0 
	local profit_loss_public = 0
}

if "${value_profits}" == "no" {
	local profit_loss_private = 0 
	local profit_loss_public = 0
}

local epsilon = (`ATE' / 2.49)/3.50
local semie = (`epsilon' / ${kwh_price_2020_US}) * (1/100) * -1

*************************
/* 5. WTP Calculations */
*************************
local wtp_cons = .01 // Increasing the price of electricity in peak times by 1 cent

local wtp_producers = `profit_loss_private' * `semie' // They lose money in the absence of this policy so they have a positive wtp

local global_pollutants = -1 * `env_global_per_kwh' * `semie'
local local_pollutants = -1 * `env_local_per_kwh' * `semie'

if "`mc_assumption'" == "vll" {
	local wtp_cons = .01 - `vll' * `semie'
	local local_pollutants = 0
	local global_pollutants = 0
}

local wtp_society = `global_pollutants' + `local_pollutants'

local q_carbon = (`co2_coal'/1000) * `semie'

if "`mc_assumption'" == "vll" {
	local q_carbon = 0
}
* Total WTP
local WTP = `wtp_cons' + `wtp_society' + `wtp_producers' - (`global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = `wtp_cons' + `local_pollutants' + `wtp_producers'
local WTP_USFut =     ${USShareFutureSSC}  * (`global_pollutants' - (`global_pollutants' * ${USShareGovtFutureSCC}))
local WTP_RoW = (1 - ${USShareFutureSSC}) * `global_pollutants'

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = .01 // Increasing the price of electricity in peak times by 1 cent

local fisc_ext_t = `profit_loss_public' * `semie' * -1

local fisc_ext_s = 0

local fisc_ext_lr = -1 * `global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = 1

local resource_cost = 1

local q_carbon_mck = (`ch4_coal' + `co2_coal') / 1000

local resource_ce = -`resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon_mck' * `semie' 

****************
/* 8. Output */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'


global wtp_soc_`1' = `wtp_society'
global wtp_cons_`1' = `wtp_cons'
global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global total_cost_`1' = `total_cost'
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
global semie_`1' = `semie'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob", "wtp_loc", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "CPP - `mc_assumption'"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `"Producers"' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 3
global color_group3_`1' = 4
global cost_color_start_`1' = 7
global color_group4_`1' = 10

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1



















