*************************************************************************************
/*       0. Program: Connecticut Residential Solar Investment Program          */
*************************************************************************************

/*
Gillingham, Kenneth, and Tsvetan Tsvetanov. 
"Hurdles and steps: Estimating demand for solar photovoltaics." 
Quantitative Economics 10, no. 1 (2019): 275-310.
*https://onlinelibrary.wiley.com/doi/pdfdirect/10.3982/QE919
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
	if "${spec_type}" == "baseline"{
		local dollar_year = ${policy_year}
	}
	
	if "${spec_type}" == "current"{
		local dollar_year = ${current_year}
	}


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
		
		local system_capacity = ${system_capacity} // kW
		local annual_output = ${output} / (`system_capacity' * 1000) // kWh per year per Watt (kW * 1000)
		local lifetime = ${lifetime} 
		local marginal_val = ${marginal_val}
		local federal_subsidy = 0.26 // percent of cost subsidized
		local cost_per_watt_baseline = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022}) // expressed in 2022 dollars initially
	restore
	
	if "${subsidy_loop}" == "yes" {
		local federal_subsidy = ${fed_sub_loop}
	}

	****************************************************
	/* 3c. Policy Specific Assumptions */
	****************************************************	
	
	** Own-price elasticity of demand 
	local e_demand = `elas' // Hurdle model - sum of cols (3) and (4), Table 6 

	** Cost assumptions
	local pre_cost_per_watt = ${cost_per_watt} * (${cpi_`dollar_year'} / ${cpi_2022})
	local cost_per_watt = `pre_cost_per_watt' * (1 - `federal_subsidy')
	local avg_state_rebate = 0 // Assuming no average state rebate.
	local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
	
	if "${spec_type}" == "baseline" {
		local federal_subsidy = 0.3 // Subsidy was 30% in baseline year. https://www.irs.gov/pub/irs-prior/i5695--2014.pdf
		local system_capacity =  6.972 // kW, Average system capacity (Table 3)
		local annual_output =  32.26 / 25 // kWh/Watt, output per unit of installed capacity over 25-year lifespan (pg 302)
		
		local pre_cost_per_watt = 3.8945 * (${cpi_${policy_year}}/${cpi_2014}) // Table 4 in 2014$
		local avg_state_rebate = 3.0427 * (${cpi_${policy_year}}/${cpi_2014}) // Table 4, $/W in 2014$, doesn't include federal subsidy
		
		local avg_fed_rebate = (`pre_cost_per_watt' + `avg_state_rebate') * `federal_subsidy' // Assume federal subsidy applies to pre-state-incentive price. 
		
		local cost_per_watt = `pre_cost_per_watt' - `avg_fed_rebate'
	}
	
// 	if "${spec_type}" == "baseline_gen" {
// 		local federal_subsidy = 0.3
// 		local system_capacity = ${system_capacity}
// 		local annual_output = ${output} / (`system_capacity' * 1000)
// 		local pre_cost_per_watt = 5.40 // https://www.nrel.gov/solar/market-research-analysis/solar-installed-system-cost.html
// 		local avg_state_rebate = 0 // US-wide specification
//		
// 		local cost_per_watt = `pre_cost_per_watt' * (1-`federal_subsidy')
// 		local avg_fed_rebate = `pre_cost_per_watt' * `federal_subsidy'
// 	}
	
	local semie = `e_demand'/`cost_per_watt'

*********************************
/* 4. Intermediate Calculations */
*********************************

* learning by doing
local cum_sales = (713918 * 1000)/`system_capacity' // 71391800 MW, as of 2020; 176,113.39 MW, as of 2014
local marg_sales = (128050.40 * 1000)/`system_capacity' // 128050.40 MW, in 2020; 39,541.25 MW, in 2014

if `dollar_year' == ${policy_year} {
	local cum_sales = (176113.39 * 1000)/`system_capacity'
	local marg_sales = (39541.25 * 1000)/`system_capacity'
}

solar, policy_year(${policy_year}) spec(${spec_type}) semie(`semie') replacement(`replacement') p_name("ct_solar") marg_sales(`marg_sales') cum_sales(`cum_sales') annual_output(`annual_output') system_capacity(`system_capacity') pre_cost_per_watt(`pre_cost_per_watt') avg_state_rebate(`avg_state_rebate') e_demand(`e_demand') pass_through(${solar_passthrough}) farmer_theta(`farmer_theta') federal_subsidy(`federal_subsidy')
