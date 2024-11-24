*************************************************************************************
/*       0. Program: Cash for Coolers (air conditioners) - Mexico         */
*************************************************************************************

/*
Davis, Lucas W., Alan Fuchs, and Paul Gertler. 
"Cash for coolers: evaluating a large-scale appliance replacement program in Mexico." 
American Economic Journal: Economic Policy 6.4 (2014): 207-38.
* https://www.aeaweb.org/articles?id=10.1257/pol.6.4.207
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
	local lifetime = 5 // Paper assumes that the program accelerates retirement by 5 years
	local tons_per_gram = .000001
	
	/* Do not have reliable non-CO2 numbers for Mexico grid
	local SO2_per_kwh = ${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'}/${cpi_${md_dollar_year}}) * 9.1 * `tons_per_gram'
	
	local NOx_per_kwh = ${md_NOx_`dollar_year'_unweighted} * (${cpi_`dollar_year'}/${cpi_${md_dollar_year}}) * 8.5 * `tons_per_gram'
	*/
	local SO2_per_kwh = 0
	local NOx_per_kwh = 0
	
	*431 gCO2/kWh from: https://www.climate-transparency.org/wp-content/uploads/2021/10/CT2021Mexico.pdf 
	local CO2_per_kwh = ${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}) * 431 * `tons_per_gram'
		
	local adj_subsidy = (13400000 / 98604) * (${cpi_`dollar_year'}/${cpi_2012}) // total spent on program divided by number of ac replacements
		
	rebound ${rebound}
	local r = `r(r)'
	
	local kwh_change = `kwh_winter' * 6 + `kwh_summer' * 6 // Converting monthly effect to annual
	
*************************
/* 4. WTP Calculations */
*************************
local prop_marginal = 0.5 // 50% share supported by results from: https://www.sciencedirect.com/science/article/pii/S0047272714000589

local wtp_inf = `adj_subsidy' * `prop_marginal'
local wtp_marg = `adj_subsidy' * `marginal_valuation' * `prop_marginal'

local wtp_cons = `wtp_inf' + `wtp_marg'
	
local local_pollutants = ((`kwh_change' * (`SO2_per_kwh' + `NOx_per_kwh')) + ((`kwh_change' * (`SO2_per_kwh' + `NOx_per_kwh'))/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `prop_marginal' * `r'

local global_pollutants = ((`kwh_change' * (`CO2_per_kwh')) + ((`kwh_change' * (`CO2_per_kwh'))/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `prop_marginal' * `r'

local rebound_local = `local_pollutants' * (1-`r')
local rebound_global = `global_pollutants' * (1-`r')

local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local q_carbon = ((-1 * `kwh_change' * `prop_marginal' * `CO2_per_kwh' * `lifetime')/(1/`tons_per_gram')) * `r'
	
local WTP = `wtp_cons' + `wtp_society' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = 0
local WTP_USFut  =     ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global') * (1 - ${USShareGovtFutureSCC})
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global') + `local_pollutants' + `wtp_cons' - `rebound_local'

**************************
/* 5. Cost Calculations  */
**************************
local program_cost = `adj_subsidy'

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
global US_MVPF_`1' = (`WTP_USFut' + `WTP_USPres')/`total_cost'

** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_r_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "wtp_r_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "AC Rebate - Mexico"
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