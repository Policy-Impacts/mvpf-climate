*************************************************************************************
/*       0. Program: Weatherization Assistance Program				              */
*************************************************************************************

/*
Fowlie, Meredith, Michael Greenstone, and Catherine Wolfram. 
"Do energy efficiency investments deliver? Evidence from the 
weatherization assistance program." 
The Quarterly Journal of Economics 133, no. 3 (2018): 1597-1644.
* https://academic.oup.com/qje/article/133/3/1597/4828342?login=true
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

local subsidy_cost = 5150
local baseline_electricity_mmbtu = 2.13 * 12 // Table 4
local baseline_electricity_kwh = `baseline_electricity_mmbtu' * 293.07107 // Converting mmbtu to kwh

local baseline_gas_mmbtu = 6.39 * 12 // Table 4

*********************************
/* 4. Intermediate Calculations */
*********************************
*Energy Reduction
*Transform to levels
local electricity_percent = 1 - exp(`electricity_reduction') 
local gas_percent = 1 - exp(`gas_reduction') 

local kwh_reduction_annual = `electricity_percent' * `baseline_electricity_kwh'
local mmbtu_reduction_annual = `gas_percent' * `baseline_gas_mmbtu'

weatherization_ado non-marginal, policy_year(${policy_year}) inflation_year(${policy_year}) spec(${emissions_factor}) geo(${State}) kwh_reduced(`kwh_reduction_annual') mmbtu_reduced(`mmbtu_reduction_annual') ///
								 program_cost(`subsidy_cost') replacement(`replacement')
di `r(MVPF)'

****************
/* 5. Outputs */
****************
global MVPF_`1' = `r(MVPF)'
global cost_`1' = `r(total_cost)'
global WTP_`1' = `r(WTP)'

global program_cost_`1' = `r(program_cost)'
global wtp_soc_`1' = `r(wtp_society)'
global wtp_marg_`1' = `r(marginal)' 
global wtp_inf_`1' = `r(inframarginal)' 
global c_savings_`1' = `r(c_savings)'
global wtp_glob_`1' = `r(global_pollutants)'
global wtp_loc_`1' = `r(local_pollutants)'
global total_cost_`1' = `r(total_cost)'
global wtp_prod_`1' = `r(corporate_loss)'
global wtp_r_loc_`1' = `r(rebound_local)'
global wtp_r_glob_`1' = `r(rebound_global)'

global fisc_ext_t_`1' = `r(fisc_ext_t)'
global fisc_ext_s_`1' = `r(fisc_ext_s)'
global fisc_ext_lr_`1' = `r(fisc_ext_lr)'
global p_spend_`1' = `r(policy_spending)'
global q_CO2_`1' = `r(q_carbon)'

global WTP_USPres_`1' = `r(WTP_USPres)'
global WTP_USFut_`1'  = `r(WTP_USFut)'
global WTP_RoW_`1'    = `r(WTP_RoW)'

global gov_carbon_`1' = `r(gov_carbon)'
global resource_ce_`1' = `r(resource_ce)'
global q_carbon_mck_`1' = `r(q_carbon_mck)'

** for waterfall charts
global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Michigan Weatherization"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Global" "Enviro""' 4 `""Local" "Enviro""' 5 `""Rebound" "Local""' 6 `""Rebound" "Global""' 7 `"Producers"' 8 `"Total WTP"' 10 `""Program" "Cost""' 11 `""FE" "Subsidies""' 12 `""FE" "Taxes""' 13 `""FE" "Long-Run""' 14 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 6
global color_group3_`1' = 7
global cost_color_start_`1' = 10
global color_group4_`1' = 13