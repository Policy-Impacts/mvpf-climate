********************************************************************************
/*  0. Program:  Conservation Reserve Program (Russo)         */
********************************************************************************
/*
Additionality and Asymmetric Information in
Environmental Markets: Evidence from Conservation
Auctions

Karl M. Aspelund and Anna Russo
https://annarusso.github.io/papers/aspelund_russo_crp.pdf
*/


********************************
/* 1. Pull Global Assumptions */
********************************
local discount = ${discount_rate}

local efficient_allocation = "no" // yes or no depending on whether you want status quo auction of the effecient auction

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
	local bid_price = 83 * (${cpi_`dollar_year'}/${cpi_2020}) // from Table 1 - this seems to be in 2020 dollars since other recent sources have a similar price 
	
	local annual_avoided_CO2 = (44/23.4) // Total CO2e avoided divided by total amount of acres (both in millions). Source from reference in Russo's paper: https://www.fsa.usda.gov/Assets/USDA-FSA-Public/usdafiles/EPAS/natural-resouces-analysis/nra-landing-index/2017-files/Environmental_Benefits_of_the_US_CRP_2017_draft.pdf 
	
	*Russo uses a scc of $43. She reports the total GHG benefits + other benefits (wildlife, air quality, etc...) for four different estimates and takes the average. To backout the other estimates, I can apply a $43 scc and subtract out the GHG benefits from the total benefits.
	
	local russo_ghg = (`annual_avoided_CO2' * 43)
	
	local other_benefits = ((98.34 - `russo_ghg') + (255.70 - `russo_ghg') + (367.96 - `russo_ghg') + (456.04 - `russo_ghg'))/4

	local marginal_prop = `rd_estimate'/-0.35 // Calculated using estimate & method from Table 2
	
*************************
/* 4. WTP Calculations */
*************************
if "`efficient_allocation'" == "yes" {
	local marginal_prop = 0.55
}
local wtp_infr = (1 - `marginal_prop') * `bid_price'
local wtp_marg = `marginal_prop' * 0.5 * `bid_price' // Hard to get landowner surplus so using a Harberger approximation instead

local wtp_cons = `wtp_infr' + `wtp_marg' 
	
local local_pollutants = `other_benefits' * `marginal_prop' // These are not necessarily local pollutants but local benefits more generally

local global_pollutants = (${sc_CO2_2020} * `annual_avoided_CO2') * `marginal_prop' * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})

local rebound_local = 0
local rebound_global = 0

* Social benefits from reduced carbon
local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'

local q_carbon = `annual_avoided_CO2'
* Total WTP
local WTP = `wtp_cons' + `wtp_society' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

	// Quick decomposition
	local WTP_USPres = `wtp_cons' + `local_pollutants' - `rebound_local'
	local WTP_USFut  =     ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
	local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')
	
**************************
/* 5. Cost Calculations  */
**************************
local program_cost = `bid_price'

local fisc_ext_t = 0

local fisc_ext_s = 0

local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 6. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'
	
if (`WTP' > 0 & `total_cost' < 0) {
	local MVPF = 99999 // positive infinity
}

****************************************
/* 7. Cost-Effectiveness Calculations */
****************************************
local land_cost = `bid_price'

local resource_cost = `land_cost'

local q_carbon_mck = `annual_avoided_CO2'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `q_carbon_mck' * `marginal_prop'
****************
/* 8. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'


global wtp_cons_`1' = `wtp_cons' 

global wtp_glob_`1' = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'


global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

global wtp_marg_`1' = `wtp_marg'
global wtp_inf_`1' = `wtp_infr'




global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'
global US_MVPF_`1' = (`WTP_USFut' + `WTP_USPres')/`total_cost'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

** for waterfall charts
global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_loc WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "wtp_loc", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "CRP - Russo"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Env" "Global""' 4 `""Local" "Benefits""' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

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
