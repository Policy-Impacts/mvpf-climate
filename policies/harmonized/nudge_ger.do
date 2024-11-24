*************************************************************************************
/*       0. Program: Electricity Nudge - Germany         */
*************************************************************************************

/*
Social Norms and Energy Conservation Beyond the US
Mark A. Andor, Andreas Gerster, Jörg Peters, Christoph M. Schmidt

https://www.sciencedirect.com/science/article/abs/pii/S0095069620300747

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
	*Emissions numbers from: Table 1
	
	local tons_per_gram = .0000011023
	
	*Do not have reliable non-CO2 numbers for Germany grid, so I am using CO2eq instead
	local SO2_per_kwh = 0
	local NOx_per_kwh = 0
	
	local CO2_per_kwh = ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}) * 486 * `tons_per_gram'
				
	rebound ${rebound}
	local r = `r(r)'
	
	local baseline_kwh = 3304 // Using German average from table 1 instead of sample average
	local annual_kwh_change = `baseline_kwh' * `kwh_change'
	
	local nudge_number = 4 // They send out 4 nudges
	
*************************
/* 4. WTP Calculations */
*************************
local wtp_inf = 0
local wtp_marg = 0

local wtp_cons = `wtp_inf' + `wtp_marg'
	
local local_pollutants = 0 // Using CO2eq

local global_pollutants = `annual_kwh_change' * `CO2_per_kwh' * `r'

local rebound_local = `local_pollutants' * (1-`r')
local rebound_global = `global_pollutants' * (1-`r')

local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local q_carbon = ((`kwh_change' * `CO2_per_kwh')/(1/`tons_per_gram')) * `r'
	
local WTP = `wtp_cons' + `wtp_society' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = 0
local WTP_USFut  =     ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global') * (1 - ${USShareGovtFutureSCC})
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global') + `local_pollutants' + `wtp_cons' - `rebound_local'

**************************
/* 5. Cost Calculations  */
**************************
local program_cost = 1 * `nudge_number' * (${cpi_`dollar_year'}/${cpi_2009}) // Alcott estimates that the cost of mailing and printing 1 HER is approximately $1 in 2009

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
else if (`WTP' < 0 & `total_cost' > 0) {
	local MVPF = -99999 // negative infinity
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
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global wtp_marg_`1' = `wtp_marg'
global wtp_inf_`1' = `wtp_inf'

global wtp_cons_`1' = `wtp_cons' 

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' =  `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_r_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "wtp_r_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Electricity Nudge - Germany"
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