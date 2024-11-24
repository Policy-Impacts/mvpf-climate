/*
*************************************************************************************
/*       0. Program: Solar Testing          */
*************************************************************************************

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

	*i. Import Solar assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("Solar")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
			local `val' = `r(mean)'
		}
		local annual_output = ${output} / (`system_capacity' * 1000)
		local federal_subsidy = 0.26
		local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022})
	restore
	
	if "${subsidy_change}" == "yes" {
		local federal_subsidy = ${fed_subsidy}
	}

	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	** Cost assumptions
	local pre_cost_per_watt = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022})
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = 0
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	local pass_through = ${solar_passthrough}
	local e_demand = ${feed_in_elas}
	local semie = `e_demand'/`cost_per_watt'
	
*********************************
/* 4. Intermediate Calculations */
*********************************

* learning by doing
local cum_sales = (713918 * 1000)/`system_capacity' // 71391800 MW, as of 2020; 176,113.39 MW, as of 2014
local marg_sales = (128050.40 * 1000)/`system_capacity' // 128050.40 MW, in 2020; 39,541.25 MW, in 2014

if `dollar_year' == ${policy_year} {
	local cum_sales = (136572.14 * 1000)/`system_capacity'
	local marg_sales = (34926.70 * 1000)/`system_capacity'  
}

solar, policy_year(${policy_year}) spec(${spec_type}) semie(`semie') replacement(`replacement') p_name("solar_testing") marg_sales(`marg_sales') cum_sales(`cum_sales') annual_output(`annual_output') system_capacity(`system_capacity') pre_cost_per_watt(`pre_cost_per_watt') avg_state_rebate(`avg_state_rebate') e_demand(`e_demand') pass_through(`pass_through') farmer_theta(`farmer_theta') federal_subsidy(`federal_subsidy')
