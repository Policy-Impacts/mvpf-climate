*************************************************************
/* 0. Program: California Alternate Rates for Energy (CARE) */
*************************************************************

/*Hahn, Robert W., and Robert D. Metcalfe. 
"Efficiency and Equity Impacts of Energy Subsidies." 
American Economic Review 111, no. 5 (2021): 1658-88. */
*https://www.aeaweb.org/articles?id=10.1257/aer.20180441
*/

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}

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
local subsidy_percent = 0.2/0.9 // The actual subsidy percent is 20% of the marginal price. We don't observe the marginal price, but we know in context that the price is 0.90 for non-care and care recipients pay 0.7, so we infer a 22% subsidy on the market price
	
if "`4'" == "baseline" | "`4'" == "baseline_gen" {
		
	local ng_price = 0.9
	local subsidy_size = 0.2 // Table in Appendix B.1
}

if "`4'" == "current"{
		
	local ng_price = 10.78 / 10 // From policy_category spreadsheet (Need to change if we change year from 2020)
	local subsidy_size = `ng_price' * `subsidy_percent' // It is a 20% subsidy
}

local admin_cost = (7/109 * `subsidy_size') / (1 - (7/109))
 // Seven million dollars of admin cost out of 109 million of total spending. I scale the subsidy size by the percentage of subsidy size that is admin cost
*********************************
/* 4. Intermediate Calculations */
*********************************

local elasticity = -1 * `consumption_change' / ((21 + 21 + `consumption_change') / 2) / ((`subsidy_size') / ((`ng_price' + (`ng_price' - `subsidy_size')) / 2)) // Formula from the bottom of page 1673
	
local semie = `subsidy_percent' *  `elasticity'

rebound ${rebound}
local r = `r(r_ng)'

*************************
/* 5. WTP Calculations */
*************************
*Consumers
local wtp_cons = `subsidy_size'

*Environment
local local_pollutants = 0

local global_pollutants = ${global_mmbtu_`dollar_year'} / 10 

local carbon_only_benefit = ${carbon_mmbtu_`dollar_year'} / 10

local carbon_reduction = ${lbs_carbon_mmbtu_`dollar_year'} / 10

*Producers
local wtp_prod = (${psurplus_mmbtu_`dollar_year'_${State}} / 10) * - `semie' * `r' 

if "${value_profits}" == "no" {
	local wtp_prod = 0
}

local epsilon = `elasticity'
local val_local_pollutants = `local_pollutants' * `semie' // These components are negative since they are increasing consumption
local val_global_pollutants = `global_pollutants' * `semie' // These components are negative since they are increasing consumption
di `val_global_pollutants'

local rebound_global = -1 * `val_global_pollutants' * (1 - `r') // This is positive

local q_carbon = `val_global_pollutants' / ${sc_CO2_`dollar_year'}

local wtp_soc = `val_local_pollutants' + `val_global_pollutants' + `rebound_global'
local wtp_private = `wtp_cons' + `wtp_prod'

* Total WTP
local WTP = `wtp_private' + `wtp_soc' - ((`val_global_pollutants' + `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}) // not including learning-by-doing

// Quick decomposition
local WTP_USPres = `wtp_private' + `val_local_pollutants'
local WTP_USFut =     ${USShareFutureSSC}  * ((`val_global_pollutants'+`rebound_global') - ((`val_global_pollutants' + `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`val_global_pollutants'+`rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `subsidy_size' + `admin_cost'

local fisc_ext_t = -`semie' * (${govrev_mmbtu_`dollar_year'_${State}} / 10) // Divide by 10 to convert from mmbtu to therms

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = `subsidy_size' * -`semie' * `r' 

local fisc_ext_lr = -1 * (`val_global_pollutants') * ${USShareFutureSSC} * ${USShareGovtFutureSCC} 

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr' 

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local ng_cost = 3.43 * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor form EIA, from ng_citygate tab in policy_category_assumptions_MASTER

local resource_cost = -`ng_cost'
di in red "resource cost is `resource_cost'"

local ng_price = `ng_cost'


local q_carbon_mck = ${global_mmbtu_2020} / ${sc_CO2_2020}

local resource_ce = `resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"

local gov_carbon = `wtp_soc' / ${sc_CO2_`dollar_year'}


****************
/* 8. Output */
****************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `WTP'

global wtp_soc_`1' = `wtp_soc'
global wtp_loc_`1' = `val_local_pollutants'
global wtp_glob_`1' = `val_global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global cost_`1' = `total_cost'


global program_cost_`1' = `program_cost'


global wtp_private_`1' = `wtp_private'
global wtp_cons_`1' = `wtp_cons'


global wtp_r_glob_`1' = `rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global total_cost_`1' = `total_cost'
global wtp_prod_`1' = `wtp_prod'
global admin_cost_`1' = `admin_cost'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'

global q_CO2_`1' = (`wtp_soc' / ${sc_CO2_`dollar_year'}) * -1
global q_CO2_no_`1' = (`wtp_soc' / ${sc_CO2_`dollar_year'}) * -1
global q_CO2_mck_`1' = (`wtp_soc' / ${sc_CO2_`dollar_year'}) / `semie'
global q_CO2_mck_no_`1' = `q_carbon' / `semie'
global resource_cost_`1' = ${ng_price_`dollar_year'_${State}}/10

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'
global semie_`1' = `semie'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "CARE"
global `1'_ep = round(`epsilon', 0.001)

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Rebound" "Global""' 4 `"Producers"' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 3
global color_group3_`1' = 4
global cost_color_start_`1' = 7
global color_group4_`1' = 10

global normalize_`1' = 0

di "`1'"
di `wtp_private'
di `CE'
di `epsilon'

di `wtp_cons'
di `wtp_prod'
di `wtp_soc'

di `val_local_pollutants'
di `val_global_pollutants'

di `semie'

di `WTP'
di `program_cost'
di `fisc_ext'
di `total_cost'
di `MVPF'
di ${admin_cost_`1'}

di `WTP'/`total_cost'
di ${policy_year}
di `q_carbon'

di `val_global_pollutants'
di `rebound_global'
di `wtp_prod'
	
	
	
	
	
	
	