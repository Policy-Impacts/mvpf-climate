*************************************************************************************
/*       1. Program: Diesel taxes						              			 */
*************************************************************************************

/* Dahl, Carol A.
"Measuring Global Gasoline and Diesel Price and Income Elasticities." 
Energy Policy 41, (2012) 2-13. */
*https://www.sciencedirect.com/science/article/pii/S0301421510008797. */
*/

display `"All the arguments, as typed by the user, are: `0'"'
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
if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "${spec_type}" == "current"{
	local dollar_year = ${today_year}
}

****************************************************
/* 4. Pull in Necessary Price and Tax Data. */
****************************************************
preserve

	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
	qui sum pct_markup if year == `dollar_year'
	local pct_markup = r(mean)

	import excel "${policy_assumptions}", first clear sheet("diesel_prices") 
		keep if year== `dollar_year'	


	local consumer_price =  diesel_price
	if "${spec_type}" == "baseline" {
		local consumer_price = ${paper_price}
	}	
		
	* Consumer price = includes taxes. 
	local tax_rate = (diesel_tax_federal + diesel_tax_state_avg)/100
	local diesel_markup = `consumer_price' * `pct_markup'

restore	

**************************
/* 5. Cost Components.  */
**************************

* Semi-elasticity of demand
local semi_e_demand_diesel_tax = `e_demand_diesel' / `consumer_price' 

* Producer (Markups)
local semi_e_producer_prices_tax = 0 // Assuming = 0.

* Program Costs
local program_cost = 1

*************************
/* 6. WTP Calculations */
*************************

* Consumers  [1 + (1+t)ep] 
local wtp_consumers = 1 + (1 +`tax_rate')*`semi_e_producer_prices_tax'

* Society  [-V/p*e]
local wtp_soc_g = ${diesel_ext_global_`dollar_year'} * `semi_e_demand_diesel_tax'
local wtp_soc_l = ${diesel_ext_local_`dollar_year'} * `semi_e_demand_diesel_tax'
				
			
* Producers
local wtp_producers = -`diesel_markup' * `semi_e_demand_diesel_tax' * (1 - ${gasoline_effective_corp_tax})
local fisc_ext_prod = `diesel_markup' * `semi_e_demand_diesel_tax' * ${gasoline_effective_corp_tax}
	
if "${value_profits}" == "no" {
	
	local wtp_producers = 0 // Includes utilities and gas companies' profits. 
	local fisc_ext_prod = 0
	
}

local total_WTP = `wtp_consumers' + (`wtp_soc_g'* (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_l' + `wtp_producers'

local WTP_USPres = `wtp_consumers' + `wtp_producers' + `wtp_soc_l' 
local WTP_USFut = `wtp_soc_g' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (1-(${USShareFutureSSC})) * `wtp_soc_g' 

**************************
/* 7. MVPF Calculations */
**************************
local fiscal_externality_tax = (`tax_rate' * `semi_e_demand_diesel_tax') + `fisc_ext_prod'
local fiscal_externality_subsidy = -0.000000000001
local fiscal_externality_lr = -`wtp_soc_g' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_lr' + `fiscal_externality_subsidy'

local MVPF = `total_WTP'/`total_cost'

****************************************
/* 6. Cost-Effectiveness Calculations */
****************************************
local q_carbon_mck = ((`wtp_soc_g') / ${sc_CO2_`dollar_year'}) / `semi_e_demand_diesel_tax'
di in red "consumer price is `consumer_price'"
di in red "diesel markup is `diesel_markup'"
di in red "tax rate is `tax_rate'"
local resource_cost = 0.92 * `consumer_price' - `diesel_markup' - `tax_rate' //economy-wide 8% markup from De Loecker et al. (2020)
di in red "resource cost is `resource_cost'"

local resource_ce = -`resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"
di in red "consumer price is `consumer_price'"
di in red "carbon is `q_carbon_mck'"

local resource_cost = -`consumer_price'
local gov_carbon = `wtp_soc_g' / ${sc_CO2_`dollar_year'}

**************************
/* 7. Output */
**************************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `total_WTP'

global program_cost_`1' = `program_cost' 
global wtp_soc_`1' = `wtp_soc_l' + (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))


global wtp_glob_`1' = (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global wtp_loc_`1' = `wtp_soc_l'

global wtp_r_loc_`1' = 0
global wtp_r_glob_`1' = 0


global fisc_ext_t_`1' = `fiscal_externality_tax'
global fisc_ext_s_`1' = `fiscal_externality_subsidy'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global p_spend_`1' = `program_cost' + `tax_rate' * `semi_e_demand_diesel_tax'
global q_CO2_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'}) * -1

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global wtp_soc_rbd_`1' = 0

global wtp_cons_`1' = `wtp_consumers'

global wtp_prod_s_`1' = `wtp_producers'
global wtp_prod_u_`1' = 0
global q_CO2_no_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'}) * -1
global q_CO2_mck_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'})/`semi_e_demand_diesel_tax'
global q_CO2_mck_no_`1' = ((`wtp_soc_g')/${sc_CO2_`dollar_year'})/`semi_e_demand_diesel_tax'
global resource_cost_`1' = `consumer_price'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'
global semie_`1' = `semi_e_demand_diesel_tax'