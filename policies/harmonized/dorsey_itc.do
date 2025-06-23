********************************************************************************
/*       0. Program: Federal ITC (DORSEY)         */
********************************************************************************

/*
https://www.jacksonfdorsey.com/_files/ugd/f863ae_3dcc9be89b99454db9a9bacd63551714.pdf
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
		local federal_subsidy = 0.26 // 2020 ITC
	restore

	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	** Cost assumptions
	local pre_cost_per_watt = ${cost_per_watt}
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = 0
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	
	
	if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
		local federal_subsidy = 0.3
		local system_capacity =  7.30 // kW, Average system capacity (Table A.11)
		local annual_output =  1.42828 // kWh/Watt, output per unit of installed capacity over 25-year lifespan (Table A.9)
			
		local pre_cost_per_watt = 2.19 + 1.76 // Table 2 Panel A 2014 H1
		local avg_state_rebate = 0
			
		local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy') // Cost per watt is post-federal subsidy
		local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	}
	
	local semie = `e_demand'/`cost_per_watt'

*********************************
/* 4. Intermediate Calculations */
*********************************

* learning by doing
local cum_sales = (713918 * 1000)/`system_capacity' // 71391800 MW, as of 2020; 176,113.39 MW, as of 2014 (IRENA, 2023)
local marg_sales = (128050.40 * 1000)/`system_capacity' // 128050.40 MW, in 2020; 39,541.25 MW, in 2014 (IRENA, 2023)

if `dollar_year' == ${policy_year} {
	local cum_sales = (101645.45 * 1000)/`system_capacity'
	local marg_sales = (29440.00 * 1000)/`system_capacity'
}

solar, policy_year(${policy_year}) spec(${spec_type}) semie(`semie') replacement(`replacement') p_name("dorsey_itc") marg_sales(`marg_sales') cum_sales(`cum_sales') annual_output(`annual_output') system_capacity(`system_capacity') pre_cost_per_watt(`pre_cost_per_watt') avg_state_rebate(`avg_state_rebate') e_demand(`e_demand') pass_through(${solar_passthrough}) farmer_theta(`farmer_theta') federal_subsidy(`federal_subsidy')