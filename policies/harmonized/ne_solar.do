*************************************************************************************
/*       0. Program: Northeast solar rebate              */
*************************************************************************************

/*
Crago, Christine Lasco, and Ilya Chernyakhovskiy. 
"Are policy incentives for solar power effective? Evidence from residential installations in the Northeast." 
Journal of Environmental Economics and Management 81 (2017): 132-151.
*https://www.sciencedirect.com/science/article/pii/S0095069616302996?casa_token=9dmKVCBFHjIAAAAA:9p28uehNsbo1E5HZwqdOZw169o_9I2j0C0EPNKRdrl5vQUmGulaD1-o2qwmaOFvrNdDvz2YibQ
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
	
	if "${subsidy_loop}" == "yes" {
		local federal_subsidy = ${fed_sub_loop}
	}
	
	*Getting weighted average of cost per watt from 2010-2012
	*Installations: https://www.seia.org/solar-industry-research-data
	*Cost per Watt: https://www.nrel.gov/solar/market-research-analysis/solar-installed-system-cost.html
	
	local cost_per_watt_context = (((8.70 * 667.40) + (7.66 * (975.20-667.40)) + (5.40 * (1472.90 - 975.20))) / (1472.90)) * (${cpi_2008} / ${cpi_2022})

	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************

	** Cost assumptions
	local pre_cost_per_watt = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022})
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = 0
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	local pass_through = ${solar_passthrough}

	
	if "${spec_type}" == "baseline" {
		local federal_subsidy = 0.3
		local system_capacity =  5 // kW, Average system capacity (pg 142)
		local annual_output =  1200/1000 // kWh/W
		
		local avg_state_rebate = 1.13 * (${cpi_${policy_year}}/${cpi_2008}) // Table 9 - assuming it is in 2008$ (in between the sample years 2005-2012) 

		local pre_cost_per_watt = (((8.70 * 667.40) + (7.66 * (975.20-667.40)) + (5.40 * (1472.90 - 975.20))) / (1472.90)) * (${cpi_${policy_year}} / ${cpi_2022}) - `avg_state_rebate'
		
		local avg_fed_rebate = (`pre_cost_per_watt' + `avg_state_rebate')  * `federal_subsidy'
		local cost_per_watt = `pre_cost_per_watt' - (`avg_fed_rebate')
		
		local pass_through = 1 - 0.156
	}
	
	local cost_in_context = `cost_per_watt_context' * (1-0.3) - (1.13)
// 	local cost_in_context = 4 * (1-0.3) - (1.13)

	
	if "${spec_type}" == "baseline_gen" {
		local federal_subsidy = 0.3
		local system_capacity = ${system_capacity}
		local annual_output =  ${output} / (`system_capacity' * 1000)
		local pre_cost_per_watt = 5.40 * (${cpi_`dollar_year'}/${cpi_2022}) // NREL 2012
		local avg_state_rebate = 0

		local cost_per_watt = `pre_cost_per_watt' * (1-`federal_subsidy')
		local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	}

	local e_demand = (`semie' * `cost_in_context') * (1/(1 - 0.156)) // scale the elasticity by 1 over the in-context pass through rate

	local semie = `e_demand' / `cost_per_watt' // In-Context the cost per watt and cost in context are the same

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

solar, policy_year(${policy_year}) spec(${spec_type}) semie(`semie') replacement(`replacement') p_name("ne_solar") marg_sales(`marg_sales') cum_sales(`cum_sales') annual_output(`annual_output') system_capacity(`system_capacity') pre_cost_per_watt(`pre_cost_per_watt') avg_state_rebate(`avg_state_rebate') e_demand(`e_demand') pass_through(`pass_through') farmer_theta(`farmer_theta') federal_subsidy(`federal_subsidy')
