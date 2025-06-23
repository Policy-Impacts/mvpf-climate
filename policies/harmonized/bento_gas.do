*************************************************************************************
/*       0. Program: Gas taxes									        */
*************************************************************************************

/*Bento, Antonio M., Lawrence H. Goulder, Mark R. Jacobsen, and Roger H. Von Haefen. 
"Distributional and efficiency impacts of increased US gasoline taxes." 
American Economic Review 99, no. 3 (2009): 667-99. */
* https://www.jstor.org/stable/pdf/25592478.pdf
*/

display `"All the arguments, as typed by the user, are: `0'"'
********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
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

local farmer_theta = -0.421 // Way et al. (2022)

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************
if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "${spec_type}" == "current"{
	local dollar_year = ${today_year}
}

*********************************
/* 3. Computations */
*********************************
* Run gas_tax.ado <-- Performs all necessary calculations for a gas tax.
run_gas_tax `dollar_year', elas_demand(`e_demand_gas') farmer_theta(`farmer_theta')

*********************************
/* 4. Outputs */
*********************************
global normalize_`1' = 0

global MVPF_`1' = `r(MVPF)'
global MVPF_no_cc_`1' = `r(MVPF_no_cc)'

global WTP_USPres_`1' = `r(WTP_USPres)'
global WTP_USFut_`1'  = `r(WTP_USFut)'
global WTP_RoW_`1'    = `r(WTP_RoW)'

global WTP_`1' = `r(WTP)'

global wtp_soc_`1' = `r(gas_soc)' + `r(ev_stat_gas)'
	global wtp_soc_l_`1' = `r(gas_soc_l)' + `r(ev_stat_gas_l)'
	global wtp_soc_l_po_`1' = `r(gas_soc_l_pollution)' + `r(ev_stat_gas_l)'
	global wtp_soc_l_dr_`1' = `r(gas_soc_l_driving)'
		assert round(${wtp_soc_l_po_`1'} + ${wtp_soc_l_dr_`1'}, 0.1) == round(${wtp_soc_l_`1'}, 0.1)
	global wtp_soc_g_`1' = `r(gas_soc_g)' + `r(ev_stat_gas_g)'	
	
global ev_stat_gas_`1' = `r(ev_stat_gas)'
	global ev_stat_gas_l_`1' = `r(ev_stat_gas_l)'
	global ev_stat_gas_g_`1' =  `r(ev_stat_gas_g)'	
		
global cost_wtp_`1' = `r(ev_sub_c)'
global env_cost_wtp_`1' = `r(ev_dyn_gas)'	
global env_cost_wtp_local_`1' = `r(ev_dyn_gas_l)'
global env_cost_wtp_global_`1' = `r(ev_stat_gas_g)'	
 
global wtp_cons_`1' = `r(wtp_cons)'

global wtp_prod_`1' = `r(wtp_prod)'
	global wtp_prod_s_`1' = `r(wtp_prod_s)'
	global wtp_prod_u_`1' = `r(wtp_prod_u)'	

if "${value_profits}" == "no" {

	global wtp_prod_`1' = 0 
		global wtp_prod_s_`1' = 0
		global wtp_prod_u_`1' = 0
}

assert round(${wtp_prod_`1'}, 0.001) == round(${wtp_prod_u_`1'} + ${wtp_prod_s_`1'}, 0.001)

assert round(${WTP_`1'}, 0.0001) == round(${wtp_cons_`1'} + ${wtp_prod_`1'} + ${wtp_soc_`1'} + ${env_cost_wtp_`1'} + ${cost_wtp_`1'}, 0.0001) 

global program_cost_`1' = `r(program_cost)'
global p_spend_`1' = `r(p_spend)'
global fisc_ext_t_`1' = `r(fisc_ext_t)'
global fisc_ext_s_`1' = `r(fisc_ext_s)'
global fisc_ext_lr_`1' = `r(fisc_ext_lr)'
global cost_`1' = `r(cost)'
	global total_cost_`1' = `r(cost)'

assert round(${cost_`1'}, 0.0001) == round(${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_s_`1'} + ${fisc_ext_lr_`1'}, 0.0001)
assert round(${MVPF_`1'}, 0.0001) == round(${WTP_`1'}/${cost_`1'}, 0.0001)

global q_CO2_`1' = `r(q_CO2)'
global q_CO2_no_`1' = `r(q_CO2_no)'
global q_CO2_mck_`1' = `r(q_CO2_mck)'
global q_CO2_mck_no_`1' = `r(q_CO2_mck_no)'

global gov_carbon_`1' = `r(gov_carbon)'
global resource_ce_`1' = `r(resource_ce)'
global q_carbon_mck_`1' = `r(q_carbon_mck)'
global semie_`1' = `r(semi_e_demand_gas_tax)'

global wtp_comps_`1' wtp_cons wtp_soc_g wtp_soc_l_po wtp_soc_l_dr env_cost_wtp cost_wtp  wtp_prod_s wtp_prod_u WTP 

global wtp_comps_`1'_commas "wtp_cons", "wtp_soc_g", "wtp_soc_l_po", "wtp_soc_l_dr", "env_cost_wtp", "cost_wtp", "wtp_prod_s"
global wtp_comps_`1'_commas2 "wtp_prod_u", "WTP"

global cost_comps_`1' program_cost fisc_ext_t fisc_ext_s fisc_ext_lr cost 
global cost_comps_`1'_commas "program_cost", "fisc_ext_t", "fisc_ext_s", "fisc_ext_lr", "cost" 

global `1'_xlab 1 "Transfer" 2 `""Global" "Env""' 3 `""Local" "Env""' 4 `" "Driving" "' 5 `""Dynamic" "Env""' 6 `""Dynamic" "Price""' 7 `""Gasoline" "Producers" "' 8 `"Utilities"' 9 `""Total" "WTP""' 11 `""Program" "Cost""' 12 `"Taxes"' 13 `" "Subsidies" "' 14 `" "Climate" "FE" "' 15 `""Govt" "Cost""'
			
global color_group1_`1' = 1
global color_group2_`1' = 4
global color_group3_`1' = 6
global color_group4_`1' = 8
global cost_color_start_`1' = 11
global color_group5_`1' = 14

	global `1'_ep = "N"
	global `1'_name "Gasoline Tax (Price Elasticity from Bento et al. 2009)"

if "${gas_tax_cc_toggle}" == "yes" {
		
		local cc_note_gas_taxes = "Cost curve enabled."
		
	}
	else {
		
		local cc_note_gas_taxes = "Cost curve disabled."

	}

global note_`1' = `"Publication: Bento et al. 2009" "Global Assumptions: ${scc_ind_name}, ${dr_ind_name}" "Description: Gasoline Price of $`r(consumer_price_return)' (`dollar_year' dollars). `cc_note_gas_taxes' "'
