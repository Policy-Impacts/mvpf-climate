********************************************************************************
/*  0. Program: Rice Field Burning (India)                     */
********************************************************************************
/*
MONEY (NOT) TO BURN: PAYMENTS FOR ECOSYSTEM SERVICES TO REDUCE CROP RESIDUE BURNING

B. Kelsey Jack, Seema Jayachandran, Namrata Kala, Rohini Pande
Working Paper 30690
http://www.nber.org/papers/w30690

Standard Payments
*/


********************************
/* 1. Pull Global Assumptions */
********************************
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
	local money_per_acre = `money_per' // Maximum Accuracy model in Table 6
	local not_burned = `burned_prop' // Maximum Accuracy model in Table 6
	
	local cost_per_unburned = `money_per_acre' / `not_burned'
	
	local co2e_in_punjab = 15119.03 * 1000 // Gigagram of Carbon from burning in Punjab * short tons per Gigagram // The Gigagram number is from Table 2 of https://www.sciencedirect.com/science/article/pii/S0048969723055699
	
	local co2e_per_hectare = `co2e_in_punjab' / 2000000 // There are 2 million hectares of burned land in Punjab from abstract of https://www.sciencedirect.com/science/article/pii/S0048969723055699
	
	local co2e_per_acre = `co2e_per_hectare' / 2.47105 // Converting hectares to acres
	
	local dollar_rupee = 74.102 // In-Context and Current are both 2020 https://www.irs.gov/individuals/international-taxpayers/yearly-average-currency-exchange-rates
	
*************************
/* 4. WTP Calculations */
*************************
local prop_infra = 0.098 / (`not_burned'+0.098) // 9.8% from paper

local wtp_inf = (`cost_per_unburned' * `prop_infra') /`dollar_rupee'
local wtp_marg = (`cost_per_unburned' * (1 - `prop_infra') * 0.5)/`dollar_rupee'

local wtp_cons = `wtp_inf' + `wtp_marg'
	
local local_pollutants = 0 // Even though there are local benefits, we are doing this in terms of CO2e

local global_pollutants = `co2e_per_acre' * ${sc_CO2_`dollar_year'} // We don't scale by semie because everything is in terms of 1 unburned acre

local q_carbon = `co2e_per_acre'

local wtp_society = `global_pollutants' + `local_pollutants'

local WTP = `wtp_cons' + `wtp_society' - (`global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = 0
local WTP_USFut  =     ${USShareFutureSSC}  * `global_pollutants' * (1 - ${USShareGovtFutureSCC})
local WTP_RoW    = (1 - ${USShareFutureSSC}) * `global_pollutants' + `local_pollutants' + `wtp_cons'

**************************
/* 5. Cost Calculations  */
**************************
local program_cost = `cost_per_unburned' / `dollar_rupee'

local fisc_ext_t = 0

local fisc_ext_s = 0

local fisc_ext_lr = -1 * `global_pollutants' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'


**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP'/`total_cost'
	
if (`WTP' > 0 & `total_cost' < 0) {
	local MVPF = 99999 // positive infinity
}

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
global wtp_loc_`1' = `local_pollutants'
global wtp_marg_`1' = `wtp_marg'
global wtp_inf_`1' = `wtp_inf'

global wtp_cons_`1' = `wtp_cons' 

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' =  `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global cost_`1' = `total_cost'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

** for waterfall charts
global wtp_comps_`1' wtp_marg wtp_inf wtp_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Standard Payments - Rice Burning"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `"Enviro"' 4 `"Total WTP"' 6 `""Program" "Cost""' 7 `""FE" "Subsidies""' 8 `""FE" "Taxes""' 9 `""FE" "Long-Run""' 10 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 3
global color_group3_`1' = 3
global cost_color_start_`1' = 6
global color_group4_`1' = 9

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1

di `MVPF'
di `total_cost'
di `WTP'
di `wtp_cons'
di `co2e_per_acre'

di `WTP_RoW' + `WTP_USFut' + `WTP_USPres'
di (`WTP_USFut' + `WTP_USPres')/`total_cost'