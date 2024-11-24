**************************************************
/*       0. Program: PTC Wind subsidies              */
**************************************************

/*
Metcalf, Gilbert E. 
"Investment in energy infrastructure and the tax code." 
Tax policy and the economy 24.1 (2010): 1-34.

https://www.journals.uchicago.edu/doi/full/10.1086/649826
*/

*Policy variation is at the $0.01 per kwh

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
		local current_ptc = 0.015 * (${cpi_`dollar_year'}/${cpi_1992}) // Enacted in 1992 and inflation adjusted
			*PTC is roughly $15 per MWh in 1992 dollars and is inflation adjusted during the sample period
	}
	
	// Calculate weighted average over the sample period for the in-context LCOE
	preserve
		import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
		keep if Year >= 2000 & Year <= ${policy_year} // Only have capacity additions data starting in 1999
		gen ptc_nominal = .
		gen lcoe_nominal = LCOE
		qui sum Year
		forvalues y = `r(min)'(1)`r(max)' {
			replace ptc_nominal = 15 * (${cpi_`y'}/${cpi_1992}) if Year == `y'
			replace lcoe_nominal = LCOE * (${cpi_`y'}/${cpi_2022}) if Year == `y'
		}
		replace ptc_nominal = 0 if Year == 2000 | Year == 2002 | Year == 2004 | Year == 2010 // expired in those years
		collapse (mean) LCOE ptc_nominal lcoe_nominal [aw=capacity_additions]
		local avg_lcoe = (LCOE[1] * (${cpi_2007}/${cpi_2022}))/1000
		local avg_ptc = ptc_nominal[1]/1000
		local avg_nominal_lcoe = lcoe_nominal[1]/1000
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
local cum_sales = 742689 / `average_size' // 742,689 (2020) or 93,924 (2007), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).
local marg_sales = 92490 / `average_size' // 92,490 for (2020) or 19,967 (2007) , world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	local cum_sales = 93924 / `average_size' // 742,689 (2020) or 93,924 (2007), world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).
	local marg_sales = 19967 / `average_size' // 92,490 for (2020) or 19,967 (2007) , world numbers. Available in replication package of cited paper (lcoe_learning_data_wind).
	local lcoe = `avg_lcoe'
}

*Getting the elasticity
local epsilon = `elas'

*If bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0 {
	local epsilon = - 0.00001
}

*For Semie
local capital_discount = 0.0280  // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Weighted Avg Cost of Capital (%))
local ptc_discount_rate = 0.0280  // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Fixed Charge Rate (%))

local lcoe_discounted = `lcoe' + ((`lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
local ptc_discounted = 0.01 + ((0.01)/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))

local ratio = `ptc_discounted'/`lcoe_discounted'

local scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_discounted'/`lcoe')

local semie = (`epsilon' / (`lcoe' * (1 - (`current_ptc' * 100 * `ratio')))) * 0.01 * `scale_factor'

local prod_cost = (`output_per_mw'/1000) * `lcoe' * 1000 *  `average_size'
local subsidy_max = (`hrs' * `capacity_factor' * 1000 * `credit_life') * `current_ptc' * `average_size'

if "${constant_semie}" == "yes" {
	local lcoe_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
	local ratio_incontext = `ptc_discounted'/ `lcoe_incontext'
	local ic_scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_incontext'/`avg_lcoe')
	local semie = (`epsilon' / (`avg_lcoe' * (1 - (`avg_ptc' * 100 * `ratio_incontext')))) * 0.01 * `ic_scale_factor'
	local epsilon = (`semie' * (`lcoe' * (1 - (`current_ptc' * 100 * `ratio')))) / (0.01 * `ic_scale_factor')
}

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	local lcoe_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
	local ratio_incontext = `ptc_discounted'/ `lcoe_incontext'
	local ic_scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_incontext'/`avg_lcoe')
	local semie = (`epsilon' / (`avg_lcoe' * (1 - (`avg_ptc' * 100 * `ratio_incontext')))) * 0.01 * `ic_scale_factor'
}

****************
/* 5. Outputs */
****************
wind_ado, policy_year(${policy_year}) inflation_year(${policy_year}) spec(${spec_type}) replacement(`replacement') capacity_factor_context(`capacity_factor_context') size_context(`average_size') semie(`semie') p_name("metcalf_ptc") marg_sales(`marg_sales') cum_sales(`cum_sales') prod_cost(`prod_cost') epsilon(`epsilon') farmer_theta(`farmer_theta') subsidy_max(`subsidy_max') current_ptc(`current_ptc')

global `1'_name "Metcalf PTC"
global semie_`1' = `semie'