*************************************************************************************
/*       0. Program: Incentive Payments for Weatherization Program - Low        */
*************************************************************************************

/*
Peter Christensen, Paul Francisco, and Erica Myers
Incentive Pay and Social Returns to Worker Effort in Public Programs: Evidence from the
Weatherization Assistance Program, NBER Working Paper No. 31322. 
* https://www.nber.org/system/files/working_papers/w31322/w31322.pdf.
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

	*i. Import weatherization assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("WAP")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local marginal_valuation = ${val_given}
		local prop_marginal = ${marginal_prop}
		local retrofit_lifespan = ${retrofit_lifespan}
	restore
	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************

	local bonus_cost = 114 * (${cpi_`dollar_year'}/${cpi_2017}) // Table 10
	local contractor_surplus = 13 * (${cpi_`dollar_year'}/${cpi_2017}) // Table 10
	local retrofit_cost = 9655 * (${cpi_`dollar_year'}/${cpi_2017}) // Table 10
	local kwhs_per_mmbtu = 293.07107 // conversion rate
	
***********************************
/* 4. Intermediate Calculations */
***********************************
*Energy Reduction
local kwh_reduced_annual = (`e_saved' + `energy_saved_e') * 12 * `kwhs_per_mmbtu'
local mmbtu_reduced_annual = (`g_saved' + `energy_saved_g') * 12 // Energy saved corresponds to the impact of the bonus payment

local kwh_reduced_marginal = ((`e_saved' * `prop_marginal') +  `energy_saved_e') * 12 * `kwhs_per_mmbtu'
local mmbtu_reduction_marginal = ((`g_saved' * `prop_marginal') + `energy_saved_g') * 12

rebound ${rebound}
local r = `r(r)'
local r_ng = `r(r_ng)'

*************************
/* 5. WTP Calculations */
*************************
*Consumers
local inframarginal = (1 - `prop_marginal') * `retrofit_cost'
local marginal = `prop_marginal' * `marginal_valuation' * `retrofit_cost'
local wtp_consumers = `marginal' + `inframarginal' + `contractor_surplus'

*Producers

local prod_annual = ((`kwh_reduced_marginal' * ${producer_surplus_`dollar_year'_${State}} * `r') + (`mmbtu_reduction_marginal' * `r_ng' *	${psurplus_mmbtu_`dollar_year'_${State}}))
		
local corporate_loss = `prod_annual' + ((`prod_annual'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1))))

if "${value_profits}" == "no" {
	local corporate_loss = 0
}
	
local c_savings = 0

if "${value_savings}" == "yes" {
	local savings_annual = ((`kwh_reduced_marginal' * ${kwh_price_`dollar_year'_${State}}) + (`mmbtu_reduction_marginal' * ${ng_price_`dollar_year'_${State}}))
		
	local c_savings = `savings_annual' + (`savings_annual'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1)))
}

local contractor_wtp = `contractor_surplus'

* Social Costs
dynamic_grid `kwh_reduced_annual', starting_year(`dollar_year') lifetime(`retrofit_lifespan') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants = `prop_marginal' * `r(local_enviro_ext)'
local global_pollutants = (`r(global_enviro_ext)' + (${global_mmbtu_`dollar_year'} * `mmbtu_reduction_marginal') + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduction_marginal')/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1))))

local carbon = `r(carbon_content)' * `r' * `prop_marginal'

local q_carbon = `carbon' + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduction_marginal' * `retrofit_lifespan' * `r_ng')/${sc_CO2_`dollar_year'})

local rebound_local = `local_pollutants' * (1-`r')

local rebound_global = (((`r(global_enviro_ext)' * (1-`r')) + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduction_marginal') + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduction_marginal')/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1)))) * (1 - `r_ng'))) * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

* Social benefits from reduced carbon 
local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

* Total WTP
local WTP = `marginal' + `inframarginal' + `wtp_society' + `contractor_wtp' - `corporate_loss' + `c_savings'

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings' + `contractor_wtp'
local WTP_USFut  =  ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global')
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `bonus_cost' + `retrofit_cost'

local annual_fe_t = ((`kwh_reduced_marginal' * ${government_revenue_`dollar_year'_${State}}  * `r') + (`mmbtu_reduction_marginal' * ${govrev_mmbtu_`dollar_year'_${State}} * `r_ng'))

local fisc_ext_t = `annual_fe_t' + (`annual_fe_t'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1)))

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
local ng_cost = 3.43 * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor form EIA, from ng_citygate tab in policy_category_assumptions_MASTER

local energy_savings = ((`kwh_reduced_annual' * `energy_cost') + `mmbtu_reduced_annual' * `ng_cost') + (((`kwh_reduced_annual' * `energy_cost') + `mmbtu_reduced_annual' * `ng_cost') / `discount') * (1 - (1 / (1 + `discount')^(`retrofit_lifespan' - 1)))

local nudge_cost = `program_cost'
di in red "nudge cost is `nudge_cost'"
di in red "energy savings are `energy_savings'"

local resource_cost = `nudge_cost' - `energy_savings'
local nudge_price = `program_cost'
local kwh_reduc = `kwh_reduced_annual' * `retrofit_lifespan'
local mmtu_reduc = `mmbtu_reduced_annual' * `retrofit_lifespan'

local q_carbon_mck = `r(carbon_content)' + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced_annual' * `retrofit_lifespan') / ${sc_CO2_`dollar_year'})

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `carbon' + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced_annual' * `retrofit_lifespan' * `prop_marginal') / ${sc_CO2_`dollar_year'})

****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global wtp_marg_`1' = `marginal' 
global wtp_inf_`1' = `inframarginal' 
global wtp_ctr_`1' = `contractor_surplus'

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
global wtp_soc_`1' = `wtp_society'
global c_savings_`1' = `c_savings'
global wtp_glob_`1' = `global_pollutants'
global wtp_loc_`1' = `local_pollutants'

global wtp_prod_`1' = -`corporate_loss'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global'


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
global wtp_comps_`1' wtp_marg wtp_inf c_savings wtp_ctr wtp_prod wtp_glob wtp_loc wtp_r_loc wtp_r_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "c_savings", "wtp_ctr", "wtp_prod"
global wtp_comps_`1'_commas2 "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "WTP"


global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Illinois Weatherization + Low Bonus"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `"Savings"' 4 `"Contractors"' 5 `"Producers"' 6 `""Global" "Enviro""' 7 `""Local" "Enviro""' 8 `""Rebound" "Local""' 9 `""Rebound" "Global""' 10 `"Total WTP"' 12 `""Program" "Cost""' 13 `""FE" "Subsidies""' 14 `""FE" "Taxes""' 15 `""FE" "Long-Run""' 16 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 5
global color_group2_`1' = 7
global color_group3_`1' = 9
global cost_color_start_`1' = 12
global color_group4_`1' = 9
global color_group5_`1' = 15

global normalize_`1' = 1


di `total_cost'
di `WTP'

di `inframarginal'
di `marginal'
di `wtp_society'
di `MVPF'
di `CE'

di `carbon_only_benefit'

di `fiscal_externality'
di `program_cost'
di `corporate_loss'
di `global_pollutants' + `local_pollutants'
