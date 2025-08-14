*************************************************************************************
/*       0. Program:  California's electricity rebate program            */
*************************************************************************************

/*
Ito, Koichiro. 
"Asymmetric incentives in subsidies: Evidence from a large-scale electricity rebate program." 
American Economic Journal: Economic Policy 7, no. 3 (2015): 209-37.
* https://www.aeaweb.org/articles?id=10.1257/pol.20130397
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
*i. Import energy rebate assumptions
preserve
	import excel "${policy_assumptions}", first clear sheet("energy_rebate")
	
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}	
restore

	local marginal_valuation = ${val_given}
	
****************************************************
/* 3c. Policy Specific Assumptions */
****************************************************
** Cost assumptions
local rebate_cost_coastal = 9358919 // (Table 8 row 3)
local rebate_cost_inland = 1250621 // (Table 8 row 3)
local rebate_cost = `rebate_cost_coastal' + `rebate_cost_inland'
local indirect_cost = 4000000 // SCE spent ~$4M to administer and advertise program (Wirtshafter Associates 2006)
* energy consumption 2005 (Kwh)

local consump_coastal_base	= 8247457920 * (1 + (1 - exp(`LATE_coastal'))) // (Table 8 row 2)
local consump_inland_base	= 1154292248 * (1 + (1 - exp(`LATE_inland'))) // (Table 8 row 2)

****************************************************
/* 3d. Inflation Adjusted Values */
****************************************************
*Convert rebate to current dollars
local adj_indirect = `indirect_cost' * (${cpi_`dollar_year'}/${cpi_${policy_year}})
local adj_rebate = `rebate_cost' * (${cpi_`dollar_year'}/${cpi_${policy_year}})

*********************************
/* 4. Intermediate Calculations */
*********************************
** Energy reductions (Kwh)
local energy_reduction_coastal = `consump_coastal_base'* (1 - exp(`LATE_coastal'))
local energy_reduction_inland = `consump_inland_base'* (1 - exp(`LATE_inland'))

local kwh_reduction_today = `energy_reduction_coastal' + `energy_reduction_inland'
local kwh_reduction_06 = `consump_inland_base'* (1 - exp(`LATE_inland_06'))
local kwh_reduction_07 = `consump_inland_base'* (1 - exp(`LATE_inland_07'))
local kwh_reduction_08 = `consump_inland_base'* (1 - exp(`LATE_inland_08'))

local prop_inframarginal = 9358919 / (9358919 + 1250621) // We need the marginal inframarginal split to value the rebate. This number is difficult to estimate w/ the information provided in the paper. Since the coastal group saw no decline in consumption, we assume everyone is inframarginal and we assume everyone in the inland group is marginal. We take the ratio of costs in Table 8 to estimate the inframarginal share 

local prop_marginal = 1 - `prop_inframarginal'

rebound ${rebound}
local r = `r(r)'

*************************
/* 5. WTP Calculations */
*************************
*Consumers
local inframarginal = `prop_inframarginal' * `adj_rebate'
local marginal = 0 // Marginal people do not value the rebate at the margin since they already get energy savings

*Energy Savings
local c_savings = 0

if "${value_savings}" == "yes" {
	local c_savings = ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_today') + /// 
					  ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_06')/(1+`discount')) + ///
					  ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_07')/(1+`discount')^2) + ///
					  ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_08')/(1+`discount')^3))
}

*Producers
local corporate_loss = ((${producer_surplus_`dollar_year'_${State}} * `kwh_reduction_today') + ((${producer_surplus_`dollar_year'_${State}} * `kwh_reduction_06')/(1+`discount')) + ((${producer_surplus_`dollar_year'_${State}} * `kwh_reduction_07')/(1+`discount')^2) + ((${producer_surplus_`dollar_year'_${State}} * `kwh_reduction_08')/(1+`discount')^3)) * `r'

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

local c_savings = 0
if "${value_savings}" == "yes" {
	local c_savings = ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_today') + ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_06')/(1+`discount')) + ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_07')/(1+`discount')^2) + ((${kwh_price_`dollar_year'_${State}} * `kwh_reduction_08')/(1+`discount')^3))
}

* Social Costs
local end_year = `dollar_year' + 3
local kwh_reduction = `kwh_reduction_today'
local i = 1
local local_pollutants = 0
local global_pollutants = 0
local carbon = 0
forvalues y = `dollar_year'(1)`end_year'{
	
	dynamic_split_grid `kwh_reduction', starting_year(`dollar_year') ext_year(`y') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
	local local_pollutants = `local_pollutants' + `r(local_enviro_ext)'
	local global_pollutants = `global_pollutants' + `r(global_enviro_ext)'
	local carbon = `carbon' + `r(carbon_content)'
	local i = `i' + 1
	
	if `i' == 2 {
		local kwh_reduction = `kwh_reduction_06'
	}
	
	if `i' == 3 {
		local kwh_reduction = `kwh_reduction_07'
	}
	
	if `i' == 4 {
		local kwh_reduction = `kwh_reduction_08'
	}
}
local q_carbon = `carbon' * `r'

local rebound_local = `local_pollutants' * (1 -`r')
local rebound_global = `global_pollutants' * (1 -`r')

local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local WTP = `marginal' + `inframarginal' + `wtp_society' - `corporate_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings'
local WTP_USFut  =     ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `adj_rebate' + `adj_indirect'

local program_cost_no_ind = `adj_rebate'

local fisc_ext_t = ((${government_revenue_`dollar_year'_${State}} * `kwh_reduction_today') + ((${government_revenue_`dollar_year'_${State}} * `kwh_reduction_06')/(1+`discount')) + ((${government_revenue_`dollar_year'_${State}} * `kwh_reduction_07')/(1+`discount')^2) + ((${government_revenue_`dollar_year'_${State}} * `kwh_reduction_08')/(1+`discount')^3)) * `r'

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'
local total_cost_no_ind = `program_cost_no_ind' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'
local MVPF_no_ind = `WTP' / `total_cost_no_ind'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}
local ca_electric_savings = ((`energy_cost' * `kwh_reduction_today') + ///
							((`energy_cost' * `kwh_reduction_06') / (1 + `discount')) + ///
							((`energy_cost' * `kwh_reduction_07') / (1 + `discount')^2) + ///
							((`energy_cost' * `kwh_reduction_08') / (1+`discount')^3))

local ca_electric_savings = -abs(`ca_electric_savings')

local resource_cost = `ca_electric_savings'
di in red "electricity savings are `ca_electric_savings'"
local q_carbon_mck = `q_carbon' / `r'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon_mck'

****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF_no_ind'
global cost_`1' = `total_cost_no_ind'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost_no_ind'
global wtp_soc_`1' = `wtp_society'
global prop_infra_`1' = `prop_inframarginal'
global wtp_marg_`1' = `marginal'
global wtp_inf_`1' = `inframarginal'
global c_savings_`1' = `c_savings' 
global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global total_cost_`1' = `total_cost_no_ind'
global wtp_prod_`1' = -`corporate_loss'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global c_savings_`1' = `c_savings'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'
global admin_cost_`1' = `adj_indirect'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

** for waterfall charts
global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "CA Electricity Rebates"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Global" "Enviro""' 4 `""Local" "Enviro""' 5 `""Rebound" "Local""' 6 `""Rebound" "Global""' 7 `"Producers"' 8 `"Total WTP"' 10 `""Program" "Cost""' 11 `""FE" "Subsidies""' 12 `""FE" "Taxes""' 13 `""FE" "Long-Run""' 14 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 6
global color_group3_`1' = 7
global cost_color_start_`1' = 10
global color_group4_`1' = 13

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1


di in red "Main Estimates"
di "`4'"
di `MVPF'
di `WTP'
di `total_cost'
di `wtp_society'
di `inframarginal'
di `marginal'

di `CE'

di `carbon_cost'
di `pollutant_cost'
di `fiscal_externality'
di `program_cost'
di `corporate_loss'
di `global_pollutants' + `local_pollutants'
di in red (`inframarginal' + `marginal')/`program_cost_no_ind'
di in red `dollar_year'
