**************************************************
/*       0. Program: FIT Germany              */
**************************************************

/*
An Econometric Analysis of Support Scheme Effects on Renewable Energy Investments in Europe
Torjus Folsland Bolkesjø, Petter Thørring Eltviga, Erik Nygaarda
https://www.sciencedirect.com/science/article/pii/S1876610214017688?ref=pdf_download&fr=RR-2&rr=8954f25fdf5e8feb
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
		
***************************************
/* 4. Calculating Semie & Elasticity */
***************************************
local output_per_mw = (`hrs' * `capacity_factor' * 1000 * `credit_life') + (`hrs' * (`capacity_factor' * (1 - `capacity_reduction')) * 1000 * (`lifetime' - `credit_life'))
// Term 1 = Hours/Year x Capacity Factor (%) x (1000 KW / 1 MW) * 10 Years (Credit Lifetime); do the same but for remaining lifetime years but adjust by % drop in capacity factor.

*Learning by Doing Assumptions
local cum_sales = 742689 / `average_size' // 742,689 (2020), world numbers. Sources are cited in way_etal.xlsx in data/6_tables/tables_data
local marg_sales = 92490 / `average_size' // 92,490 for (2020), world numbers. Sources are cited in way_etal.xlsx in data/6_tables/tables_data

*Getting the elasticity
local epsilon = `e_demand'

*If bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0 {
	local epsilon = - 0.00001
}

*For Semie
local capital_discount = 0.0280 // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Weighted Avg Cost of Capital (%))
local ptc_discount_rate = 0.0280 // https://www.nrel.gov/docs/fy24osti/88335.pdf, Slide 50 (Real Fixed Charge Rate (%))

local lcoe_discounted = `lcoe' + ((`lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))

local ptc_discounted = 0.01 + ((0.01)/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))

local ratio = `ptc_discounted'/`lcoe_discounted'

local scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_discounted'/`lcoe')

local semie = (`epsilon' / (`lcoe' * (1 - (`current_ptc' * 100 * `ratio')))) * 0.01 * `scale_factor'

local prod_cost = (`output_per_mw'/1000) * `lcoe' * 1000 *  `average_size'
local subsidy_max = (`hrs' * `capacity_factor' * 1000 * `credit_life') * `current_ptc' * `average_size'

****************
/* 5. Outputs */
****************
wind_ado, policy_year(${policy_year}) inflation_year(${policy_year}) spec(${spec_type}) replacement(`replacement') capacity_factor_context(`capacity_factor_context') size_context(`average_size') semie(`semie') p_name("bolk_Germany") marg_sales(`marg_sales') cum_sales(`cum_sales') prod_cost(`prod_cost') epsilon(`epsilon') farmer_theta(`farmer_theta') subsidy_max(`subsidy_max') current_ptc(`current_ptc')

global `1'_name "Bolk (Germany)"
global semie_`1' = `semie'
