********************************************************************************
/*  0. Program: India Cookstoves                   */
********************************************************************************
/*
Rema Hanna, Esther Duflo, and Michael Greenstone
"Up in Smoke: The Influence of Household Behavior
on the Long-Run Impact of Improved Cooking Stoves"
https://www.aeaweb.org/articles?id=10.1257/pol.20140008
*/


********************************
/* 1. Pull Global Assumptions */
********************************
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


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

    ****************************************************
    /* 3a. Set Dollar Year and Policy Year */
    ****************************************************

    preserve

        if "`4'" == "baseline"{
            
            local dollar_year = ${policy_year}
            
        }
        
        if "`4'" == "current"{
            
            local dollar_year = ${today_year}
            
        }
        
    restore

	****************************************************
	/* 3b. Policy Specific Assumptions */
	****************************************************
	local prop_infra = 0.0618/0.6823 // 6% of control group and 68% of treatment group got stoves (Table 3)
		
	*To get the carbon emissions per wood cookstove in this study, I take the amount of wood used in the last meal of 3.373 kg (Control group mean in Table 7) and multiply by number of meals cooked in a week with a traditional stove 12.61 (Table 1) and multiply by 52 weeks. Then I multiply the emissions factor (grams of CO2/kg of wood) of 1590 (the midpoint estimate from this paper: https://www.sciencedirect.com/science/article/abs/pii/S0961953402000727. I then divide by 1000000 to go from grams to tons of CO2. The final result is in the middle of the range (2-6 tons) estimated by the EPA: https://www.epa.gov/indoor-air-quality-iaq/household-energy-and-clean-air)
	
	local cookstove_emissions = (3.373 * 12.61 * 52 * 1590)/1000000 // tons of CO2 per cookstove
	
	local cookstove_externality = `cookstove_emissions' * ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
	
	forvalues i = 1(1)4 {
		di `wood_change_`i''
		local per_change_wood_`i' = `wood_change_`i'' / 3.373 // Converting level change to percent change
	}
	
	local subsidy = 12.50 * (${cpi_`dollar_year'}/${cpi_${policy_year}}) // Each cookstove costs gov 12.50
	
*************************
/* 4. WTP Calculations */
*************************
local wtp_infr = `subsidy' * `prop_infra'
local wtp_marg = `subsidy' * (1 - `prop_infra') * 0.5

local wtp_cons = `wtp_infr' + `wtp_marg'
	
local local_pollutants = 0

*The treatment effect is the difference between control and treatment, so it already takes into account inframarginality

local global_pollutants = (`cookstove_externality' * `per_change_wood_1') + ((`cookstove_externality' * `per_change_wood_2')/(1 + `discount')) + ((`cookstove_externality' * `per_change_wood_3')/(1 + `discount')^2) + ((`cookstove_externality' * `per_change_wood_4')/(1 + `discount')^3)

local rebound_local = 0
local rebound_global =  0

local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local q_carbon = (`cookstove_emissions' * `wood_change_1') + (`cookstove_emissions' * `wood_change_2') + (`cookstove_emissions' * `wood_change_3') + (`cookstove_emissions' * `wood_change_4')
	
local WTP = `wtp_cons' + `wtp_society' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = 0
local WTP_USFut  =     ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global') * (1 - ${USShareGovtFutureSCC})
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global') + `local_pollutants' + `wtp_cons' - `rebound_local'


**************************
/* 5. Cost Calculations  */
**************************
local program_cost = `subsidy'

local fisc_ext_t = 0

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'
**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'
	
if (`WTP' > 0 & `total_cost' < 0) {
	local MVPF = 99999 // positive infinity
}
// else if (`WTP' < 0 & `total_cost' > 0) {
// 	local MVPF = -99999 // negative infinity
// }
****************
/* 5. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `MVPF'
global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'
global cost_`1' = `total_cost'
global total_cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global wtp_marg_`1' = `wtp_marg'
global wtp_inf_`1' = `wtp_infr'

global wtp_cons_`1' = `wtp_cons' 

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' =  `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'
global US_MVPF_`1' = (`WTP_USFut' + `WTP_USPres')/`total_cost'


** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_r_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "wtp_r_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Cookstoves - India"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Env" "Global""' 4 `""Rebound" "Global""' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 4
global color_group3_`1' = 4
global cost_color_start_`1' = 7
global color_group4_`1' = 10

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1

di `MVPF'
di `total_cost'
di `WTP'
di `wtp_cons'
di `local_pollutants'
di `global_pollutants'
di `rebound_global'
di `rebound_local'
di `wtp_society'
di `WTP_RoW' + `WTP_USFut' + `WTP_USPres'
di (`WTP_USFut' + `WTP_USPres')/`total_cost'

di `per_change_wood_2'
di `cookstove_externality' * `per_change_wood_1'
di `cookstove_externality' * `per_change_wood_2'
