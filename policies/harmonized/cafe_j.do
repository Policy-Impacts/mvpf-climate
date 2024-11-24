*************************************************************
/* 0. Program: CAFE                        */
*************************************************************
/*
Jacobsen, Mark R. 
"Evaluating US Fuel Economy Standards in a Model with Producer and Household Heterogeneity."
American Economic Journal: Economic Policy, 5(2): 148--87.
https://www.aeaweb.org/articles?id=10.1257/pol.5.2.148
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

*****************************
/* 2. Intermediate Calculations */
*****************************
// 2001 dollars. 
global additional_accidents 		no
global normalize_env     			yes


local change_carbon_tons = (0.008887 * 222 * ${cpi_2020})/${cpi_2001}

local consumer_surplus = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * `change_carbon_tons' * ((`change_consumer_surplus')/(`change_consumer_surplus' + `change_producer_surplus')) * -1

local producer_surplus = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * `change_carbon_tons' * (`change_producer_surplus'/(`change_consumer_surplus' + `change_producer_surplus')) * -1


local per_mile_ext = ((${gas_ldv_ext_local_2020} - ${gas_ldv_ext_local_no_vmt_2020}) / ${gas_ldv_avg_mpg_2020}) * (1/0.52)

local soc_local_p = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * ${gas_ldv_ext_local_no_vmt_2020}
local soc_local_d = (${baseline_mileage} * (`vmt_change')) * ${households_in_sample} * `per_mile_ext'



local soc_local = `soc_local_p' + `soc_local_d'
local soc_global = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * ///
			 	((${gas_ldv_ext_global_2020})*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) 


if "${normalize_env}" == "yes" {
	local normalize = `soc_local' + `soc_global'
}
if "${normalize_env}" != "yes" {
	local normalize = 1
}


local gas_tax_rev_lost = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * (${nominal_gas_tax_2020})

local corp_tax_lost = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * (${nominal_gas_markup_2020})*(${gasoline_effective_corp_tax})

local gas_profit_lost = (${baseline_gas_consumption} * (`gallons_change')) * ${households_in_sample} * (${nominal_gas_markup_2020})*(1 - ${gasoline_effective_corp_tax}) * -1

*****************************
/* 3. Saving components */
*****************************
global regulation_`1' = 1

/* Since looking at a regulation, we do not have costs --> Skip MVPF calculation and simply show the 
   breakdown b/w producers WTP to abate pollutant, p, and society's WTP for this ton of pollution. */
   
global wtp_prod_`1' = (`producer_surplus' + `gas_profit_lost')/abs(`normalize')
global wtp_cons_`1' = (`consumer_surplus')/abs(`normalize')

global wtp_soc_l_`1' = (`soc_local')/abs(`normalize')
global wtp_soc_g_`1' = `soc_global'/abs(`normalize')
global wtp_soc_`1' = ${wtp_soc_g_`1'} + ${wtp_soc_l_`1'}

global WTP_`1' = ${wtp_prod_`1'} + ${wtp_soc_`1'} + ${wtp_cons_`1'}
   
di in red ${WTP_`1'}
   
   
global normalize_`1' =  `normalize'
global soc_global_`1' =  `soc_global'
   
global program_cost_`1' = 0
global fisc_ext_t_`1' = (`gas_tax_rev_lost' + `corp_tax_lost')/abs(`normalize')
global fisc_ext_s_`1' = 0
global fisc_ext_lr_`1' = (`soc_global' * (${USShareFutureSSC} * ${USShareGovtFutureSCC}))/(abs(`normalize')) * -1
global cost_`1' = ${program_cost_`1'} + ${fisc_ext_t_`1'} + ${fisc_ext_s_`1'} + ${fisc_ext_lr_`1'}


local phi = 0
global CAFE_sc_`1' = (  ${fisc_ext_t_`1'} + ${fisc_ext_lr_`1'} - ${wtp_prod_`1'} - ${wtp_cons_`1'} + (`phi'*(${fisc_ext_t_`1'} + ${fisc_ext_lr_`1'}))) / ///
					 ((${wtp_soc_g_`1'}) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
				