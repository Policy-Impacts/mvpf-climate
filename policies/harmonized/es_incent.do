*************************************************************************************
/*       0. Program: Energy Star Sales Agent Nudge        */
*************************************************************************************

/*
Allcott, Hunt, and Richard L. Sweeney. 
"The role of sales agents in information disclosure: evidence from a field experiment." 
Management Science 63.1 (2017): 21-39.
*/
* https://pubsonline.informs.org/doi/abs/10.1287/mnsc.2015.2327
*$100 Rebate & Sales Agent Incentive

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
preserve
	import excel "${policy_assumptions}", first clear sheet("energy_rebate")
	
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}
	
	local lifetime = ${appliance_lifetimes} // 13, 15, or 18 yrs - Footnote 10
	local marginal_valuation = ${val_given}
restore
****************************************************
/* 3c. Policy Specific Assumptions */
****************************************************
	
** Cost assumptions:
local rebate = 100 // 2012 $USD  (Table 6)
local sales_incentive = 25 // 2012 $USD Sales Incentive
local Baseline_prob = 0.009 // Specification (6) (Table 6)
local baseline_mmbtu = 22.7 // https://www.eia.gov/todayinenergy/detail.php?id=37433
local mmbtu_saving_prop = 0.08 // https://www.energystar.gov/products/water_heaters/water_heater_high_efficiency_gas_storage/benefits_savings

****************************************************
/* 3d. Inflation Adjusted Values */
****************************************************
*Convert rebate to current dollars
local adj_rebate = `rebate' * (${cpi_`dollar_year'}/${cpi_${policy_year}})
local adj_incentive = `sales_incentive' * (${cpi_`dollar_year'}/${cpi_${policy_year}})

***********************************
/* 4. Intermediate Calculations */
***********************************
local mmbtu_reduction_annual = `mmbtu_saving_prop' * `baseline_mmbtu' // Assumes value for avg 4-person HH
local prop_inframarginal = `Baseline_prob' / (`TE_prob'+`Baseline_prob')
local prop_marginal = 1 - `prop_inframarginal'

rebound ${rebound}
local r = `r(r)'
local r_ng = `r(r_ng)'

*************************
/* 5. WTP Calculations */
*************************
*Consumers
local inframarginal = `prop_inframarginal' * `adj_rebate'
local marginal = `prop_marginal' * `marginal_valuation' * `adj_rebate'
local wtp_consumers = `marginal' + `inframarginal'

*Energy Savings
local c_savings = 0

if "${value_savings}" == "yes" {

	local annual_savings = `prop_marginal' * `mmbtu_reduction_annual' * ${ng_price_`dollar_year'_${State}}
	
	local c_savings = `annual_savings' + (`annual_savings'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))
}

*Producers

local annual_prod = `prop_marginal' * `mmbtu_reduction_annual' * ${psurplus_mmbtu_`dollar_year'_${State}}

local corporate_loss = (`annual_prod' + (`annual_prod'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `r_ng'

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

* Social Costs
local local_pollutants = 0
local global_pollutants = (`prop_marginal' * ${global_mmbtu_`dollar_year'} * `mmbtu_reduction_annual') + ((`prop_marginal' * ${global_mmbtu_`dollar_year'} * `mmbtu_reduction_annual') / `discount') * (1 - (1 / (1+`discount')^(`lifetime' - 1)))

local rebound_local = `local_pollutants' * (1-`r_ng')
local rebound_global = `global_pollutants' * (1-`r_ng')

local q_carbon = `prop_marginal' * `lifetime' * `mmbtu_reduction_annual' * (${global_mmbtu_`dollar_year'}/ ${sc_CO2_`dollar_year'}) * `r_ng'

* Social benefits from reduced carbon 
local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

* Total WTP
local WTP = `marginal' + `inframarginal' + `wtp_society' - `corporate_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings'
local WTP_USFut  =  ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `adj_rebate' + `adj_incentive'

local annual_fe_t = `prop_marginal' * `mmbtu_reduction_annual' * ${govrev_mmbtu_`dollar_year'_${State}}
local fisc_ext_t = (`annual_fe_t' + (`annual_fe_t'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `r_ng'


if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local ng_cost = 3.43 * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor form EIA, from ng_citygate tab in policy_category_assumptions_MASTER

local water_heater_energy_savings = (`mmbtu_reduction_annual' * `ng_cost') + ((`mmbtu_reduction_annual' * `ng_cost') / `discount') * (1 - (1 / (1+`discount')^(`lifetime' - 1)))

local water_heater_cost = 386.3243

local sticker_price = `water_heater_cost' + `adj_incentive'
di in red "sticker price is `sticker_price'"
di in red "energy savings are `water_heater_energy_savings'"

local q_carbon_mck = `lifetime' * (${global_mmbtu_2020} / ${sc_CO2_2020}) * `mmbtu_reduction_annual'
di in red "carbon is `q_carbon_mck'"
local resource_cost = `water_heater_cost' + `adj_incentive' - `water_heater_energy_savings'
local energy_savings = `water_heater_energy_savings'
local sticker_price = `water_heater_cost'
local mmbtu_reduc = `mmbtu_reduction_annual' * `lifetime'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `prop_marginal' * `q_carbon_mck' * `r_ng'

****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'
global wtp_soc_`1' = `wtp_society'
global wtp_marg_`1' = `marginal'
global wtp_inf_`1' = `inframarginal'
global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global total_cost_`1' = `total_cost'
global wtp_prod_`1' = -`corporate_loss'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global c_savings_`1' = `c_savings'

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
global wtp_comps_`1' wtp_marg wtp_inf c_savings wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "c_savings", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Water Heater Rebates + Incentive"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Consumer" "Savings""' 4 `""Global" "Enviro""' 5 `""Local" "Enviro""' 6 `""Rebound" "Local""' 7 `""Rebound" "Global""' 8 `"Producers"' 9 `"Total WTP"' 11 `""Program" "Cost""' 12 `""FE" "Subsidies""' 13 `""FE" "Taxes""' 14 `""FE" "Long-Run""' 15 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 3
global color_group2_`1' = 7
global color_group3_`1' = 8
global cost_color_start_`1' = 11
global color_group4_`1' = 14

// global note_`1' = `"Publication: " "SCC: `scc'" "Description: Cost curve - `cc_def', MVPF definition - `mvpf_def', Subsidy value - `s_def', Grid - `grid_def', Replacement - `replacement_def'," "Grid Model - `grid_model_def', Electricity supply elasticity - `elec_sup_elas'"'
global normalize_`1' = 1
global note_`1' = `""'

