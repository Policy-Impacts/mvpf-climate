*************************************************************
/* 0. Program: CAFE                        */
*************************************************************
/*

*/

*****************************
/* 1. Estimates from Paper */
*****************************

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

local dollar_year = ${today_year}
global policy_year = ${today_year}
local mpg_diff = 1 // A 1 MPG tightening of CAFE standards.

local permit_price 				89.66666666666667 // 2014 dollars

// For running vehicle retirement .ado file.
global months_accelerated		0
global retirement_cf   			new_avg
global normalize_env                yes

*****************************
/* 2. Intermediate Calculations */
*****************************
preserve

	use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", clear
	drop if age > 17
		egen total_vmt_harmonized = total(fleet_avg_vmt)
			local harmonized_vmt = total_vmt_harmonized
			
restore

run_vehicle_retirement `dollar_year', mpg_improvement(`mpg_diff')

*****************************
/* 3. WTP Saves*/
*****************************
local producer_surplus = (`r(wtp_prod)') // Assuming all compliance costs passed onto consumers; gasoline profits not passed on, however. Rebound included.

local consumer_surplus = (-`permit_price' * (${cpi_2020}/${cpi_2014})) * (`harmonized_vmt'/195264)
	assert `consumer_surplus' <= 0 // Our data implies a larger total lifetime VMT. Harmonizing with estimates on producers' cost of compliance. No rebound.

local soc_local = `r(wtp_soc_local)' + `r(wtp_r_loc)' 
local soc_global = `r(wtp_soc_global)' + `r(wtp_r_glob)'

if "${normalize_env}" == "yes" {
	local normalize = `soc_local' + `soc_global'
}
if "${normalize_env}" != "yes" {
	local normalize = 1
}
	
local wtp_total = `producer_surplus' + `consumer_surplus' + `soc_local' + `soc_global'

*****************************
/* 3. Waterfalls */
*****************************
/* Since looking at a regulation, we do not have costs --> Skip MVPF calculation and simply show the 
   breakdown b/w producers WTP to abate pollutant, p, and society's WTP for this ton of pollution. */
   
global wtp_prod_`1' = (`producer_surplus')/abs(`normalize')
global wtp_cons_`1' = (`consumer_surplus')/abs(`normalize')


global wtp_soc_l_`1' = `soc_local'/abs(`normalize')
global wtp_soc_g_`1' = `soc_global'/abs(`normalize')
	global wtp_soc_`1' = ${wtp_soc_g_`1'} + ${wtp_soc_l_`1'}

global WTP_`1' = ${wtp_prod_`1'} + ${wtp_soc_`1'} + ${wtp_cons_`1'}
   
global program_cost_`1' = 0
global fisc_ext_t_`1' =  `r(fisc_ext_t)' /abs(`normalize')
global fisc_ext_s_`1' = 0
global fisc_ext_lr_`1' = `r(fisc_ext_lr)'/abs(`normalize')
global cost_`1' = ${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_s_`1'} + ${fisc_ext_lr_`1'}


local phi = 0.5


global CAFE_sc_`1' = (  ${fisc_ext_t_`1'} + ${fisc_ext_lr_`1'} - ${wtp_prod_`1'} - ${wtp_cons_`1'}  + (`phi'*(${fisc_ext_t_`1'} + ${fisc_ext_lr_`1'}))) / ///
						 ((${wtp_soc_g_`1'}) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))

di in red ${CAFE_sc_`1'}
