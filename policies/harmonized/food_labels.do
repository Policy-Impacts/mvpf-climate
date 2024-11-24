*************************************************************************************
/*       0. Program: Nudges with Carbon Footprint Food Labels                              */
*************************************************************************************

/*
Paul M. Lohmann, Elisabeth Gsottbauer, Anya Doherty, Andreas Kontoleon
Do carbon footprint labels promote climatarian diets? Evidence from a large-scale field experiment, Journal of Environmental Economics and Management, https://www.sciencedirect.com/science/article/pii/S0095069622000596.
*/

display `"All the arguments, as typed by the user, are: `0'"'

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}

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
	preserve
		
		if "${spec_type}" == "baseline"{
			local dollar_year = ${policy_year}
		}
		
		if "${spec_type}" == "current"{
			local dollar_year = ${current_year}
		}
	restore

local sales_per_day = 1000
local grams_per_ton = 907185
local euro_dollar = 1.09
local days_per_month = 30
local cost_per_month = 80 // From Discussion/Conclusion section

local treatment_footprint_baseline = 573.23 // From Table 2
local control_footprint_baseline = 671.27 //From Table 2
local average_meal_footprint = 2000 // From Discussion/Conclusion section 

*********************************
/* 4. Intermediate Calculations */
*********************************

local average_footprint = (`treatment_footprint_baseline' + `control_footprint_baseline') / 2
local average_reduction = (`reduction' / `average_footprint') * `average_meal_footprint'
local carbon_saved = (`average_reduction' * `days_per_month' * `sales_per_day')/`grams_per_ton'

*************************
/* 5. WTP Calculations */
*************************
* consumers
local inframarginal = 0
local marginal = 0
local wtp_consumers = `marginal' + `inframarginal'

*producers
local wtp_producers = 0

* society 
local carbon_reduction = `carbon_saved'

local wtp_society = `carbon_saved' * ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020})

local q_carbon = `carbon_saved'

* Total WTP
local WTP = `wtp_consumers' + `wtp_producers' + `wtp_society' - (`wtp_society' * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

local WTP_USPres = `wtp_consumers' + `wtp_producers'
local WTP_USFut  =      ${USShareFutureSSC}  * (`wtp_society' - (`wtp_society' * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * `wtp_society'

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = `cost_per_month' * `euro_dollar'

local fisc_ext_t = 0
local fisc_ext_s = 0

local fisc_ext_lr = -1 * `wtp_society' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************

local MVPF = `WTP'/`total_cost'

****************
/* 9. Outputs */
****************

di `program_cost'
di `fiscal_externality'
di `total_cost'
di `WTP'
di `wtp_consumers'
di `wtp_producers'
di `wtp_society'
di `total_cost'
di `MVPF'
di `CE'
di `carbon_reduction'


global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'
global wtp_society_`1' = `wtp_society'
global prop_infra_`1' = .
global wtp_cons_`1' = `wtp_consumers'
global wtp_glob_`1' = `wtp_society' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = 0

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'
global total_cost_`1' = `total_cost'

** for waterfall charts

global wtp_comps_`1' wtp_cons wtp_glob wtp_loc WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Food Label Nudge"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `"Total WTP"' 6 `"Program Cost"' 7 `""FE" "Subsidies""' 8 `""FE" "Taxes""' 9 `""FE" "Long-Run""' 10 `"Total Cost"'  ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 1
global color_group3_`1' = 3
global cost_color_start_`1' = 6
global color_group4_`1' = 9




