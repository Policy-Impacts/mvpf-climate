*************************************************************
/* 0. Program: RGGI                         */
*************************************************************

/* Chan & Morrow (2019 Energy Economics):
Unintended consequences of cap-and-trade?
Evidence from the Regional Greenhouse Gas Initiative */
* DOI: 10.1016/j.eneco.2019.01.007

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


global leakage_approach = "percent_approach"
global share_leakage_rggi = .51136364

if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	
	local dollar_year = ${policy_year}
	if "${mvpf_approach}" == "nonmarginal" {
		global MVPF_type = "nonmarginal"
	}
	else {
		global MVPF_type = "marginal"
	}	
}
if "${spec_type}" == "current"{
	
	local dollar_year = ${today_year}
	if "${mvpf_approach}" == "nonmarginal" {
		global MVPF_type = "nonmarginal"
	}
	else {
		global MVPF_type = "marginal"
	}	
}

local discount = ${discount_rate}

****************************************************
/* 1. Pollution Calculations */
****************************************************
local energy_classes 			 natgas coal	
local pollutants_list    		 CO2 SO2 NOx
local emission_type   			 prod leaker


// Baseline Emissions Produced and leaker.
foreach p of local pollutants_list {
	
	foreach t of local emission_type {
		
		local total_baseline_q_`p'_`t' = ${coal_`p'_`t'_baseline} + ${natgas_`p'_`t'_baseline}
			
	}
	
}

// Adjust Percent Change Metrics and Calculate Percent Change b/w 2009 and 2016; Calculate Leakage Shares.
foreach p of local pollutants_list {
	
	foreach t of local emission_type {
		
		foreach e of local energy_classes {
			
			if "`p'" != "NOx" {
				
				local pct_change_`e'_`p'_`t' = exp(`log_`e'_`p'_`t'_${policy_year}')
				local `e'_`p'_`t'_new = ${`e'_`p'_`t'_baseline} * `pct_change_`e'_`p'_`t''
				di in red ``e'_`p'_`t'_new'
				
			}
			
			if "`p'" == "NOx" {
				
				local pct_change_total_`p'_`t' = exp(`log_total_`p'_`t'_${policy_year}')
				local `p'_`t'_new = `total_baseline_q_`p'_`t'' * `pct_change_total_`p'_`t''
				
			}
			
		}
		
	}
	
}

* Calculate Change in Emissions by RGGI and Leaker States. 
foreach p of local pollutants_list {
	
	foreach t of local emission_type {
		
		if "`p'" != "NOx" {
			
			local total_new_q_`p'_`t' = `coal_`p'_`t'_new' + `natgas_`p'_`t'_new'
			local delta_q_`p'_`t' = `total_new_q_`p'_`t'' - `total_baseline_q_`p'_`t''
			
		}
		
		if "`p'" == "NOx" {
			
			local total_new_q_`p'_`t' =  ``p'_`t'_new'
			local delta_q_`p'_`t' = `total_new_q_`p'_`t'' - `total_baseline_q_`p'_`t''
			
		}
		
	}
	
}

* Calculate Overall Change in Emissions and WTP by Pollutant. 
foreach p of local pollutants_list {
	
	if "${leakage_approach}" == "paper_values" {
		
		local total_delta_`p' = `delta_q_`p'_prod' + `delta_q_`p'_leaker'
		di in red `total_delta_`p''
		
	}
	
	if "${leakage_approach}" == "percent_approach" {
		
		local total_delta_`p' = `delta_q_`p'_prod' * (1 - ${share_leakage_rggi})
		di in red `total_delta_`p''
			
	}
	
}

local delta_q_SO2_dCO2 = `delta_q_SO2_prod' / `delta_q_CO2_prod'
local delta_q_NOx_dCO2 = `delta_q_NOx_prod' / `delta_q_CO2_prod'

****************************************************
/* 2. Calculate Price Changes */
****************************************************
preserve

	import excel "${policy_assumptions}", first clear sheet("RGGI_C&T_data")
	
	drop if clearing_price == "--"
	destring clearing_price, replace
	
	gen year = year(auction_date)
	gen month = month(auction_date)
	
	gen auction_quarter = .
	levelsof(month), local(month_loop)
	foreach m of local month_loop {
		
		replace auction_quarter = 1 if month == 3
		replace auction_quarter = 2 if month == 6
		replace auction_quarter = 3 if month == 9
		replace auction_quarter = 4 if month == 12

	}
		
	bysort year : egen allowances_total = total(q_sold)		
	collapse (mean) clearing_price allowances_total [aw=q_sold], by(year)
		
	* Generate Locals Needed in Calculations.
	egen q = total(allowances_total) if inrange(year, 2009, ${policy_year})
	qui sum q if q != .
	local permit_q = r(mean)
		
	gen real_clearing_price = .
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		replace real_clearing_price = clearing_price * (${cpi_`dollar_year'}/${cpi_`y'}) if year == `y' 
		// 2016 dollars in context, 2020 dollars for current.
		
	}
	
	qui sum real_clearing_price [aw = allowances_total] if inrange(year, 2009, ${policy_year}) 
	local baseline_price = r(mean)
				
	if "${spec_type}" == "baseline" {
		
		local permit_price = `baseline_price' 
		
	}
		
	if "${spec_type}" == "current" {
		
		qui sum real_clearing_price if year == `dollar_year' 
		local permit_price = r(mean)
		
	}	
	
	local semie = (`baseline_price' / `delta_q_CO2_prod') * `permit_q'
	
	// For non-marginal calculation, we need total permits and emissions reduction
	
	local total_permits_auctioned = `permit_q'  // 816.2 million permits from paper
	local total_emissions_reduction = abs(`delta_q_CO2_prod')  // 22 million short tons from paper
	
****************************************************
/* 3. Import Social Costs and Marginal Damages */
****************************************************

// GOING TO SHORT TONS TO BE CONSISTENT WITH PAPER AND PERMIT QUANTITY
gen sc_NOx = (${md_NOx_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}}))/1.10231
local social_cost_NOx_uw = sc_NOx
gen sc_SO2 = (${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}}))/1.10231
local social_cost_SO2_uw = sc_SO2



gen sc_CO2 = .
foreach y of local year_loop {
	
	replace sc_CO2 = (${sc_CO2_`y'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}))/1.10231 if year == `y'
	// Constant dollars, varying social cost of carbon.
	
}

if "${spec_type}" == "baseline" {
	
	qui sum sc_CO2 [aw = allowances_total] if inrange(year, 2009, ${policy_year}) 
	local social_cost_CO2 = r(mean)
	
}

if "${spec_type}" == "current" {
	
	qui sum sc_CO2 [aw = allowances_total] if year == `dollar_year'
	local social_cost_CO2 = r(mean)
	
}

restore

****************************************************
/* 4. Cost Calculations */
****************************************************
if "${MVPF_type}" == "marginal" {
	
	local permit_revenue = -`semie'
	local fe_permit = -`permit_price'
	
}

if "${MVPF_type}" == "nonmarginal" {
	
	// Revenue from auctioning all permits
	local permit_revenue = `total_permits_auctioned' * `permit_price'  // $2.6B
	local fe_permit = 0  // No additional fiscal externality in non-marginal case
	
}

****************************************************
/* 5. Rebound Calculations */
****************************************************

****************************************************
/* 6. WTP Calculations */
****************************************************

if "${MVPF_type}" == "marginal" {
	
	* Producers/Firms WTP (M), +
	local wtp_permits_grandfathered = 0
	local wtp_permits_auctioned = -`semie'
	local wtp_permits = `wtp_permits_grandfathered' + `wtp_permits_auctioned'

	local wtp_abatement = 0 // Envelopes out. 
	
	local wtp_producers = `wtp_permits' + `wtp_abatement'
		
	* Society WTP (M), - 
	local wtp_soc = 0	
	foreach p of local pollutants_list {
		
		if "${leakage_approach}" == "paper_values"  {
			
			if "`p'" == "CO2" {
				local wtp_`p' = -`social_cost_`p''
			}
			else {
				local wtp_`p' = -`social_cost_`p'_uw' * `delta_q_`p'_dCO2'
			}
							
		}
		
		if "${leakage_approach}" == "percent_approach"  {
			
			if "`p'" == "CO2" {
				local wtp_`p' = -`social_cost_`p'' * (1 - ${share_leakage_rggi})
			}
			else {
				local wtp_`p' = -`social_cost_`p'_uw' * `delta_q_`p'_dCO2' * (1 - ${share_leakage_rggi})
			}	
		
		}
		
	}
	
	local wtp_soc_l = `wtp_SO2' + `wtp_NOx'
	local wtp_soc_g = `wtp_CO2'	
	
	local total_WTP = `wtp_producers' + `wtp_soc_l' + `wtp_soc_g' * (1 - ${USShareFutureSSC} * ${USShareGovtFutureSCC})

}

if "${MVPF_type}" == "nonmarginal" {
	
	* Producers/Firms WTP - cost of buying permits plus abatement cost
	local wtp_permits = -`permit_revenue'

	local max_abatement_cost = `permit_price' * `total_emissions_reduction'
	local wtp_abatement = -0.5 * `max_abatement_cost'  // Assuming linear abatement curve
	
	local wtp_producers = `wtp_permits' + `wtp_abatement'
	
	* Society WTP from environmental benefits
	local wtp_CO2 = `social_cost_CO2' * `total_emissions_reduction' * (1 - ${share_leakage_rggi})
	
	// Local pollutant benefits (SO2 and NOx)
	local wtp_SO2 = `social_cost_SO2_uw' * `total_emissions_reduction' * `delta_q_SO2_dCO2' * (1 - ${share_leakage_rggi})
	local wtp_NOx = `social_cost_NOx_uw' * `total_emissions_reduction' * `delta_q_NOx_dCO2' * (1 - ${share_leakage_rggi})
	
	local wtp_soc_l = `wtp_SO2' + `wtp_NOx'
	local wtp_soc_g = `wtp_CO2'
	
	local total_WTP = `wtp_producers' + `wtp_soc_l' + `wtp_soc_g' * (1 - ${USShareFutureSSC} * ${USShareGovtFutureSCC})
	

}

local WTP_USPres = `wtp_producers' + `wtp_soc_l'
local WTP_USFut = (`wtp_soc_g') * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (`wtp_soc_g') * (1 - ${USShareFutureSSC})

****************************************************
/* 7. Calculate MVPF (and Cost Effectiveness Metrics) */
****************************************************
	
local fe_lr = `wtp_soc_g' * ${USShareFutureSSC} * ${USShareGovtFutureSCC} * -1

local total_cost = -`permit_revenue' + `fe_permit' + `fe_lr'

local MVPF = `total_WTP'/`total_cost' 

di in red `social_cost_CO2' 
di in red `wtp_CO2'
di in red `wtp_soc_l'
// di in red `total_cost'
// di in red `total_WTP'
// di in red `max_abatement_cost' // match
// di in red `permit_revenue' // match


****************************************************
/* 8. Save Results and Waterfall Components */
****************************************************

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `total_WTP'
global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global program_cost_`1' = `permit_revenue'

global wtp_soc_`1' = `wtp_soc_l' + (`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
global wtp_soc_l_`1' = `wtp_soc_l'
global wtp_soc_g_`1'  = `wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
	
global wtp_no_leak_`1' = ${wtp_soc_`1'}/(1 - ${share_leakage_rggi})	
global wtp_leak_`1' = ${wtp_soc_`1'} - (${wtp_soc_`1'}/(1 - ${share_leakage_rggi}))

global wtp_abatement_`1' = `wtp_abatement'
global wtp_permits_`1' = `wtp_permits'

global semie_`1' = `semie'

global fisc_ext_t_`1' = `fe_permit'
global fisc_ext_lr_`1' = `fe_lr'

global permit_price_`1' = `permit_price'
global macc_`1' = (`baseline_price' / `delta_q_CO2_prod')

global gov_carbon_`1' = `delta_q_CO2_prod' 