*************************************************************
/* 1. Program: Tax on Crude Oil Production				    */
*************************************************************

/* 
Brown, Jason P. and Maniloff, Peter and Manning, Dale T. 2020.
"Spatially variable taxation and resource extraction: The impact of state oil taxes on drilling in the US"
Journal of Environmental Economics and Management 103.  
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
	if ${draw_number} ==1 {
		preserve
			use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
			qui ds draw_number, not 
			global estimates_${name} = r(varlist)
			
			mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
		restore
	}
	local ests ${estimates_${name}}
	foreach var in `ests' {
		matrix temp = draws_${name}["${draw_number}", "`var'"]
		local `var' = temp[1,1]
	}
}
if "`bootstrap'" != "yes" {
	preserve
		qui import excel "${code_files}/2a_causal_estimates_papers/${folder_name}/${name}.xlsx", clear sheet("wrapper_ready") firstrow		
levelsof estimate, local(estimates)


		foreach est in `estimates' {
			su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}

global crude_market_toggle 		elastic

*********************************
/* 3. Pull Necessary Estimates / Parameters */
*********************************
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "`4'" == "current"{
	local dollar_year = ${today_year}
}

*********************************
/* 4. Pull Tax Rates */
*********************************
local tax_rate_crude = ${tax_rate_paper} * (${cpi_`dollar_year'}/${cpi_${paper_dollar_year}})

preserve

	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear	
		keep if year == `dollar_year'
		
		gen per_barrel_markup = (refiner_crude_cost - crude_landed_cost)
		local tax_per_barrel = per_barrel_markup * ${gasoline_effective_corp_tax}
		
restore

*********************************
/* 5. Calculate Environmental Externality */
*********************************

	*********************************
	/* 5a. Import Social Costs and Parameters*/
	*********************************
	preserve

		local ghg CO2 CH4 N2O
		foreach g of local ghg {
			
			local social_cost_`g' = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
				
		}	
		
		** Emissions from crude oil production (global).
		import excel "${policy_assumptions}", first clear sheet("driving_parameters")
		
			qui sum estimate if parameter == "well_to_refinery_global"
				local global_intensity = r(mean)
			qui sum estimate if parameter == "well_to_refinery_US"
				local US_intensity = r(mean)

		local enviro_externality_difference = `global_intensity' - `US_intensity'
	
		
	restore 

	*********************************
	/* 5b. Calculate Pollution Externality per Barrel of Crude */
	*********************************
	preserve

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
		
		keep if year == `dollar_year'

		local upstream CO2 CH4 N2O
		
			local wtp_upstream_difference = 0
			
			foreach val of local upstream {
				
				local wtp_upstream_`val' = ///
							`val'_well_to_refinery*`social_cost_`val''
							
				local wtp_upstream_difference = `wtp_upstream_difference' + `wtp_upstream_`val''
				
			}
		
	restore
	
*********************************
/* 6. Intermediate Calculations */
*********************************
local semi_e_crude_tax = `e_supply_crude' / `tax_rate_crude'
	assert `semi_e_crude_tax' <= 0

local wtp_soc_l = 0 // No local pollutants
local wtp_soc_g = -`wtp_upstream_difference' * `semi_e_crude_tax'
	assert `wtp_soc_g' <= 0

local wtp_producers = 1

	local total_wtp = `wtp_producers' + `wtp_soc_l' + (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
local program_cost = 1
	assert `program_cost' == `wtp_producers'

local fiscal_externality_tax = `semi_e_crude_tax' * `tax_rate_crude'
	assert `fiscal_externality_tax' <= 0 
	assert round(`fiscal_externality_tax', 0.001) == round(`e_supply_crude', 0.001)
	// Elasticity of supply w.r.t. tax rate, so multiplying semi by tax gives us back the elasticity.
	
	// Account for corporate profit taxes lost.
	local fiscal_externality_tax = `fiscal_externality_tax' + (`tax_per_barrel' * `semi_e_crude_tax')

local fiscal_externality_lr = -`wtp_soc_g' * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
	assert `fiscal_externality_lr' >= 0

local total_cost = `program_cost' + `fiscal_externality_lr' + `fiscal_externality_tax'

	local MVPF = `total_wtp'/`total_cost'
		di in red `MVPF'
		
*********************************
/* 7. Output */
*********************************
global normalize_`1' = 0

global MVPF_`1' = `MVPF'


local US_CO2_tons_prod = (`US_intensity'*${MJ_conversion})/1000000
local carbon_content_barrel = 0.43 // Metric tons.

	local q_CO2_per_barrel = `US_CO2_tons_prod' + `carbon_content_barrel'

global q_CO2_`1' = -`wtp_soc_g'/`social_cost_CO2'
global q_CO2_no_`1' = -`wtp_soc_g'/`social_cost_CO2'
global q_CO2_mck_`1' = `q_CO2_per_barrel'
global q_CO2_mck_no_`1' = `q_CO2_per_barrel' 

global cost_`1' = `total_cost'
global program_cost_`1' = `program_cost'
global p_spend_`1' = `program_cost' + `fiscal_externality_tax'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global fisc_ext_s_`1' = 0
global fisc_ext_t_`1' = `fiscal_externality_tax'

global WTP_`1' = `total_wtp'
global wtp_soc_l_`1' = 0
global wtp_soc_g_`1'  = `wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_prod_`1' = `wtp_producers'

global WTP_USPres_`1' = `wtp_producers'
global WTP_USFut_`1'  = `wtp_soc_g'* (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global WTP_RoW_`1'    = (1 - ${USShareFutureSSC})*`wtp_soc_g'

assert round((${WTP_USPres_`1'} + ${WTP_USFut_`1'} + ${WTP_RoW_`1'})/`total_cost', 0.01) == round(`MVPF', 0.01)


* Waterfall Components: 
global wtp_comps_`1' wtp_prod wtp_soc_g wtp_soc_l WTP 
global wtp_comps_`1'_commas "wtp_prod", "wtp_soc_g", "wtp_soc_l", "WTP"

global cost_comps_`1' program_cost fisc_ext_t fisc_ext_s fisc_ext_lr cost 
global cost_comps_`1'_commas "program_cost", "fisc_ext_t", "fisc_ext_s", "fisc_ext_lr", "cost" 

global `1'_xlab 1 `"Transfer Cost"' 2 `"Global Damages"' 3 `"Local Damages"' 4 `"Baseline WTP"' 6 `"Tax Benefit"' 7 `""Fiscal" "Externality," "Taxes""' 8 `""Fiscal" "Externality," "Subsidies""' 9 `""Fiscal" " Externality," "Long-run" "Revenue""' 10 `""Total" "Cost""'

global color_group1_`1' = 2
global color_group2_`1' = 2
global color_group3_`1' = 3
global cost_color_start_`1' = 6
global color_group4_`1' = 9