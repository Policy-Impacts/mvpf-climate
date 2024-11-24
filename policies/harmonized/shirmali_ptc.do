**************************************************
/*       0. Program: PTC Wind subsidies              */
**************************************************

/*
Gireesh Shrimali, Melissa Lynes, Joe Indvik,
Wind energy deployment in the U.S.: An empirical analysis of the role of federal and state policies,
Renewable and Sustainable Energy Reviews,
Volume 43, 2015, Pages 796-806, ISSN 1364-0321,
https://doi.org/10.1016/j.rser.2014.11.080.

*/

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
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "`4'" == "current"{
	local dollar_year = ${current_year}
}
	
	****************************************************
	/* 3b. Policy Category Assumptions */
	****************************************************
	preserve
		import excel "${policy_assumptions}", first clear sheet("Wind")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local lifetime = ${lifetime}
		
		local capacity_factor = ${capacity_factor} // capacity factor for wind. 
		// Capacity factor doesn't matter b/c it affects WTP and cost identically. 
		
		local average_size = ${average_size}
		local credit_life = ${credit_life}
		local current_ptc = ${current_ptc}
		local capacity_reduction = ${capacity_reduction}
		local hrs = 8760 // hours per year
		local lcoe = 0.0373 * (${cpi_2020}/${cpi_2022}) // from https://emp.lbl.gov/levelized-cost-wind-energy, in 2022 dollars.
		local capacity_factor_context = 0.29 // https://www.energy.gov/sites/default/files/2023-08/land-based-wind-market-report-2023-edition.pdf
	restore
	
	
	// Adjust Values if Calculating In-Context MVPFs.
	if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
		
		local capacity_factor = `capacity_factor_context' // Land Based Wind Market Report - Capacity Factor in Table 34 (2007). 
		local average_size = 1.65 // in MW frrom https://pubs.usgs.gov/sir/2011/5036/sir2011-5036.pdf on Page 3.
		local current_ptc = 0.022 // PTC is 2.2 cents in 2011 (in 2011 dollars)
	}
	
	preserve
		import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
		keep if Year >= 2000 & Year <= ${policy_year} // Only have capacity additions data starting in 1999
		collapse (mean) LCOE [aw=capacity_additions]
		local avg_lcoe = (LCOE[1] * (${cpi_2020}/${cpi_2022}))/1000
		
		local ic_lcoe = (LCOE[1] * (${cpi_${policy_year}}/${cpi_2022}))/1000
	restore
	
	preserve
		import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
		
		gen ptc_real = .
		qui sum Year
		forvalues y = `r(min)'(1)`r(max)' {
			replace ptc_real = 15 * (${cpi_2020}/${cpi_1992}) if Year == `y'
		}
		replace ptc_real = 0 if Year == 2000 | Year == 2002 | Year == 2004 | Year == 2010 // expired in those years
		
		keep if Year >= 2000 & Year <= ${policy_year} // Only have capacity additions data starting in 1999
		collapse (mean) capacity_additions ptc_real [aw=capacity_additions]
		local capacity_add = capacity_additions[1]
		local ptc_real = ptc_real[1]/1000
	restore
	
	if "${lcoe_scaling}" == "yes" {
		local lcoe = ${scalar} * `lcoe'
	}
	
	if "${subsidy_loop}" == "yes" {
		local current_ptc = ${fed_sub_loop}
	}

***************************************
/* 4. Calculating Semie & Elasticity */
***************************************
local output_per_mw = (`hrs' * `capacity_factor' * 1000 * `credit_life') + (`hrs' * (`capacity_factor' * (1 - `capacity_reduction')) * 1000 * (`lifetime' - `credit_life'))
// Term 1 = Hours/Year x Capacity Factor (%) x (1000 KW / 1 MW) * 10 Years (Credit Lifetime); do the same but for remaining lifetime years but adjust by % drop in capacity factor.

*Learning by Doing Assumptions
local cum_sales = 742689 / `average_size' // 742,689 (2020), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).
local marg_sales = 92490 / `average_size' // 92,490 for (2020), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	local cum_sales = 238110 / `average_size' // 742,689 for (2020) or 238,110 (2007), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).
	local marg_sales = 40154 / `average_size' // 92,490 for (2020) or 40,154 (2007), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind). 
	local lcoe = `ic_lcoe'
}

*Getting the elasticity (New Version)
local causal_est = `semie'

*Discount the flow of LCOE and PTC to the present. 
local capital_discount = 0.0280 // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Weighted Avg Cost of Capital (%))
local ptc_discount_rate = 0.0280 // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Fixed Charge Rate (%))

*In-Context (for elasticity)
local lcoe_discounted_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
local ptc_discounted = 0.01 + ((0.01)/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))

local scale_factor_incontext = (`ptc_discounted' / 0.01) / (`lcoe_discounted_incontext'/`avg_lcoe')


*2020 (for Semie)
local lcoe_discounted = `lcoe' + ((`lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))

local ratio = `ptc_discounted'/`lcoe_discounted'

local scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_discounted'/`lcoe')

local q_change = (`semie' * 50) / ((`capacity_add') - (`semie' * 50 * 0.5)) // percent change in capacity additions as a result of the PTC // using arc elasticity method

local p_change = (`ptc_real' * `scale_factor_incontext') / (`avg_lcoe' - (`ptc_real' * `scale_factor_incontext') * 0.5) // Average credit and average lcoe in 2020 dollars // using arc elasticity method

local epsilon = - `q_change' / `p_change'

*If bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0 {
	local epsilon = - 0.00001
}

local semie = (`epsilon' / (`lcoe' * (1 - (`current_ptc' * 100 * `ratio')))) * 0.01 * `scale_factor'

if "${constant_semie}" == "yes" {
	local lcoe_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
	local ratio_incontext = `ptc_discounted'/ `lcoe_incontext'
	local ic_scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_incontext'/`avg_lcoe')
	local semie = (`epsilon' / (`avg_lcoe' * (1 - (`ptc_real' * 100 * `ratio_incontext')))) * 0.01 * `ic_scale_factor'
	local epsilon = (`semie' * (`lcoe' * (1 - (`current_ptc' * 100 * `ratio')))) / (0.01 * `ic_scale_factor')
}

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	local lcoe_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
	local ratio_incontext = `ptc_discounted'/ `lcoe_incontext'
	local ic_scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_incontext'/`avg_lcoe')
	local semie = (`epsilon' / (`avg_lcoe' * (1 - (`ptc_real' * 100 * `ratio_incontext')))) * 0.01 * `ic_scale_factor'
}


local prod_cost = (`output_per_mw'/1000) * `lcoe' * 1000 *  `average_size'
local subsidy_max = (`hrs' * `capacity_factor' * 1000 * `credit_life') * `current_ptc' * `average_size'

****************
/* 5. Outputs */
****************
wind_ado, policy_year(${policy_year}) inflation_year(${policy_year}) spec(${spec_type}) replacement(`replacement') capacity_factor_context(`capacity_factor_context') size_context(`average_size') semie(`semie') p_name("shirmali_ptc") marg_sales(`marg_sales') cum_sales(`cum_sales') prod_cost(`prod_cost') epsilon(`epsilon') farmer_theta(`farmer_theta') subsidy_max(`subsidy_max') current_ptc(`current_ptc')

global `1'_name "Shrimali PTC"
global semie_`1' = `semie'