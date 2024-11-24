*************************************************************
/* 0. Program: California Cap-and-Trade (Marginal Auction) */
*************************************************************

/* Hernandez-Cortes and Meng (2023 JPubE):
Do environmental markets cause environmental injustice?
Evidence from California's carbon market */
* DOI: 10.1016/j.jpubeco.2022.104786

*****************************
/* 1. Estimates from Paper */
*****************************

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


if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
	
	local dollar_year = ${policy_year}
	global MVPF_type = "marginal"
	
}
if "${spec_type}" == "current"{
	
	local dollar_year = ${today_year}
	global MVPF_type = "marginal"
	
}

local share_leaked = 0

if "${toggle_firm_assumption}" == "" {
	
	global other_firm_assumption	no_abate // Either "abate" or "no_abate"
	
}
if "${toggle_firm_assumption}" == "yes" {
	
	global other_firm_assumption	abate // Either "abate" or "no_abate"
	
}

****************************************************
/* 1. Calculate Quantity Changes */
****************************************************
local pollutants_abated_ca_ct 			CO2 SO2 NOx PM25 // Ignoring PM10 b/c no MD estimate from AP3. 
foreach p of local pollutants_abated_ca_ct {
	
	if "`p'" != "CO2" {
		
		local delta_`p'_q_dCO2 = (`delta_`p'_q'/`delta_CO2_q') 
		// Carbon is priced; SO2, NOx, and PM25 are unpriced co-benefits.

	}

}

****************************************************
/* 2. Calculate Price Changes */
****************************************************
preserve

	import excel "${policy_assumptions}", first clear sheet("CA_C&T_data")
	gen year = substr(quarter_year, -4, .)
	destring year, replace
		
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		qui sum annual_allowances_CA if year == `y'
			replace annual_allowances_CA = r(mean) if year == `y'
		
	}
		
	collapse (mean) settlement_p annual_allowances_CA [aw = allowances_sold], by(year)	
		
	* Generate Locals Needed in Calculations.
	egen q = total(annual_allowances_CA) if inrange(year, 2012, ${policy_year})
	qui sum q if q != .
		local permit_q = r(mean)
		
	gen real_clearing_price = .
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		replace real_clearing_price = settlement_p * (${cpi_`dollar_year'}/${cpi_`y'}) if year == `y' 
		
	}
		
	qui sum real_clearing_price [aw = annual_allowances_CA] if inrange(year, 2012, ${policy_year}) 
		local baseline_price = r(mean)

				
	if "${spec_type}" == "baseline" {
		
		local permit_price = `baseline_price' 
		
	}
		
	if "${spec_type}" == "current" {
		
		qui sum real_clearing_price if year == `dollar_year' 
			local permit_price = r(mean)
		
	}	
	
	
	if "${other_firm_assumption}" == "no_abate" { // Default assumption.
		local semie = (`baseline_price' / `delta_CO2_q') * `permit_q'
	}
	
	if "${other_firm_assumption}" == "abate" {
		local semie = (`baseline_price' / (`delta_CO2_q'*20)) * `permit_q' // Only have ~5% of emissions; only for robustness!
	} 


****************************************************
/* 3. Cost Calculations */
****************************************************
// GOING TO SHORT TONS TO BE CONSISTENT WITH PAPER AND PERMIT QUANTITY
gen sc_NOx = (${md_NOx_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}}))
	local social_cost_NOx_uw = sc_NOx
gen sc_SO2 = (${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}}))
	local social_cost_SO2_uw = sc_SO2
gen sc_PM25 = (${md_SO2_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}}))
	local social_cost_PM25_uw = sc_SO2	
	
gen sc_CO2 = .
foreach y of local year_loop {
	
	replace sc_CO2 = (${sc_CO2_`y'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})) if year == `y'
	// Constant dollars, varying social cost of carbon.
	
}

if "${spec_type}" == "baseline" {
	
	qui sum sc_CO2 [aw = annual_allowances_CA] if inrange(year, 2012, ${policy_year}) 
		local social_cost_CO2 = r(mean)
	
}

if "${spec_type}" == "current" {
	
	qui sum sc_CO2 [aw = annual_allowances_CA] if year == `dollar_year'
		local social_cost_CO2 = r(mean)
	
}

restore


****************************************************
/* 4. Cost Calculations */
****************************************************

if "${MVPF_type}" == "marginal" {
	
	
	local permit_revenue = -`semie'
	local fiscal_externality_permit = -`permit_price'
	
}

****************************************************
/* 5. WTP Calculations */
****************************************************

if "${MVPF_type}" == "marginal" {
	
	* Producers/Firms WTP (M), +
	local wtp_permits_auctioned = -`semie'
	local wtp_permits = `wtp_permits_auctioned'

	local wtp_abatement = 0 // Envelopes out. 
	
	local wtp_producers = `wtp_permits' + `wtp_abatement'
		
	* Society WTP (M), - 
	local wtp_soc = 0	
	foreach p of local pollutants_abated_ca_ct {
		
		if "`p'" == "CO2" {
			local wtp_`p' = -`social_cost_`p''
		}
		else {
			local wtp_`p' = -`social_cost_`p'_uw' * `delta_`p'_q_dCO2'
		}

		local wtp_soc = `wtp_soc' + `wtp_`p''
	
	}
	
	local wtp_soc_l = `wtp_PM25' + `wtp_SO2' + `wtp_NOx'
	local wtp_soc_g = `wtp_CO2'

	local total_WTP = `wtp_producers' + ///
					  ((`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_l')*(1 - `share_leaked')

}

local WTP_USPres = `wtp_producers' + (`wtp_soc_l'*(1 - `share_leaked'))
local WTP_USFut = (`wtp_soc_g') * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC})) * (1- `share_leaked')
local WTP_RoW = (`wtp_soc_g') * (1 - ${USShareFutureSSC}) * (1- `share_leaked') 

****************************************************
/* 7. Calculate MVPF (and Cost Effectiveness Metrics) */
****************************************************

local fiscal_externality_lr = (`wtp_soc_g') * (${USShareFutureSSC} * ${USShareGovtFutureSCC}) * -1
// assert `fiscal_externality_lr' >= 0 

local total_cost = `permit_revenue' + `fiscal_externality_permit' + `fiscal_externality_lr'
	
local MVPF = `total_WTP'/`total_cost' // finite MVPF

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
	
global wtp_soc_`1' = ((`wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `wtp_soc_l')*(1-`share_leaked')
global wtp_soc_l_`1' = `wtp_soc_l' * (1-`share_leaked')
global wtp_soc_g_`1'  = `wtp_soc_g' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})) * (1 -`share_leaked')
	
		
global wtp_no_leak_`1' = ${wtp_soc_`1'}/(1 - `share_leaked')
	
global wtp_leak_`1' = ${wtp_soc_`1'} - (${wtp_soc_`1'}/(1 - `share_leaked'))


global wtp_abatement_`1' = `wtp_abatement'
global wtp_permits_`1' = `wtp_permits'

global fisc_ext_t_`1' = `fiscal_externality_permit'
global fisc_ext_lr_`1' = `fiscal_externality_lr'

global permit_price_`1' = `permit_price'

if "${toggle_firm_assumption}" == "yes" {
	
	macro drop toggle_firm_assumption
	
}