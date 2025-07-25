*************************************************************************************
/*       0. Program: Energy Efficient Appliance Rebate -- Clothes Washers        */
*************************************************************************************

/*
Souvik Datta and Sumeet Gulati
"Utility rebates for ENERGY STAR appliances: Are they effective?" 
Journal of Environmental Economics and Management
* https://www.sciencedirect.com/science/article/pii/S0095069614000722#s0070
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


****************************************************
/* 3a. Emissions Factors */
****************************************************
preserve
	
	if "${spec_type}" == "baseline"{
		local dollar_year = ${policy_year}
	}
	
	if "${spec_type}" == "current"{
		local dollar_year = ${current_year}
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
	
local lifetime = ${appliance_lifetimes} // 13, 15, or 18 yrs - Footnote 10

if "${incr_appliance_lifetimes}" == "yes" {
	local lifetime = 25
}

if "${decr_appliance_lifetimes}" == "yes" {
	local lifetime = 5
}
local marginal_valuation = ${val_given}
	
****************************************************
/* 4. Set local assumptions unique to this policy */
****************************************************
local appliance_cost = 966 * (${cpi_`dollar_year'} / ${cpi_2004}) // Footnote on page 1
local avg_rebate = 68.65 * (${cpi_`dollar_year'} / ${cpi_2004}) // Table 3
// local annual_kwh = ((854+829+829+615+529+531)/6) - ((290+297+297+254+243+234)/6) // kwh per year
local annual_kwh = 201 // Houde & Aldy (2017)

*Datta assumes that people replace their appliances at the end of the appliance lifetime and do not consider accelerated replacement as does Houde and Aldy

if "${spec_type}" == "baseline"{
	local annual_kwh = 531-234 // Table 5
}

*********************************
/* 5. Intermediate Calculations */
*********************************
local semie = `semie' / 100
local epsilon = `semie' * ((966 - 68.65) * (${cpi_${policy_year}} / ${cpi_2004}))
local semie = `epsilon' / (`appliance_cost' - `avg_rebate')

rebound ${rebound}
local r = `r(r)'
*************************
/* 6. WTP Calculations */
*************************
* Consumers
local wtp_cons = 1

* Producers
local annual_prod = `semie' * `annual_kwh' * ${producer_surplus_`dollar_year'_${State}}

local wtp_prod = (`annual_prod' + (`annual_prod'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `r'

local c_savings = 0

if "${value_savings}" == "yes" {
	local annual_savings = `semie' * `annual_kwh' * ${kwh_price_`dollar_year'_${State}}
	
	local c_savings = `annual_savings' + (`annual_savings'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))
}

if "${value_profits}" == "no" {
	local wtp_prod = 0
}

* Social Costs
dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")
local local_pollutants = `r(local_enviro_ext)'
local global_pollutants = `r(global_enviro_ext)'

local rebound_local = `local_pollutants' * (1 - `r') * `semie'
local rebound_global = `global_pollutants' * (1 - `r') * `semie'

local val_local_pollutants = `local_pollutants' * `semie'
local val_global_pollutants = `global_pollutants' * `semie'

local carbon = `r(carbon_content)'
local q_carbon = `carbon' * `r' * `semie'

* Society
local wtp_soc_raw = `val_local_pollutants' + `val_global_pollutants'

local wtp_society = `wtp_soc_raw' - `rebound_local' - `rebound_global'

local wtp_private = `wtp_cons' - `wtp_prod'

local WTP = `wtp_cons' + `wtp_society' - `wtp_prod' + `c_savings' - ((`val_global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
local WTP_USPres = `wtp_cons' + `val_local_pollutants' - `wtp_prod' - `rebound_local' + `c_savings'
local WTP_USFut  =     ${USShareFutureSSC}  * ((`val_global_pollutants' - `rebound_global') - ((`val_global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`val_global_pollutants' - `rebound_global')

**************************
/* 6. Cost Calculations  */
**************************
local program_cost = 1

local annual_fe_t = `semie' * `annual_kwh' * ${government_revenue_`dollar_year'_${State}}

local fisc_ext_t = (`annual_fe_t' + ((`annual_fe_t')/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))) * `r'

if "${value_profits}" == "no" {
	local fisc_ext_t = 0
}

local gov_state_spending = 0

local gov_fed_spending = `avg_rebate' * `semie'

local fisc_ext_s = `gov_state_spending' + `gov_fed_spending'

local fisc_ext_lr = -1 * (`val_global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = `WTP' / `total_cost'

****************************************
/* 8. Cost-Effectiveness Calculations */
****************************************
local energy_cost = ${energy_cost}

local annual_e_savings = `annual_kwh' * `energy_cost'
local clothes_washer_energy_savings = `annual_e_savings' + (`annual_e_savings' / `discount') * (1 - (1 / (1 + `discount')^(`lifetime' - 1)))

di in red "energy savings are `clothes_washer_energy_savings'"

local clothes_washer_cost = 448.82 //ES manufacturer's suggested retail price of $1,033 from Table 3 of Houde & Aldy (2017)and a non-ES price of $643. $448.82 from taking the difference and inflation adjusting to 2020$ (we assume the values are in 2011$)

local resource_cost = `clothes_washer_cost' - `clothes_washer_energy_savings'
di in red "resource cost is `resource_cost'"

local q_carbon_mck = `carbon'
di in red "carbon is `q_carbon_mck'"

local resource_ce = `resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"

local gov_carbon = `q_carbon_mck' * `semie'

****************
/* 9. Outputs */
****************
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'
global wtp_soc_`1' = `wtp_society'
global c_savings_`1' = `c_savings'
global wtp_glob_`1' = `val_global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `val_local_pollutants'
global total_cost_`1' = `total_cost'
global wtp_prod_`1' = -`wtp_prod'
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_cons_`1' = `wtp_cons'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global q_CO2_`1' = `q_carbon'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'
global semie_`1' = `semie'

** for waterfall charts
global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_r_loc wtp_r_glob wtp_prod WTP
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob" ,"wtp_loc", "wtp_r_loc", "wtp_r_glob", "wtp_prod", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Clothes Washer Rebates - C4A (Datta)"
global `1'_ep = "N"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Enviro""' 3 `""Local" "Enviro""' 4 `""Rebound" "Local""' 5 `""Rebound" "Global""' 6 `"Producers"' 7 `"Total WTP"' 9 `""Program" "Cost""' 10 `""FE" "Subsidies""' 11 `""FE" "Taxes""' 12 `""FE" "Long-Run""' 13 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 5
global color_group3_`1' = 6
global cost_color_start_`1' = 9
global color_group4_`1' = 12

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1


di in red "Main Estimates"
di "`4'"
di `MVPF'
di `WTP'
di `total_cost'
di `wtp_society'
di `wtp_private'

di `program_cost'
di `wtp_prod'
di `wtp_cons'
di `val_global_pollutants' + `val_local_pollutants'
di `rebound_local' + `rebound_global'
di `wtp_society'
di `epsilon'
di `annual_kwh'