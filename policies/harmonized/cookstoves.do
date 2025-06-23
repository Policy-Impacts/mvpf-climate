********************************************************************************
/*  0. Program: Cookstove Subsidies (for Kenyans)                     */
********************************************************************************
/*
Berkouwer, Susanna B. and Joshua T. Dean. 
"Credit, Attention, and Externalities in the Adoption of Energy Efficient Technologies by Low-Income Housholds."
American Economic Review 112(10): 3291--3330.
https://www.aeaweb.org/articles?id=10.1257/aer.20210766
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
*   if ${draw_number} ==1 {
        preserve
            use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
            qui ds draw_number, not 
            global estimates_${name} = r(varlist)
            
            mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
        restore
*   }
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
		        
        local ghg CO2 CH4 N2O
        foreach g of local ghg {
            
			local social_cost_`g'_2020 = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
			
			local social_cost_`g'_2021 = ${sc_`g'_2021} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
                
        }	
        
    restore


****************************************************
/* 4. Calculate MVPF */
****************************************************
local subsidy = ${cookstove_subsidy} * (${cpi_`dollar_year'} / ${cpi_${policy_year}})
local policy_impact = `takeup_treatment' - `takeup_control'

local wtp_infr = `takeup_control' * `subsidy'

// local wtp_marg = `policy_impact' * `subsidy' * 0.5	
local wtp_marg = `policy_impact' * ((-1 * `savings' * 52) + (-1 * `savings' * 52) / (1+`discount')) // Cookstoves save $2.28 per week for two years	
	
local wtp_soc = `policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local alt_wtp_soc = `policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (1 - (${USShareFutureSSC} * 0.255)) // 25.5% US tax to GDP ratio in 2020

local program_cost = `subsidy' * `takeup_treatment'


local fiscal_externality_lr = -`policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (${USShareFutureSSC} * ${USShareGovtFutureSCC})
local alt_fisc_ext_lr = -`policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (${USShareFutureSSC} * 0.255)
local alt_fisc_ext_lr_n = `alt_fisc_ext_lr' / `program_cost'
di in red "alternative long-run FE is `alt_fisc_ext_lr_n'"

local total_wtp = `wtp_marg' + `wtp_infr' + `wtp_soc'
local total_cost = `program_cost' + `fiscal_externality_lr'
local alt_total_cost_n = (`program_cost' + `alt_fisc_ext_lr') / `program_cost'
local alt_total_cost = `program_cost' + `alt_fisc_ext_lr'
di in red "alternative total cost is `alt_total_cost_n'"


local MVPF = `total_wtp' / `total_cost'

local WTP_USPres = 0
local WTP_USFut = `policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ///
                  ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local alt_WTP_USFut = `policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ///
                  ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) * (${USShareFutureSSC} - (${USShareFutureSSC} * 0.255))

local WTP_RoW = (1-(${USShareFutureSSC})) * `policy_impact' * ((`carbon_per_cookstove' * `social_cost_CO2_2020') + ((`carbon_per_cookstove' * `social_cost_CO2_2021') / (1 + `discount'))) + `wtp_marg' + `wtp_infr'

local alt_us_only_mvpf = `alt_WTP_USFut' / `alt_total_cost'
di in red "alternative US-only MVPF is `alt_us_only_mvpf'"


assert round((`WTP_RoW' + `WTP_USFut' + `WTP_USPres')/`total_cost', 0.01) == round(`MVPF', 0.01)	
	
if (`total_wtp' > 0 & `total_cost' < 0) {
	local MVPF = 99999 // positive infinity
}
else if (`total_wtp' < 0 & `total_cost' > 0) {
	local MVPF = -99999 // negative infinity
}

****************
/* 5. Outputs */
****************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'
global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `total_wtp'

global wtp_soc_l_`1' = 0
global wtp_soc_g_`1' = `wtp_soc'

di in red "cookstoves global damages are ${wtp_soc_g_`1'}"
pause

global wtp_marg_`1' = `wtp_marg' 
global wtp_inf_`1' = `wtp_infr' 

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = 0
global fisc_ext_s_`1' =  0
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global cost_`1' = `total_cost'

global alt_US_MVPF_`1' = `alt_us_only_mvpf'
global alt_cost_`1' = `alt_total_cost'
global alt_WTP_USFut_`1' = `alt_WTP_USFut'

****************
/* 6. Waterfall */
****************
global wtp_comps_`1' wtp_inf wtp_marg wtp_soc_g WTP
global wtp_comps_`1'_commas "wtp_inf", "wtp_marg", "wtp_soc_g", "WTP"

global cost_comps_`1' program_cost fisc_ext_lr cost 
global cost_comps_`1'_commas "program_cost", "fisc_ext_lr", "cost" 

global `1'_xlab 1 `"Inframarginal"' 2 `" "Energy" "Savings" "' 3 `""Env" "Global""' 4 `""Total" "WTP""' ///
                6 `""Program" "Cost""' 7 `" "Climate" "FE" "' 8 `""Govt" "Cost""'
				
global color_group1_`1' = 2
global color_group2_`1' = 3
global color_group3_`1' = 2
global color_group5_`1' = 2
global cost_color_start_`1' = 6
global color_group4_`1' = 7				