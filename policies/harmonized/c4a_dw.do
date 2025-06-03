*************************************************************************************
/*       0. Program: Energy Efficient Appliance Rebate -- STAR Dishwashers        */
*************************************************************************************

/*
Houde, Sébastien, and Joseph E. Aldy. 
"Consumers' response to state energy efficient appliance rebate programs." 
American Economic Journal: Economic Policy 9, no. 4 (2017): 227-55.
* https://www.aeaweb.org/articles?id=10.1257/pol.20140383
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
	
local lifetime = ${appliance_lifetimes} // 13, 15, or 18 yrs - Footnote 10

if "${incr_appliance_lifetimes}" == "yes" {
	local lifetime = 25
}

if "${decr_appliance_lifetimes}" == "yes" {
	local lifetime = 5
} 

local marginal_valuation = ${val_given}

****************************************************
/* 3c. Policy Specific Assumptions */
****************************************************	
local avg_rebate = 84 // Table 2
local shift_factor = 5
local prop_inframarginal = 0.859
local ce_0 = 0.07 // Cost effectiveness estimate assuming 0% inframarginals (Table A.10, Online Appendix)
	
****************************************************
/* 3d. Inflation Adjusted Values */
****************************************************
*Convert rebate to current dollars
local adj_rebate = `avg_rebate' * (${cpi_`dollar_year'}/${cpi_2010})

*********************************
/* 4. Intermediate Calculations */
*********************************

/* Back out total lifetime evergy reduction from Cost-effectiveness ratios

* Authors compute the total amount of energy saved by taking the difference in 
* electricity consumption of an ES-rated appliance purchased in 2010 and an 
* appliance purchased 10 years before (in 2001). They sum this difference over 
* five years. For the remaining 10 years of the appliance lifetime, the average 
* savings are simply the difference between a ES and non ES-rated appliance 
* purchased in 2010. 

* Authors report ratio of rebate value and total lifetime reduction, but 
* only report the reduction amount for years 6-15. Need to back out 1-5 from 
* cost effectiveness = rebate amount/total lifetime reduction 
*					 = rebate amount/(reduction years 0-5 x 5 + reduction years 6+ x 10)
 */
 
local kwh_reduction_yrs6plus = `kwh_reduction' // kwh/year
local kwh_reduction_yrs0to5 = ((`adj_rebate' / `ce_0') - (`kwh_reduction_yrs6plus' * 10)) / 5

local first5_loss = (1 - `prop_inframarginal') * `kwh_reduction_yrs0to5'
local 6plus_loss = (1 - `prop_inframarginal') * `kwh_reduction_yrs6plus'

local prop_marginal = 1 - `prop_inframarginal'

rebound ${rebound}
local r = `r(r)'

*************************
/* 5. WTP Calculations */
*************************

*Consumers
local inframarginal = `prop_inframarginal' * `adj_rebate'
local marginal = `adj_rebate' * `prop_marginal' * `marginal_valuation'

*Energy Savings
local c_savings = 0

if "${value_savings}" == "yes" {
	local c_savings =  (`first5_loss' * ${kwh_price_`dollar_year'_${State}}) + ((`first5_loss' * ${kwh_price_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))) + ///
	(`6plus_loss' * ${kwh_price_`dollar_year'_${State}}) + ((`6plus_loss' * ${kwh_price_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) - ///
	((`6plus_loss' * ${kwh_price_`dollar_year'_${State}}) + ((`6plus_loss' * ${kwh_price_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))))
}

*Producers
local corporate_loss = ((`first5_loss' * ${producer_surplus_`dollar_year'_${State}}) + ((`first5_loss' * ${producer_surplus_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))) + ///
	(`6plus_loss' * ${producer_surplus_`dollar_year'_${State}}) + ((`6plus_loss' * ${producer_surplus_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) - ///
	((`6plus_loss' * ${producer_surplus_`dollar_year'_${State}}) + ((`6plus_loss' * ${producer_surplus_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))))) * `r'

if "${value_profits}" == "no" {
	local corporate_loss = 0
}

* Social Costs
dynamic_grid `first5_loss', starting_year(`dollar_year') lifetime(`shift_factor') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants_1 = `r(local_enviro_ext)'
local global_pollutants_1 = `r(global_enviro_ext)'
local carbon = `r(carbon_content)'

dynamic_grid `6plus_loss', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants_2 = `r(local_enviro_ext)'
local global_pollutants_2 = `r(global_enviro_ext)'
local carbon = `carbon' + `r(carbon_content)'

dynamic_grid `6plus_loss', starting_year(`dollar_year') lifetime(`shift_factor') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants_3 = `r(local_enviro_ext)'
local global_pollutants_3 = `r(global_enviro_ext)'
local carbon = `carbon' - `r(carbon_content)'

local local_pollutants = `local_pollutants_1' + (`local_pollutants_2' - `local_pollutants_3')
local global_pollutants = `global_pollutants_1' + (`global_pollutants_2' - `global_pollutants_3')
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
local program_cost = `adj_rebate'

local fisc_ext_t = ((`first5_loss' * ${government_revenue_`dollar_year'_${State}}) + ((`first5_loss' * ${government_revenue_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))) + ///
	(`6plus_loss' * ${government_revenue_`dollar_year'_${State}}) + ((`6plus_loss' * ${government_revenue_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) - ///
	((`6plus_loss' * ${government_revenue_`dollar_year'_${State}}) + ((`6plus_loss' * ${government_revenue_`dollar_year'_${State}})/`discount') * (1 - (1/(1+`discount')^(`shift_factor' - 1))))) * `r'

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}
local first5_loss = `kwh_reduction_yrs0to5'
local 6plus_loss = `kwh_reduction_yrs6plus'

local dishwasher_energy_savings = (((`first5_loss' * `energy_cost') + ((`first5_loss' * `energy_cost') / `discount') * (1 - (1 / (1 + `discount')^(`shift_factor' - 1)))) + ///
								   ((`6plus_loss' * `energy_cost') + ((`6plus_loss' * `energy_cost') / `discount') * (1 - (1 / (1 + `discount')^(`lifetime' - 1)))) - ///
								   ((`6plus_loss' * `energy_cost') + ((`6plus_loss' * `energy_cost') / `discount') * (1 - (1 / (1 + `discount')^(`shift_factor' - 1)))))

di in red "energy savings are `dishwasher_energy_savings'"

local dishwasher_cost = 161.11772

local resource_cost = `dishwasher_cost' - `dishwasher_energy_savings'

* CO2
dynamic_grid `first5_loss', starting_year(2020) lifetime(`shift_factor') discount_rate(`discount') ef("marginal") type("uniform") geo("US") grid_specify("yes") model("midpoint")
local carbon = `r(carbon_content)'

dynamic_grid `6plus_loss', starting_year(2020) lifetime(`lifetime') discount_rate(`discount') ef("marginal") type("uniform") geo("US") grid_specify("yes") model("midpoint")
local carbon = `carbon' + `r(carbon_content)'

dynamic_grid `6plus_loss', starting_year(2020) lifetime(`shift_factor') discount_rate(`discount') ef("marginal") type("uniform") geo("US") grid_specify("yes") model("midpoint")
local carbon = `carbon' - `r(carbon_content)'

local q_carbon_mck = `carbon'

local resource_ce = `resource_cost' / `q_carbon_mck'

local prop_marginal = 1 - `prop_inframarginal'
local gov_carbon = `prop_marginal' * `q_carbon_mck'

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

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "cost"
global `1'_name "Dish Washer Rebates - C4A"
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
di `wtp_private'
di `prop_inframarginal'
di `inframarginal'
di `marginal'

di `kwh_reduction_yrs0to5'
di `kwh_reduction_yrs6plus'
di `carbon_reduction'
di `fiscal_externality'
di `program_cost'
di `corporate_loss'
di `global_pollutants' + `local_pollutants'
