*************************************************************
/* 0. Program: CAFE                        */
*************************************************************
/*
Greenstone, Michael and Nath, Ishan
"Do Renewable Portfolio Standards Deliver Cost-Effective Carbon Abatement?"
Working Paper No. 2019-62 (November 2020). 
*/

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

local dollar_year = ${today_year}

*****************************
/* 2. Intermediate Calculations */
*****************************
// 2019 dollars. Policy year set to 2019.
global value_local_RPS 			no
global normalize_env          	yes  

local cost_per_ton = 145 * (${cpi_2020}/${cpi_2022})
	global cost_per_ton_label = `cost_per_ton'

local producer_surplus = 0
local consumer_surplus = -1 * `cost_per_ton'
   
local soc_global = ${sc_CO2_`dollar_year'} * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local soc_local = 0
	

if "${normalize_env}" == "yes" {
	local normalize = `soc_local' + `soc_global'
}
if "${normalize_env}" != "yes" {
	local normalize = 1
}

*****************************
/* 3. Waterfalls */
*****************************
global regulation_`1' = 1

/* Since looking at a regulation, we do not have costs --> Skip MVPF calculation and simply show the 
   breakdown b/w producers WTP to abate pollutant, p, and society's WTP for this ton of pollution. */
   
global wtp_prod_`1' = (`producer_surplus')/ abs(`normalize')
global wtp_cons_`1' = (`consumer_surplus')/ abs(`normalize')


global wtp_soc_l_`1' = `soc_local'/abs(`normalize')
global wtp_soc_g_`1' = `soc_global'/abs(`normalize')

	global wtp_soc_`1' = ${wtp_soc_g_`1'} + ${wtp_soc_l_`1'}

global WTP_`1' = ${wtp_prod_`1'} + ${wtp_soc_`1'} + ${wtp_cons_`1'}
      
global program_cost_`1' = 0
global fisc_ext_t_`1' = 0
global fisc_ext_s_`1' = 0
global fisc_ext_lr_`1' = ((${sc_CO2_2020})*((${USShareFutureSSC} * ${USShareGovtFutureSCC}))*-1)/abs(`normalize')

global cost_`1' = ${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_s_`1'} + ${fisc_ext_lr_`1'}
			
local phi = 0

global numerator = (${fisc_ext_lr_`1'} - ${wtp_prod_`1'} - ${wtp_cons_`1'}  + (`phi'*${fisc_ext_lr_`1'})) 
global denominator = ((${wtp_soc_g_`1'}) / (${sc_CO2_`dollar_year'} * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
global RPS_sc_`1' =  (${fisc_ext_lr_`1'} - ${wtp_cons_`1'}  + (`phi'*${fisc_ext_lr_`1'})) 

di in red ${RPS_sc_`1'}