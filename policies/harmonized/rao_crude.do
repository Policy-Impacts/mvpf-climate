*************************************************************
/* 1. Program: Tax on Crude Oil Production				    */
*************************************************************

/* Rao, Niruapama L.
Taxes and U.S. Oil Production: Evidence from California and the Windfall Profit Tax
American Economic Journal: Economic Policy 10(4): 268-301.
https://www.aeaweb.org/articles?id=10.1257/pol.20140483
*/

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

*********************************
/* 3. Pull Necessary Estimates / Parameters */
*********************************
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local dollar_year = ${policy_year}
	local tax_corp = ${tax_corp_paper}
	local tax_wpt_effective = ${tax_wpt}
}
if "`4'" == "current"{
	local dollar_year = ${today_year}
	local tax_corp = ${gasoline_effective_corp_tax}
	local tax_wpt_effective = 0
}

	*********************************
	/* 3a. Calculate Necessary Price Points */
	*********************************
	local paper_ATP = ${ATP}
	local paper_purchase_price = ${purchase_price}

	// Using data points from paper to backout base price. Stored in assumptions Excel sheet. 
	local base_price = (`paper_ATP'/((1-${tax_corp_paper})*${tax_wpt})) - (`paper_purchase_price'/${tax_wpt}) + `paper_purchase_price'

	local ATP_check = (1-${tax_corp_paper})*(`paper_purchase_price' - ${tax_wpt}*(`paper_purchase_price' - `base_price'))
		assert `ATP_check' == `paper_ATP'
		
	local base_price = `base_price'*(${cpi_`dollar_year'}/${cpi_${policy_year}}) // Inflation adjust if calculating 2020 MVPF.
	local ATP = ${ATP}
	local purchase_price = `paper_purchase_price'

	// Pull updated real selling price. 
	if "`4'" == "current" {
		
		preserve

			** Crude price producer sells barrel of oil to refiners for. 
			use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
				keep if year == `dollar_year'
			
			local purchase_price = refiner_crude_cost
			// Same base price, new purchase price --> new ATP (for baseline_general)

		restore		
				
	}
	
	local ATP = (1 - `tax_corp')*(`purchase_price' - `tax_wpt_effective'*(`purchase_price' - `base_price'))	// Will not change in context.	

*********************************
/* 4. Environmental Damages from Producing Crude */
*********************************

	*********************************
	/* 4a. Import Social Costs */
	*********************************
preserve

	local ghg CO2 CH4 N2O
	foreach g of local ghg {
		
		local social_cost_`g' = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
			
	}	
	
restore 

	*********************************
	/* 4b. Calculate Pollution Externality per Barrel of Crude */
	*********************************	
preserve

	** Emissions from crude oil production (global).
	import excel "${policy_assumptions}", first clear sheet("driving_parameters")
		sum estimate if parameter == "well_to_refinery_global"
			local global_intensity = r(mean)
		sum estimate if parameter == "well_to_refinery_US"
			local US_intensity = r(mean)

			
	local enviro_externality_difference = `global_intensity' - `US_intensity'


	use "${gas_refinery_data}/upstream_emissions", clear
	keep year refinery_yield_gal
	
	gen emissions_difference = (`enviro_externality_difference'*${MJ_conversion})/1000000
	// Converting from g/MJ to mt/barrel of crude oil. Leave in per-barrel terms. 
	
		gen CH4_well_to_refinery = (emissions_difference*0.34)/30
		// 34% of Masnadi et al. emissions are methane. 
		
		gen N2O_well_to_refinery = (emissions_difference*0.005)/265
		// <1% of Masnadi et al. emissions are N2O and VOC. Assuming half are N2O.
		// Don't need to do anything about VOC b/c we use the method as them to value it globally. 

		gen CO2_well_to_refinery = (emissions_difference*0.655)
		// Remainder: CO2 (and VOC)
		
	gen well_to_refinery_check = CH4_well_to_refinery*30 + N2O_well_to_refinery*265 + CO2_well_to_refinery
		assert well_to_refinery_check == emissions_difference
		drop well_to_refinery_check
		
	// Using refinery data from 1990, true in-context social costs from 1985.
	local upstream CO2 CH4 N2O
		local wtp_upstream_difference = 0
		foreach val of local upstream {
			local wtp_upstream_`val' = ///
						`val'_well_to_refinery*`social_cost_`val''
			di in red `wtp_upstream_`val''
			local wtp_upstream_difference = `wtp_upstream_difference' + `wtp_upstream_`val''
		}
				
restore
	
	
*********************************
/* 5. Calculate MVPF Components */
*********************************

// Calculate change in after-tax price.
local new_tax_wpt = `tax_wpt_effective' + 0.01 // Imagining a 1 percentage point increase in tax rate.

local post_ATP = (1-`tax_corp')*(`purchase_price' - `new_tax_wpt' * (`purchase_price' - `base_price'))
local pre_ATP = `ATP'

	local delta_ATP = (`post_ATP' - `pre_ATP')
	local pct_change_ATP = (`post_ATP' - `pre_ATP') / (`pre_ATP')
	
		local wtp_producers = `delta_ATP' * -1
	

// Calculate behavioral response to policy: (elasticity / ATP) * percent change in ATP
local behavioral_response = (`e_supply_crude' / `ATP') * `pct_change_ATP'

// Calculate society's WTP
local wtp_soc = `wtp_upstream_difference' * `behavioral_response' * -1

	local total_WTP = `wtp_producers' + (`wtp_soc'* (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
// Calculate program cost and fiscal externalities.
local tax_paid_pre = (`tax_corp'*(`purchase_price' - `tax_wpt_effective'*(`purchase_price' - `base_price'))) ///
						+ (`tax_wpt_effective'*(`purchase_price' - `base_price'))
	
local tax_paid_post = (`tax_corp'*(`purchase_price' - `new_tax_wpt'*(`purchase_price' - `base_price'))) ///
						+ (`new_tax_wpt'*(`purchase_price' - `base_price'))
						
	local delta_tax_paid = (`tax_paid_post' - `tax_paid_pre') * -1
	assert round(`delta_tax_paid', 0.001) == round(`delta_ATP', 0.001)
		
		local program_cost = `delta_tax_paid' * -1
		

local fiscal_externality_tax = (`tax_paid_pre' * `behavioral_response')
local fiscal_externality_subsidy = 0
local fiscal_externality_lr = -`wtp_soc' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

	local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_lr' + `fiscal_externality_subsidy'

	
// Calculate MVPF.
local MVPF = `total_WTP'/`total_cost'

	local WTP_USPres = `wtp_producers'
	local WTP_USFut = `wtp_soc' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
	local WTP_RoW = `wtp_soc' * (1 - (${USShareFutureSSC}))
	
		assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW') / `total_cost', 0.1) == round(`MVPF', 0.1)
		
****************************************
/* 6. Cost-Effectiveness Calculations */
****************************************
 
**************************
/* 7. Output */
**************************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'

global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global fisc_ext_s_`1' = `fiscal_externality_subsidy'
global fisc_ext_t_`1' = `fiscal_externality_tax'

global WTP_`1' = `total_WTP'
global wtp_soc_l_`1' = 0
global wtp_soc_g_`1'  = (`wtp_soc'* (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global wtp_prod_`1' = `wtp_producers'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'