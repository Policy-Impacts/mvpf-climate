*************************************************************************************
/*       0. Program: Refridgerator Rebate Program in Southern California       */
*************************************************************************************

/*
Joshua A. Blonz
"The Costs of Misaligned Incentives: Energy Inefficiency and the Principal-Agent Problem" 

* https://pubs.aeaweb.org/doi/pdfplus/10.1257/pol.20210208
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
****************************************************
/* 3c. Policy Specific Assumptions */
****************************************************
local avg_rebate = 850 // Table 2

local years_qualified = ln(1 - 266/(57/0.03)) / -ln(1.03) // From Table 3 and the Appendix (pg 34), we can back out the average years they accelerated their replacement. We use the average capital replacement and labor costs and the fact that the annual cost is $57 discounted at a 3% rate  

local years_unqualified = ln(1 - 333/(57/0.03)) / -ln(1.03) // Same calculation as above

local prop_marginal = 1 // We assume everyone is temporally changing their purchase decison
local prop_qualified = 3715 / (3715 + 1261) // figures from paper

****************************************************
/* 3d. Inflation Adjusted Values */
****************************************************
*Convert rebate to current dollars
local adj_rebate = `avg_rebate' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})

*********************************
/* 4. Intermediate Calculations */
*********************************
 
local kwh_reduction_q = `qualified_kwh' * 12
local kwh_reduction_unq = `unqualified_kwh' * 12

*Need integer years for dynamic grid
local years_qualified = round(`years_qualified')
local years_unqualified = round(`years_unqualified')

rebound ${rebound}
local r = `r(r)'

*************************
/* 5. WTP Calculations */
*************************
* Consumers
local inframarginal = (1-`prop_marginal') * `adj_rebate'

local marginal =  (`prop_marginal' * 0.5 * `adj_rebate')

* Energy Savings
local c_savings = 0

if "${value_savings}" == "yes" {
	local annual_savings_q = (`prop_marginal' * `prop_qualified' * (`kwh_reduction_q' * ${kwh_price_`dollar_year'_${State}}))
	
	local annual_savings_unq = (`prop_marginal' * (1 - `prop_qualified') * (`kwh_reduction_unq' * ${kwh_price_`dollar_year'_${State}}))
	
	local c_savings = `annual_savings_q' + (`annual_savings_q'/`discount') * (1 - (1/(1+`discount')^(`years_qualified' - 1))) + `annual_savings_unq' + (`annual_savings_unq'/`discount') * (1 - (1/(1+`discount')^(`years_unqualified' -1)))
}

*Producers
local annual_prod_q = (`prop_marginal' * `prop_qualified' * (`kwh_reduction_q' * ${producer_surplus_`dollar_year'_${State}}))

local annual_prod_unq = (`prop_marginal' * (1 - `prop_qualified') * (`kwh_reduction_unq' * ${producer_surplus_`dollar_year'_${State}}))

local corporate_loss = (`annual_prod_q' + (`annual_prod_q'/`discount') * (1 - (1/(1+`discount')^(`years_qualified' - 1))) + `annual_prod_unq' + (`annual_prod_unq'/`discount') * (1 - (1/(1+`discount')^(`years_unqualified' - 1)))) * `r'

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

* Social Costs
dynamic_grid `kwh_reduction_q', starting_year(`dollar_year') lifetime(`years_qualified') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants_q = `r(local_enviro_ext)'
local global_pollutants_q = `r(global_enviro_ext)'
local carbon_q = `r(carbon_content)'

dynamic_grid `kwh_reduction_unq', starting_year(`dollar_year') lifetime(`years_unqualified') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants_uq = `r(local_enviro_ext)'
local global_pollutants_uq = `r(global_enviro_ext)'
local carbon_unq = `r(carbon_content)'

local local_pollutants = `prop_marginal' * (`prop_qualified' * `local_pollutants_q' + ((1 - `prop_qualified') * `local_pollutants_uq'))
local global_pollutants = `prop_marginal' * (`prop_qualified' * `global_pollutants_q' + ((1 - `prop_qualified') * `global_pollutants_uq'))
local q_carbon = `prop_marginal' * (`prop_qualified' * `carbon_q' + ((1 - `prop_qualified') * `carbon_unq')) * `r'

local rebound_local = `local_pollutants' * (1-`r')
local rebound_global = `global_pollutants' * (1-`r')

local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local WTP = `marginal' + `inframarginal' + `wtp_society' - `corporate_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings'
local WTP_USFut  =     ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `adj_rebate'

local annual_fe_t_q = (`prop_marginal' * `prop_qualified' * (`kwh_reduction_q' * ${government_revenue_`dollar_year'_${State}}))

local annual_fe_t_unq = (`prop_marginal' * (1 - `prop_qualified') * (`kwh_reduction_unq' * ${government_revenue_`dollar_year'_${State}}))

local fisc_ext_t = (`annual_fe_t_q' + (`annual_fe_t_q'/`discount') * (1 - (1/(1+`discount')^(`years_qualified' - 1))) + `annual_fe_t_unq' + (`annual_fe_t_unq'/`discount') * (1 - (1/(1+`discount')^(`years_unqualified' - 1)))) * `r'

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}
 
local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}

local fridge_energy_savings = (`prop_qualified' * `kwh_reduction_q' * `energy_cost') + ((`prop_qualified' * (`kwh_reduction_q' * `energy_cost')) / `discount') * (1 - (1 / (1 + `discount')^(`years_qualified' - 1))) + ///
							  ((1 - `prop_qualified') * (`kwh_reduction_unq' * `energy_cost')) + (((1 - `prop_qualified') * (`kwh_reduction_unq' * `energy_cost')) / `discount') * (1 - (1 / (1 + `discount')^(`years_unqualified' - 1)))

local fridge_cost = -184.13454 // difference between ES and non-ES fridge prices

local resource_cost = `fridge_cost' - `fridge_energy_savings'

local q_carbon_mck = `q_carbon' / (`prop_marginal' * `r')

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon'

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
global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Fridge Rebates (Blonz)"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Global" "Enviro""' 4 `""Local" "Enviro""' 5 `""Rebound" "Local""' 6 `""Rebound" "Global""' 7 `"Producers"' 8 `"Total WTP"' 10 `""Program" "Cost""' 11 `""FE" "Subsidies""' 12 `""FE" "Taxes""' 13 `""FE" "Long-Run""' 14 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 6
global color_group3_`1' = 7
global cost_color_start_`1' = 10
global color_group4_`1' = 13



di `MVPF'
di `WTP'
di `total_cost'
di `wtp_society'
di `wtp_private'
di `prop_inframarginal'
di `inframarginal'
di `marginal'

di `CE'
di `carbon_reduction'
di `fiscal_externality'
di `program_cost'
di `corporate_loss'
di `global_pollutants' + `local_pollutants'
di `years_qualified'
di `years_unqualified'