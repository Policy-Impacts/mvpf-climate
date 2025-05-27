*************************************************************************************
/*       0. Program: California Solar Initiative (CSI) solar subsidies              */
*************************************************************************************

/*
Hughes, Jonathan E., and Molly Podolefsky. 
"Getting green with solar subsidies: evidence from the California solar initiative." 
Journal of the Association of Environmental and Resource Economists 2, no. 2 (2015): 235-275.
*https://www.journals.uchicago.edu/doi/full/10.1086/681131?casa_token=tMBjHRJhuP8AAAAA%3AGqm_xAxaHPR8iF_BuMJZX_pMjWnYGqw1VkZEUAaLwj9DLP8kJGCA5pOULqJcTIdvIPeMFCRgKZhFbg
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
		
		local system_capacity = ${system_capacity} // KW
		local annual_output = ${output} / (`system_capacity' * 1000) // KWh per Year per Watt (KW * 1000)
		local lifetime = ${lifetime}
		local marginal_val = ${marginal_val}
		local federal_subsidy = 0.26 // Percent of Cost Subsidized
		local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022}) // Expressed in 2022 dollars initially.
	restore
	
	if "${subsidy_loop}" == "yes" {
		local federal_subsidy = ${fed_sub_loop}
	}

	if "${lifetime_change}" == "yes" {
		local lifetime = `lifetime' * ${lifetime_scalar}
	}
	
	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	** Cost assumptions
	local pre_cost_per_watt = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022})
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = 0 // Assuming no average state rebate.
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	
	local system_capacity_paper = (5.68*1192 + 5.19*1804)/(1192+1804) // kW, weighted average installations across three utilities (Table 3)
	
	local state_rebate_paper = ((1.21*1192 + 1.72*1804)/(1192+1804)) * (${cpi_${policy_year}}/${cpi_2009}) // weighted average state rebate Table 3
	
	local cost_per_watt_paper = (((42990*1192 + 39224*1804)/(1192+1804))/(`system_capacity_paper'*1000) * (${cpi_${policy_year}}/${cpi_2009})) // $/W, weighted average total system cost (Table 3) & Assuming dollar year is from middle of sample (2009)
	
	if "${spec_type}" == "baseline" {
		local federal_subsidy = 0.3
		local system_capacity = `system_capacity_paper'
		
		local annual_output = 7477 / (`system_capacity' * 1000) // Inputting California values & baseline size from https://pvwatts.nrel.gov/pvwatts.php
		
		local avg_state_rebate = `state_rebate_paper'
		local pre_cost_per_watt = `cost_per_watt_paper'
		
		local avg_fed_rebate = (`avg_state_rebate' + `pre_cost_per_watt') * `federal_subsidy'
		
		local cost_per_watt = `pre_cost_per_watt' - `avg_fed_rebate' - `avg_state_rebate'
	}
	
// 	local cost_in_context = `cost_per_watt_paper' - `state_rebate_paper' - ((`cost_per_watt_paper' + `state_rebate_paper') * 0.3)

	local cost_in_context = `cost_per_watt_paper' - `state_rebate_paper' - ((`cost_per_watt_paper') * 0.3)
	
	if "${spec_type}" == "baseline_gen" {
		local federal_subsidy = 0.3
		local pre_cost_per_watt = 5.40 * (${cpi_`dollar_year'}/${cpi_2022}) // NREL 2012
		
		local cost_per_watt = `pre_cost_per_watt' * (1-`federal_subsidy')
		local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	}
	
	*Calculating the Elasticity
// 	local semie_paper = -1 * (`daily_install_rate_increase' / 100) * 10 // Converting from 10 cent change to $1 change
	
	local semie_paper = -1 * (exp(`semie_est' * 0.1) - 1) * 10
	
	local e_demand = (`semie_paper' * `cost_in_context') * (1/0.778)

	local semie = `e_demand'/`cost_per_watt'
	local pass_through = ${solar_passthrough}
	
	if "${spec_type}" == "baseline" {
		local semie = `semie_paper'
		local pass_through = 0.778
	}

*********************************
/* 4. Intermediate Calculations */
*********************************
* learning by doing
local cum_sales = (713918 * 1000)/`system_capacity' // 71391800 MW, as of 2020; 176,113.39 MW, as of 2014
local marg_sales = (128050.40 * 1000)/`system_capacity' // 128050.40 MW, in 2020; 39,541.25 MW, in 2014

if `dollar_year' == ${policy_year} {
	local cum_sales = (101645.45 * 1000)/`system_capacity'
	local marg_sales = (29440.00 * 1000)/`system_capacity'  
}

solar, policy_year(${policy_year}) spec(${spec_type}) semie(`semie') replacement(`replacement') p_name("hughes_csi") marg_sales(`marg_sales') cum_sales(`cum_sales') annual_output(`annual_output') system_capacity(`system_capacity') pre_cost_per_watt(`pre_cost_per_watt') avg_state_rebate(`avg_state_rebate') e_demand(`e_demand') pass_through(`pass_through') farmer_theta(`farmer_theta') federal_subsidy(`federal_subsidy')
 