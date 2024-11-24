*************************************************************************************
/*       0. Program: U.S. Cash-for-Clunkers program - Texas         */
*************************************************************************************

/*
Hoekstra, Mark, Steven L. Puller, and Jeremy West. 
"Cash for Corollas: When stimulus reduces spending." 
American Economic Journal: Applied Economics 9, no. 3 (2017): 1-35.
* https://www.aeaweb.org/articles?id=10.1257/app.20150172
*/

display `"All the arguments, as typed by the user, are: `0'"'

*********************************
/* 1. Estimates from Paper */
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
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "`4'" == "current"{
	local dollar_year = ${today_year}
}


*********************************
/* 3. Run .ado File. */
*********************************
local mpg_diff = (`mpg_diff' / 0.2107)
run_vehicle_retirement `dollar_year', mpg_improvement(`mpg_diff')

****************************************
/* 4. Cost-Effectiveness Calculations */
****************************************
local resource_cost = `r(resource_cost)'
local q_carbon_mck = `r(q_carbon_mck)'
local resource_ce = `resource_cost' / `q_carbon_mck'
local gov_carbon = `q_carbon_mck'

****************
/* 5. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `r(MVPF)'
global cost_`1' = `r(total_cost)'
global total_cost_`1' = `r(total_cost)'
global WTP_`1' = `r(WTP)'

global program_cost_`1' = `r(program_cost)'

global wtp_marg_`1' = `r(wtp_marg)' // Already scaled by prop. marginal. 
global wtp_inf_`1' = `r(wtp_inf)' // Already scaled by prop. marginal. 

global wtp_soc_`1' = `r(wtp_soc)'
global wtp_glob_`1' = `r(wtp_soc_global)'
global wtp_loc_`1' = `r(wtp_soc_local)'

global c_savings_`1' = `r(c_savings)'

global fisc_ext_t_`1' = `r(fisc_ext_t)'
global fisc_ext_lr_`1' =  `r(fisc_ext_lr)'

global WTP_USPres_`1' = `r(WTP_USPres)'
global WTP_USFut_`1'  = `r(WTP_USFut)'
global WTP_RoW_`1'    = `r(WTP_RoW)'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

global q_CO2_`1' = `r(q_CO2)'

global wtp_prod_`1' = `r(wtp_prod)'
	global wtp_prod_s_`1' = `r(wtp_prod)'

global wtp_soc_rbd_`1' = `r(wtp_soc_rbd)'
	global wtp_r_glob_`1' = `r(wtp_r_glob)'
	global wtp_r_loc_`1' = `r(wtp_r_loc)'

	
assert round(${wtp_glob_`1'} + ${wtp_loc_`1'} + ${wtp_r_loc_`1'} + ${wtp_r_glob_`1'}, 0.01) == round(${wtp_soc_`1'} + ${wtp_soc_rbd_`1'} , 0.01)
	
	
** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_soc_g wtp_soc_l wtp_soc_rbd wtp_prod WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_soc_g", "wtp_soc_l", "wtp_soc_rbd", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_t fisc_ext_s fisc_ext_lr cost 
global cost_comps_`1'_commas "program_cost", "fisc_ext_t", "fisc_ext_s", "fisc_ext_lr", "cost" 

global `1'_name "Cash for Clunkers (Federal)"
global `1'_ep = "N"

global `1'_xlab 1 `"Marg."' 2 `"Infr."' 3 `""Env" "Global""' 4 `""Env" "Local""' 5 `"Rebound"'  6 `""Gasoline" "Producers""'  7 `""Total" "WTP""' ///
                9 `""Program" "Cost""' 10 "Taxes" 11 "Subsidies" 12 `" "Climate" "FE" "' 13 `""Govt" "Cost""'

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 5
global color_group3_`1' = 6
global cost_color_start_`1' = 9
global color_group4_`1' = 12