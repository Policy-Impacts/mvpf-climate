*************************************************************************************
/*       0. Program: Hybrid Electric Vehicle Rebate - USA        */
*************************************************************************************

/*
Gallagher, Kelly Sims, and Erich Muehlegger. 
"Giving green to get green? Incentives and consumer adoption of hybrid vehicle technology." 
Journal of Environmental Economics and Management 61.1 (2011): 1-15.
* https://www.sciencedirect.com/science/article/abs/pii/S0095069610000768
*/

display `"All the arguments, as typed by the user, are: `0'"'
********************************
/* 0.5. Robustness Check Toggles */
********************************
local marg_mvpf = 1
local non_marg_mvpf = 0

local s_0 = 0
local s_1 = 1
local s_bar = 0

local new_cost_curve = 1
local old_cost_curve = 0

local hev_cf = "${hev_cf}"
if "`hev_cf'" == "muehl" | "`hev_cf'" == "new_car" {
	local veh_lifespan_type = "car"
}


********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}

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

local farmer_theta = -0.421

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	global dollar_year = ${policy_year}
}
if "`4'" == "current"{
	global dollar_year = ${current_year}
}

global run_year = ${run_year}
local dollar_year = ${dollar_year}

****************************************************
/* 3a. Hybrid and Counterfactual Vehicle Fuel Economy Data */
****************************************************
preserve
	use "${assumptions}/evs/processed/hev_data", clear
	** cleanest counterfactual 
	if "`4'" == "baseline"{
		keep if year >= 2000 & year <= 2006
		forvalues y = 2000(1)2006{
			qui sum mpg_N if year == `y'
			local mpg_N_`y' = r(mean)
			qui sum mpg if year == `y'
			local mpg_`y' = r(mean)
			qui sum mpg_cf if year == `y'
			local mpg_cf_`y' = r(mean)
		}
		local hev_cf_mpg = (`mpg_N_2000' * `mpg_cf_2000' + `mpg_N_2001' * `mpg_cf_2001' + `mpg_N_2002' * `mpg_cf_2002' + `mpg_N_2003' * `mpg_cf_2003' + `mpg_N_2004' * `mpg_cf_2004' + `mpg_N_2005' * `mpg_cf_2005' + `mpg_N_2006' * `mpg_cf_2006') ///
							/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006')
		local hev_mpg = (`mpg_N_2000' * `mpg_2000' + `mpg_N_2001' * `mpg_2001' + `mpg_N_2002' * `mpg_2002' + `mpg_N_2003' * `mpg_2003' + `mpg_N_2004' * `mpg_2004' + `mpg_N_2005' * `mpg_2005' + `mpg_N_2006' * `mpg_2006') ///
							/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006')
	}
	else{
		keep if year == ${run_year}
		qui sum mpg_cf
		local hev_cf_mpg = r(mean)
		qui sum mpg
		local hev_mpg = r(mean)
	}
restore

preserve
	qui import excel "${policy_assumptions}", first clear sheet("fuel_economy_1975_2022")
	forvalues y = 2000(1)2006{
		qui sum RealWorldMPG if RegulatoryClass == "All" & ModelYear == "`y'"
		local base_mpg`y' = r(mean)
	}
	qui sum RealWorldMPG if RegulatoryClass == "All" & ModelYear == "2020"
	local base_mpg2020 = r(mean)
restore
****************************************************
/* 3b. Gas Price and Tax Data */
****************************************************


preserve
	use "${gas_fleet_emissions}/fleet_year_final", clear
	keep if fleet_year==${run_year}
	
	qui ds *_gal
	foreach var in `r(varlist)' {
		replace `var' = `var'/1000000
		* Converting from grams per gallon to metric tons per gallon.
		qui sum `var'
		local `var' = r(mean)
	}
restore

preserve
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
			
	gen real_gas_price = gas_price*(${cpi_${dollar_year}} / index) 
	gen real_tax_rate = avg_tax_rate*(${cpi_${dollar_year}} / index)
	gen real_markup = markup * (${cpi_${dollar_year}} / index)
			
	keep if year==${run_year}
		
	local consumer_price = real_gas_price 
	* Consumer price = includes taxes. 
	local tax_rate = real_tax_rate
	local markup = real_markup
	
	if "${spec_type}" == "baseline" {
		qui import excel "${assumptions}/evs/processed/state_level_gas_tax_rates", first clear
		keep tax2000 tax2001 tax2002 tax2003 tax2004 tax2005 tax2006 state
		replace tax2000 = tax2000 * (${cpi_${dollar_year}} / ${cpi_2000}) 
		replace tax2001 = tax2001 * (${cpi_${dollar_year}} / ${cpi_2001})
		replace tax2002 = tax2002 * (${cpi_${dollar_year}} / ${cpi_2002})
		replace tax2003 = tax2003 * (${cpi_${dollar_year}} / ${cpi_2003})
		replace tax2004 = tax2004 * (${cpi_${dollar_year}} / ${cpi_2004})
		replace tax2005 = tax2005 * (${cpi_${dollar_year}} / ${cpi_2005})
		replace tax2006 = tax2006 * (${cpi_${dollar_year}} / ${cpi_2006})
		keep if state == "Connecticut" | state == "Dist. of Col." | state == "Maine" | state == "New Mexico"
		replace state = "District of Columbia" if state == "Dist. of Col."
		merge m:1 state using "${assumptions}/evs/processed/pop_by_state_2000_2019", keep(match)
		drop pop2007 pop2008 pop2009 pop2010 pop2011 pop2012 pop2013 pop2014 pop2015 pop2016 pop2017 pop2018 pop2019
		drop _merge
		gen N = pop2000 + pop2001 + pop2002 + pop2003 + pop2004 + pop2005 + pop2006
		gen weighted_avg = pop2000 * tax2000 + pop2001 * tax2001 + pop2002 * tax2002 + pop2003 * tax2003 + pop2004 * tax2004 + pop2005 * tax2005 + pop2005 * tax2006
		replace weighted_avg = weighted_avg / N

		egen N_states = total(N)
		egen weighted_avg_states = total(N * weighted_avg)
		replace weighted_avg_states = weighted_avg_states / N_states
		sum weighted_avg_states
		local tax_rate = r(mean) / 100

		use "${gas_price_data}/gas_data_monthly", clear
		keep if inrange(year, 2000, 2006) // pg. 4
		* Gallagher and Muehlegger 2011 look at HEV tax incentives for Q1 2000 through Q4 2006.

		gen real_gas_price = gas_price * (${cpi_${dollar_year}} / index) // no state-level gas price data so just gonna keep using national numbers
		gen real_markup = markup * (${cpi_${dollar_year}} / index)

		collapse (mean) real*  [aw=gas_consumption]
		assert _n == 1
		local consumer_price = real_gas_price 
		* Consumer price = includes taxes.
		local markup = real_markup
	}	
restore

****************************************************
/* 3c. Hybrid Specific Assumptions */
****************************************************
preserve
	qui import excel "${policy_assumptions}", first clear sheet("evs") // same as BEVs
		
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}
	
if "${hybrid_lifetime_incr}" == "yes" {
	
		global vehicle_car_lifetime = 20
		
}

if "${hybrid_lifetime_decr}" == "yes" {
	
		global vehicle_car_lifetime = 15
		
}		
	local val_given = ${val_given}
	local lifetime = ${vehicle_`veh_lifespan_type'_lifetime}
restore

****************************************************
/* 3d. HEV Battery Capacity Data */
****************************************************
preserve
	use "${assumptions}/evs/processed/hev_data", clear
	forvalues y = 2000(1)2006{
		qui sum batt_cap if year == `y'
		local batt_cap`y' = r(mean)
		qui sum batt_cap_N if year == `y'
		local total_sales`y' = r(mean)
	}
	if "`4'" == "baseline"{
		local batt_cap = (`total_sales2000' * `batt_cap2000' + `total_sales2001' * `batt_cap2001' + `total_sales2002' * `batt_cap2002' + `total_sales2003' * `batt_cap2003' + `total_sales2004' * `batt_cap2004' + `total_sales2005' * `batt_cap2005' + `total_sales2006' * `batt_cap2006') ///
						/ (`total_sales2000' + `total_sales2001' + `total_sales2002' + `total_sales2003' + `total_sales2004' + `total_sales2005' + `total_sales2006')
	}
	else{
		keep if year == ${run_year}
		qui sum batt_cap
		local batt_cap = r(mean)
	}
restore


****************************************************
/*                  3e. HEV Price Data            */
****************************************************
preserve
	use "${assumptions}/evs/processed/hev_data", clear
	forvalues y = 2000(1)2006{
		replace msrp = msrp * (${cpi_2000} / ${cpi_`y'}) if year == `y'
		qui sum msrp if year == `y'
		local msrp`y' = r(mean)
	}
	* calculating fixed price in paper's sample period for use in calculating a constant elasticity
	local elas_msrp = (`total_sales2000' * `msrp2000' + `total_sales2001' * `msrp2001' + `total_sales2002' * `msrp2002' + `total_sales2003' * `msrp2003' + `total_sales2004' * `msrp2004' + `total_sales2005' * `msrp2005' + `total_sales2006' * `msrp2006') ///
					/ (`total_sales2000' + `total_sales2001' + `total_sales2002' + `total_sales2003' + `total_sales2004' + `total_sales2005' + `total_sales2006')
	if "`4'" == "baseline"{
		local msrp = `elas_msrp'
	}
	else{
		use "${assumptions}/evs/processed/hev_data", clear
		keep if year == ${run_year}
		qui sum msrp
		local msrp = r(mean) * (${cpi_`dollar_year'} / ${cpi_${run_year}})
	}
restore

****************************************************
/*               3f. Population Data              */
****************************************************
preserve
	** avg over policy's time period (2000-2006) and across states
	if "`4'" == "baseline"{
		use "${assumptions}/evs/processed/pop_by_state_2000_2019", clear
		forvalues y = 2000(1)2006{
			qui sum pop`y' if state == "Connecticut"
			local CT_pop_`y' = r(mean)
			qui sum pop`y' if state == "District of Columbia"
			local DC_pop_`y' = r(mean)
			qui sum pop`y' if state == "Maine"
			local ME_pop_`y' = r(mean)
			qui sum pop`y' if state == "New Mexico"
			local NM_pop_`y' = r(mean)
		}
		keep if inlist(state, "Connecticut", "District of Columbia", "Maine", "New Mexico")
		collapse (sum) pop2000 pop2001 pop2002 pop2003 pop2004 pop2005 pop2006
		forvalues y = 2000(1)2006{
			qui sum pop`y'
			local total_pop`y' = r(mean)
		}
	}
restore

****************************************************
/* 3g. EV and ICE Age-State-Level VMT Data */
****************************************************
local ub = `lifetime'
local states CT DC ME NM

preserve
	if "`4'" == "baseline"{
		use "${assumptions}/evs/processed/ev_vmt_by_state_by_age", clear // survey data combines hybrids and BEVs
		keep if state == "CT" | state == "DC" | state == "ME" | state == "NM"
		keep state age vmt_by_state_age
		gen population = .
		foreach s of local states{
			local state_pop = 0
			forvalues y = 2000(1)2006{
				local state_pop = `state_pop' + ``s'_pop_`y''
			}
			replace population = `state_pop' / 7 if state == "`s'"
		}
		bysort age: egen N = total(population)
		by age: egen weighted_avg = total(vmt_by_state_age * population)
		replace weighted_avg = weighted_avg / N	

		local ub = `lifetime'
		duplicates drop age weighted_avg, force
		sort age
		forvalues y = 1(1)`ub'{
			local hev_miles_traveled`y' = weighted_avg[`y']
		}
	}
	else{
		use "${assumptions}/evs/processed/ev_vmt_by_age", clear
		local ub = `lifetime'
		duplicates drop age vmt, force
		sort age
		forvalues y = 1(1)`ub'{
			local hev_miles_traveled`y' = vmt[`y']
		}
	}
restore

preserve
	if "`4'" == "baseline"{
		use "${assumptions}/evs/processed/ice_vmt_by_state_by_age", clear
		keep if state == "CT" | state == "DC" | state == "ME" | state == "NM"
		keep state age vmt_by_state_age
		gen population = .
		foreach s of local states{
			local state_pop = 0
			forvalues y = 2000(1)2006{
				local state_pop = `state_pop' + ``s'_pop_`y''
			}
			replace population = `state_pop' / 7 if state == "`s'"
		}
		bysort age: egen N = total(population)
		by age: egen weighted_avg = total(vmt_by_state_age * population)
		replace weighted_avg = weighted_avg / N

		local ub = `lifetime'
		duplicates drop age weighted_avg, force
		sort age
		forvalues y = 1(1)`ub'{
			local ice_miles_traveled`y' = weighted_avg[`y']
		}
	}
	else{
		use "${assumptions}/evs/processed/ice_vmt_by_age", clear
		duplicates drop age vmt, force
		sort age
		forvalues y = 1(1)`ub'{
			local ice_miles_traveled`y' = vmt[`y']
		}
	}	
restore

** fixing HEVs vmt at same levels as ICE
forvalues y = 1(1)`ub'{
	local hev_miles_traveled`y' = `ice_miles_traveled`y''
}

****************************************************
/* 3h. Cost Curve */
****************************************************
preserve
	use "${assumptions}/evs/processed/battery_sales_combined", clear
	keep if year == `dollar_year'
	qui sum cum_sales
	local cum_sales = r(mean)
	qui sum marg_sales
	local marg_sales = r(mean)		
restore

preserve
	use "${assumptions}/evs/processed/all_cells_batt_costs_combined", clear
	if "`4'" == "baseline"{
		forvalues y = 2000(1)2006{
			qui sum prod_cost_2018 if year == `y'
			local prod_cost`y' = r(mean)
		}
		local prod_cost = (`mpg_N_2000' * `prod_cost2000' + `mpg_N_2001' * `prod_cost2001' + `mpg_N_2002' * `prod_cost2002' + `mpg_N_2003' * `prod_cost2003' + `mpg_N_2004' * `prod_cost2004' + `mpg_N_2005' * `prod_cost2005' + `mpg_N_2006' * `prod_cost2006') ///
						/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006')
		local batt_per_kwh_cost = `prod_cost'
	}
	else{
		keep if year == `dollar_year'
		qui sum prod_cost_2018
		local prod_cost = r(mean)
		local batt_per_kwh_cost = `prod_cost'
	}
restore

****************************************************
/* 3h. Subsidy Levels */
****************************************************
** Federal Subsidy

local elas_avg_fed_subsidy = 1073 // Table 3
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local avg_fed_subsidy = `elas_avg_fed_subsidy'
}
else{
	local avg_fed_subsidy = 0
	local avg_state_subsidy = 0 // no states offer normal hybrid subsidies in 2020
}

****************************************************
/* 4. Set local assumptions unique to this policy */
****************************************************
** Cost assumptions:
* Program costs - US$
if (`s_1' == 1 & `marg_mvpf' == 1) | (`non_marg_mvpf' == 1){
	local rebate_cost = 1037 // semi-elasticity is calculated for a $1k price decrease
}
else if `s_0' == 1{
	local rebate_cost = 0
}
else if `s_bar' == 1{
	local rebate_cost = 1037 / 2
}
local adj_rebate_cost = `rebate_cost' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})
local avg_subsidy = `adj_rebate_cost'
local elas_avg_subsidy = `rebate_cost' // state subsidy, always want this in the policy year's dollars

if "`4'" != "baseline"{
	if (`s_1' == 1 & `marg_mvpf' == 1) | (`non_marg_mvpf' == 1){
		local avg_subsidy = `avg_state_subsidy'
	}
	else if `s_0' == 1{
		local avg_subsidy = 0
	}
	else if `s_bar' == 1{
		local avg_subsidy = `avg_state_subsidy' / 2
	}
}

****************************************************
/*          5. Intermediate Calculations          */
****************************************************

** adjust semi-elasticity to be for $1 of subsidy instead of $1,000
local semie_paper = `semie'
local semie = `semie' / 1000 // this is the in-context semi-elasticity

local net_elas_msrp = `elas_msrp' - `elas_avg_fed_subsidy' - 0.5 * `elas_avg_subsidy'
local epsilon = -`semie' * `net_elas_msrp'
di in red "net msrp for elasticity is `net_elas_msrp'"

local net_msrp = `msrp' - `avg_subsidy' - `avg_fed_subsidy'
local total_subsidy = `avg_subsidy' + `avg_fed_subsidy'
if "`4'" != "baseline"{
	local semie = -`epsilon' / `net_msrp'
}

if `marg_mvpf' == 1{
	local beh_response = `semie'
}
else if `non_marg_mvpf' == 1{
	local beh_response = `semie' * `avg_subsidy'
}

* oil producers
local producer_price = `consumer_price' - `tax_rate'
local producer_mc = `producer_price' - `markup'

* no utility company producer surplus for HEVs

* intermediate rebound effect calculations for Latex

local per_diff_cost_driving = ((`consumer_price' / `hev_mpg') - (`consumer_price' / `hev_cf_mpg')) / (`consumer_price' / `hev_cf_mpg')
local hev_rebound = `per_diff_cost_driving' * -0.221

**************************
/* 6. Cost Calculations  */
**************************

* Program cost
if `marg_mvpf' == 1{
	local program_cost = 1
}
else if `non_marg_mvpf' == 1{
	local program_cost = (1 + `beh_response') * `avg_subsidy'
}

* no utility fiscal externality for HEVs

if "`4'" == "baseline"{
	local gas_fisc_ext = 0
	forvalues y = 1(1)`ub'{
		local gas_fisc_ext = `gas_fisc_ext' + ((`beh_response' * (`ice_miles_traveled`y'' * (1 / `hev_cf_mpg' - 1 / `hev_mpg')) * `tax_rate') / ((1 + `discount')^(`y' - 1)))
	}
}
else{
	local gas_fisc_ext = -`beh_response' * (${hybrid_cf_gas_fisc_ext_`dollar_year'} - ${`hev_cf'_cf_gas_fisc_ext_`dollar_year'}) 
	local tax_rate = ${nominal_gas_tax_`dollar_year'} // for Latex
}


local fed_fisc_ext = `beh_response' * `avg_fed_subsidy'
local avg_fed_subsidy_n = `avg_fed_subsidy' / `net_msrp'

local beh_fisc_ext = `semie' * `avg_subsidy'

if `marg_mvpf' == 1{
	local total_cost0 = `program_cost' + `gas_fisc_ext' + `fed_fisc_ext' + `beh_fisc_ext'
}
else if `non_marg_mvpf' == 1{
	local total_cost0 = `program_cost' + `gas_fisc_ext' + `fed_fisc_ext'
}


*************************
/* 7. WTP Calculations */
*************************

* consumers
local wtp_cons = 1

* marginal and inframarginal consumers
local wtp_marg = 0.5 * `beh_response' * `avg_subsidy'
local wtp_inf = `avg_subsidy'

local wtp_prod_s = 0

if "${value_profits}" == "yes"{

	* producers
	if "`4'" == "baseline"{
		local tot_gal_cf = 0
		local tot_gal_hy = 0
		local tot_sales = 0
		local gas_markup = 0
		forvalues y = 2000(1)2006{
			local tot_gal_cf = `tot_gal_cf' + ${`hev_cf'_gal_`y'} * `total_sales`y''
			local tot_gal_hy = `tot_gal_hy' + ${hybrid_gal_`y'} * `total_sales`y''
			local gas_markup = `gas_markup' + ${nominal_gas_markup_`y'} * `total_sales`y''
			local tot_sales = `tot_sales' + `total_sales`y''
		}
		local tot_gal_cf = `tot_gal_cf' / `tot_sales'
		local tot_gal_hy = `tot_gal_hy' / `tot_sales'
		local tot_gal = `tot_gal_cf' - `tot_gal_hy'
		local gas_markup = `gas_markup' / `tot_sales'
		local wtp_prod_s = 0
		forvalues y = 1(1)`ub'{
			local wtp_prod_s = `wtp_prod_s' + ((`beh_response' * (`ice_miles_traveled`y'' * (1/`hev_cf_mpg' - 1/`hev_mpg')) * (`producer_price' - `producer_mc')) / ((1 + `discount')^(`y' - 1))) // positive
		}
	}

	else{
		local tot_gal_cf = ${`hev_cf'_gal_`dollar_year'} // for Latex
		local tot_gal_hy = ${hybrid_gal_`dollar_year'} // for Latex
		local tot_gal = `tot_gal_cf' - `tot_gal_hy' // for Latex
		local gas_markup = ${nominal_gas_markup_`dollar_year'} // for Latex

		local wtp_prod_s = `beh_response' * (${hybrid_wtp_prod_s_`dollar_year'} - ${`hev_cf'_wtp_prod_s_`dollar_year'})
	}
}

*no utility producer surplus for HEVs
** take out the corporate effective tax rate
local total_wtp_prod_s = `wtp_prod_s'
local wtp_prod_s = `total_wtp_prod_s' * (1 - 0.21)
local gas_corp_fisc_e = `total_wtp_prod_s' * 0.21

if `marg_mvpf' == 1{
	local wtp_private = `wtp_cons' + `wtp_prod_s'
}
else if `non_marg_mvpf' == 1{
	local wtp_private = `wtp_marg' + `wtp_inf' + `wtp_prod_s'
}


* learning by doing
local prod_cost = `prod_cost' * (${cpi_`dollar_year'} / ${cpi_2018}) // data is in 2018USD

local batt_cost = `prod_cost' * `batt_cap'
local batt_frac = `batt_cost' / `msrp'

local fixed_cost_frac = 1 - `batt_frac'

local car_theta = `farmer_theta' * `batt_frac'


** Externality and WTP for driving a hybrid vehicle

if "`4'" == "baseline"{

	local hev_gas_consumed_year_one = `hev_miles_traveled1' / `hev_mpg' // for Latex

	forvalues y = 2000(1)2006{
		local yes_hev_ext_local_`y' = ${hybrid_cf_damages_loc_`y'}
		local yes_hev_ext_global_`y' = ${hybrid_cf_damages_glob_`y'}
		local yes_hev_carbon_content_`y' = ${hybrid_cf_carbon_`y'}
		local yes_hev_rbd_loc_`y' = ${yes_hev_rbd_loc_`y'}
		local yes_hev_rbd_glob_`y' = ${yes_hev_rbd_glob_`y'}
	
	}

	local hev_first_damages_g = 0
	local tot_sales = 0
	forvalues y = 2000(1)2006{
		local hev_first_damages_g = `hev_first_damages_g' + ${hybrid_first_damages_g_`y'} * `total_sales`y''
		local tot_sales = `tot_sales' + `total_sales`y''
	}
	local hev_first_damages_g = `hev_first_damages_g' / `tot_sales' // for Latex

	local q_carbon_yes_hev = -`beh_response' * ((`yes_hev_carbon_content_2000' * `mpg_N_2000' + `yes_hev_carbon_content_2001' * `mpg_N_2001' + `yes_hev_carbon_content_2002' * `mpg_N_2002' + `yes_hev_carbon_content_2003' * `mpg_N_2003' + `yes_hev_carbon_content_2004' * `mpg_N_2004' + `yes_hev_carbon_content_2005' * `mpg_N_2005' + `yes_hev_carbon_content_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local q_carbon_yes_hev_mck = `q_carbon_yes_hev' / `beh_response'
	
	

	local wtp_yes_hev_local = -`beh_response' * ((`yes_hev_ext_local_2000' * `mpg_N_2000' + `yes_hev_ext_local_2001' * `mpg_N_2001' + `yes_hev_ext_local_2002' * `mpg_N_2002' + `yes_hev_ext_local_2003' * `mpg_N_2003' + `yes_hev_ext_local_2004' * `mpg_N_2004' + `yes_hev_ext_local_2005' * `mpg_N_2005' + `yes_hev_ext_local_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local wtp_yes_hev_rbd_loc = -`beh_response' * ((`yes_hev_rbd_loc_2000' * `mpg_N_2000' + `yes_hev_rbd_loc_2001' * `mpg_N_2001' + `yes_hev_rbd_loc_2002' * `mpg_N_2002' + `yes_hev_rbd_loc_2003' * `mpg_N_2003' + `yes_hev_rbd_loc_2004' * `mpg_N_2004' + `yes_hev_rbd_loc_2005' * `mpg_N_2005' + `yes_hev_rbd_loc_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	
	local wtp_yes_hev_loc_no_rbd = `wtp_yes_hev_local' - `wtp_yes_hev_rbd_loc' // for Latex
	local wtp_yes_hev_global_tot = -`beh_response' * ((`yes_hev_ext_global_2000' * `mpg_N_2000' + `yes_hev_ext_global_2001' * `mpg_N_2001' + `yes_hev_ext_global_2002' * `mpg_N_2002' + `yes_hev_ext_global_2003' * `mpg_N_2003' + `yes_hev_ext_global_2004' * `mpg_N_2004' + `yes_hev_ext_global_2005' * `mpg_N_2005' + `yes_hev_ext_global_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local wtp_yes_hev_rbd_glob_tot = -`beh_response' * ((`yes_hev_rbd_glob_2000' * `mpg_N_2000' + `yes_hev_rbd_glob_2001' * `mpg_N_2001' + `yes_hev_rbd_glob_2002' * `mpg_N_2002' + `yes_hev_rbd_glob_2003' * `mpg_N_2003' + `yes_hev_rbd_glob_2004' * `mpg_N_2004' + `yes_hev_rbd_glob_2005' * `mpg_N_2005' + `yes_hev_rbd_glob_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local wtp_yes_hev_g = `wtp_yes_hev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	local wtp_yes_hev_rbd_glob = `wtp_yes_hev_rbd_glob_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local total_hev_damages_glob = `wtp_yes_hev_global_tot' / `beh_response' // for Latex
	local total_hev_damages_glob_n = `total_hev_damages_glob' / `net_msrp' // for Latex
	local total_hev_damages_loc_n = `wtp_yes_hev_local' / `beh_response' // for Latex
}

else{
	local hev_gas_consumed_year_one = `hev_miles_traveled1' / `hev_mpg' // for Latex
	local total_hev_damages_glob = ${hybrid_cf_damages_glob_`dollar_year'} - ${yes_hev_rbd_glob_`dollar_year'} // for Latex
	local total_hev_damages_glob_n = `total_hev_damages_glob' / `net_msrp' // for Latex
	local total_hev_damages_loc_n = ${hybrid_cf_damages_loc_`dollar_year'} / `net_msrp' // for Latex
	local hev_first_damages_g = ${hybrid_first_damages_g_2020} // for Latex

	local wtp_yes_hev_local = -`beh_response' * ${hybrid_cf_damages_loc_`dollar_year'} // with rebound
	local wtp_yes_hev_rbd_loc = -`beh_response' * ${yes_hev_rbd_loc_`dollar_year'}
	local wtp_yes_hev_loc_no_rbd = `wtp_yes_hev_local' - `wtp_yes_hev_rbd_loc' // for Latex

	local wtp_yes_hev_global_tot = -`beh_response' * `total_hev_damages_glob' // no rebound
	local wtp_yes_hev_rbd_glob_tot = -`beh_response' * ${yes_hev_rbd_glob_`dollar_year'}

	local wtp_yes_hev_g = `wtp_yes_hev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	local wtp_yes_hev_rbd_glob = `wtp_yes_hev_rbd_glob_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local q_carbon_yes_hev = -`beh_response' * ${hybrid_cf_carbon_`dollar_year'}
	local q_carbon_yes_hev_mck = ${hybrid_cf_carbon_`dollar_year'}
}

local wtp_soc_rbd = `wtp_yes_hev_rbd_glob' + `wtp_yes_hev_rbd_loc'


local yes_hev_local_ext = `wtp_yes_hev_local' / `beh_response'
local yes_hev_global_ext_tot = `wtp_yes_hev_global_tot' / `beh_response'
local wtp_yes_hev = `wtp_yes_hev_loc_no_rbd' + `wtp_yes_hev_g'


local yes_hev_ext = `wtp_yes_hev' / `beh_response'

** Externality and WTP for driving an ICE vehicle

if "`4'" == "baseline"{
	forvalues y = 2000(1)2006{
		local no_ice_ext_local_`y' = ${`hev_cf'_cf_damages_loc_`y'}
		local no_ice_ext_global_`y' = ${`hev_cf'_cf_damages_glob_`y'}
		local no_ice_carbon_content_`y' = ${`hev_cf'_cf_carbon_`y'}
	}

	
	local wtp_no_ice_local = `beh_response' * ((`no_ice_ext_local_2000' * `mpg_N_2000' + `no_ice_ext_local_2001' * `mpg_N_2001' + `no_ice_ext_local_2002' * `mpg_N_2002' + `no_ice_ext_local_2003' * `mpg_N_2003' + `no_ice_ext_local_2004' * `mpg_N_2004' + `no_ice_ext_local_2005' * `mpg_N_2005' + `no_ice_ext_local_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local wtp_no_ice_global_tot = `beh_response' * ((`no_ice_ext_global_2000' * `mpg_N_2000' + `no_ice_ext_global_2001' * `mpg_N_2001' + `no_ice_ext_global_2002' * `mpg_N_2002' + `no_ice_ext_global_2003' * `mpg_N_2003' + `no_ice_ext_global_2004' * `mpg_N_2004' + `no_ice_ext_global_2005' * `mpg_N_2005' + `no_ice_ext_global_2006' * `mpg_N_2006') ///
												/ (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	local ice_gas_consumed_year_one = `ice_miles_traveled1' / `hev_cf_mpg' // for Latex
	local total_ice_damages_glob = `wtp_no_ice_global_tot' / `beh_response' // for Latex
	local total_ice_damages_glob_n = `total_ice_damages_glob' / `net_msrp' // for Latex
	local total_ice_damages_loc = `wtp_no_ice_local' / `beh_response' // for Latex
	local total_ice_damages_loc_n = `total_ice_damages_loc' / `net_msrp' // for Latex
	local total_damages_loc_n = `total_hev_damages_loc_n' + `total_ice_damages_loc_n' // for Latex


	local q_carbon_no_ice = `beh_response' * ((`no_ice_carbon_content_2000' * `mpg_N_2000' + `no_ice_carbon_content_2001' * `mpg_N_2001' + `no_ice_carbon_content_2002' * `mpg_N_2002' + `no_ice_carbon_content_2003' * `mpg_N_2003' + `no_ice_carbon_content_2004' * `mpg_N_2004' + `no_ice_carbon_content_2005' * `mpg_N_2005' + `no_ice_carbon_content_2006' * `mpg_N_2006') / (`mpg_N_2000' + `mpg_N_2001' + `mpg_N_2002' + `mpg_N_2003' + `mpg_N_2004' + `mpg_N_2005' + `mpg_N_2006'))
	local q_carbon_no_ice_mck = `q_carbon_no_ice' / `beh_response'
}
else{
	local wtp_no_ice_local = `beh_response' * ${`hev_cf'_cf_damages_loc_`dollar_year'}
	local wtp_no_ice_global_tot = `beh_response' * ${`hev_cf'_cf_damages_glob_`dollar_year'}
	local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local ice_gas_consumed_year_one = `ice_miles_traveled1' / `hev_cf_mpg' // for Latex
	local total_ice_damages_glob = `wtp_no_ice_global_tot' / `beh_response' // for Latex
	local total_ice_damages_glob_n = `total_ice_damages_glob' / `net_msrp' // for Latex
	local total_ice_damages_loc = `wtp_no_ice_local' / `beh_response' // for Latex
	local total_ice_damages_loc_n = `total_ice_damages_loc' / `net_msrp' // for Latex
	local total_damages_loc_n = `total_hev_damages_loc_n' + `total_ice_damages_loc_n' // for Latex
	
	local q_carbon_no_ice = `beh_response' * ${`hev_cf'_cf_carbon_`dollar_year'}
	local q_carbon_no_ice_mck = ${`hev_cf'_cf_carbon_`dollar_year'}
}

local no_ice_local_ext = `wtp_no_ice_local' / `beh_response'
local no_ice_global_ext_tot = `wtp_no_ice_global_tot' / `beh_response'

local wtp_no_ice = `wtp_no_ice_local' + `wtp_no_ice_g'


local no_ice_ext = `wtp_no_ice' / `beh_response'

*** Battery manufacturing emissions

* Averaging the SCC for 2000-2006
if "`4'" == "baseline"{
	local relevant_scc = 0
	local total_sales = 0
	forvalues y = 2000(1)2006{
		local relevant_scc = `relevant_scc' + ${sc_CO2_`y'} * `total_sales`y''
		local total_sales = `total_sales' + `total_sales`y''
	}
	local relevant_scc = `relevant_scc' / `total_sales'
}
else{
	local relevant_scc = ${sc_CO2_`dollar_year'}
}

local batt_emissions = 214 + 20 // from Table 9 of Pipitone et al. (2021)

local batt_damages_n = (`batt_emissions' * 0.001 * `relevant_scc') / `net_msrp'

local batt_man_ext = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
local batt_man_ext_tot = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc'

local wtp_soc = `wtp_yes_hev' + `wtp_no_ice' - `batt_man_ext'
local wtp_glob = `wtp_yes_hev_g' + `wtp_no_ice_g' - `batt_man_ext'
local wtp_loc = `wtp_yes_hev_loc_no_rbd' + `wtp_no_ice_local'


local local_enviro_ext = (`wtp_no_ice_local' + `wtp_yes_hev_local') / `beh_response'
local global_enviro_ext_tot = (`wtp_no_ice_global_tot' + `wtp_yes_hev_global_tot' - `batt_man_ext_tot') / `beh_response'

local enviro_ext = `local_enviro_ext' + `global_enviro_ext_tot'

local prod_cost = `prod_cost' * `batt_cap' // cost of a battery in a car as opposed to cost per kWh

* learning-by-doing

*temporary solution -> if bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0{
	local epsilon = -0.001
}


local dyn_enviro_global_tot = 0
local env_cost_wtp_global_tot = 0
local cost_wtp = 0
local env_cost_wtp = 0
local env_cost_wtp_l = 0
local env_cost_wtp_g = 0
local dyn_price = 0

if "${lbd}" == "yes"{
	** --------------------- COST CURVE --------------------- **
	cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(constant_`enviro_ext')
	local dyn_enviro = `r(enviro_mvpf)'

	cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(constant_`local_enviro_ext')
	local dyn_enviro_local = `r(enviro_mvpf)'

	cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(constant_`global_enviro_ext_tot')
	local dyn_enviro_global_tot = `r(enviro_mvpf)'
	local dyn_enviro_global = `dyn_enviro_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	if `marg_mvpf' == 1{
		local dyn_price = `r(cost_mvpf)'
		local cost_wtp = `r(cost_mvpf)' * `program_cost'
		local env_cost_wtp = `dyn_enviro' * `program_cost' // same as local plus global_tot
		local env_cost_wtp_l = `dyn_enviro_local' * `program_cost'
		local env_cost_wtp_global_tot = `dyn_enviro_global_tot' * `program_cost'
		local env_cost_wtp_g = `dyn_enviro_global' * `program_cost'

		local env_cost_wtp = `env_cost_wtp_l' + `env_cost_wtp_g' // switching to not include the piece of the global dynamic enviro that will go to the FE

	}
	else if `non_marg_mvpf' == 1{
		local cost_wtp = (`r(cost_mvpf)' * `program_cost') / (1 + `beh_response')
		local env_cost_wtp = (`r(enviro_mvpf)' * `program_cost') / (1 + `beh_response')
	}
}

local q_carbon = `q_carbon_no_ice' + `q_carbon_yes_hev'
local q_carbon_no = `q_carbon'
local q_carbon_cost_curve = `dyn_enviro_global_tot' / ${sc_CO2_`dollar_year'}
local q_carbon_cost_curve_mck = `q_carbon_cost_curve' / `beh_response'
local q_carbon_mck = `q_carbon_no_ice_mck' + `q_carbon_yes_hev_mck'
local q_carbon = `q_carbon' + `q_carbon_cost_curve'


********** Long-Run Fiscal Externality **********

local fisc_ext_lr = -1 * (`wtp_no_ice_global_tot' + `wtp_yes_hev_global_tot' + `env_cost_wtp_global_tot' + `batt_man_ext_tot') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
local total_cost = `total_cost0' + `fisc_ext_lr' + `gas_corp_fisc_e'

************************************************

if "${value_savings}" == "yes" & "`4'" == "current" {
	
	local wtp_savings = `beh_response' * (${`hev_cf'_cf_gas_savings_`dollar_year'} - ${hybrid_cf_gas_savings_`dollar_year'})
	
}
else {
	
	local wtp_savings = 0
	
}

* Total WTP
local WTP = `wtp_private' + `wtp_soc' + `wtp_savings' + `wtp_soc_rbd' // not including learning-by-doing
local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp'

// Quick Decomposition

/* Assumptions:

	- wtp_private, cost_wtp -> US Present
	- wtp_soc, env_cost_wtp -> US Future & Rest of the World

*/

local WTP_USPres = `wtp_private' + `wtp_yes_hev_local' + `wtp_no_ice_local' + `env_cost_wtp_l' + `wtp_savings'
local WTP_USFut = (${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC})) * (`wtp_yes_hev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot') + 0.1 * `cost_wtp'
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`wtp_yes_hev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot') + 0.9 * `cost_wtp'

**************************
/* 8. MVPF Calculations */
**************************

local MVPF = `WTP_cc' / `total_cost'
local MVPF_no_cc = `WTP' / `total_cost'

****************************************
/* 9. Cost-Effectiveness Calculations */
****************************************


local hev_price = 28359.08333 // from KBB, look at spreadsheet
local ice_price = 27012.5 // from KBB, look at spreadsheet

local lifetime_hev_gas_cost = ${hybrid_cf_gas_savings_2020} - ${hybrid_wtp_prod_s_2020} - 0.08 * ${hybrid_cf_gas_savings_2020} - ${hybrid_cf_gas_fisc_ext_2020}
di in red "hev gas cost is `lifetime_hev_gas_cost'"
local lifetime_ice_gas_cost = ${muehl_cf_gas_savings_2020} - ${muehl_wtp_prod_s_2020} - 0.08 * ${muehl_cf_gas_savings_2020} - ${muehl_cf_gas_fisc_ext_2020}
di in red "ice gas cost is `lifetime_ice_gas_cost'"


local resource_cost = `hev_price' + `lifetime_hev_gas_cost' - `ice_price' - `lifetime_ice_gas_cost'
di in red "resource cost is `resource_cost'"
local q_carbon_yes_hev_mck = ${hybrid_cf_carbon_2020} + ((214 + 20) * 0.001) - ${hybrid_rbd_CO2_2020}

local q_carbon_no_ice_mck = ${muehl_cf_carbon_2020}

local q_carbon_mck = `q_carbon_no_ice_mck' - `q_carbon_yes_hev_mck'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `semie' * `q_carbon_mck'

*****************
/* 10. Outputs */
*****************

global MVPF_`1' = `MVPF'
global MVPF_no_cc_`1' = `MVPF_no_cc'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global WTP_cc_`1' = `WTP_cc'
global enviro_mvpf_`1' = `dyn_enviro_global_tot'
global cost_mvpf_`1' = `dyn_price'
global wtp_marg_`1' = `wtp_marg'
global wtp_inf_`1' = `wtp_inf'
global wtp_cons_`1' = `wtp_cons'
global wtp_prod_s_`1' = `wtp_prod_s'

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
global gas_fisc_ext_`1' = `gas_fisc_ext'
global beh_fisc_ext_`1' = `beh_fisc_ext'
global fed_fisc_ext_`1' = `fed_fisc_ext'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global gas_corp_fisc_e_`1' = `gas_corp_fisc_e'
global `1'_ep = round(`epsilon', 0.001)

global wtp_soc_`1' = `wtp_soc'
global wtp_glob_`1' = `wtp_glob'
global wtp_loc_`1'= `wtp_loc'
global wtp_soc_rbd_`1' = `wtp_soc_rbd'

global wtp_no_ice_`1' = `wtp_no_ice'
global wtp_no_ice_local_`1' = `wtp_no_ice_local'
global wtp_no_ice_g_`1' = `wtp_no_ice_g'

global wtp_yes_hev_`1' = `wtp_yes_hev'
global wtp_yes_hev_local_`1' = `wtp_yes_hev_local'
global wtp_yes_hev_g_`1' = `wtp_yes_hev_g'

global env_cost_wtp_`1' = `env_cost_wtp'
global env_cost_wtp_l_`1' = `env_cost_wtp_l'
global env_cost_wtp_g_`1' = `env_cost_wtp_g'

global cost_wtp_`1' = `cost_wtp'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global c_savings_`1' = `wtp_savings'

global gov_carbon_`1' = `gov_carbon'
global q_CO2_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'
global semie_`1' = `semie'

** for waterfall charts

global wtp_comps_`1' wtp_cons wtp_glob wtp_loc wtp_soc_rbd env_cost_wtp cost_wtp wtp_prod_s WTP_cc
global wtp_comps_`1'_commas "wtp_cons", "wtp_glob", "wtp_loc", "wtp_soc_rbd", "env_cost_wtp", "cost_wtp", "wtp_prod_s", "WTP_cc"

global cost_comps_`1' program_cost beh_fisc_ext fed_fisc_ext gas_fisc_ext gas_corp_fisc_e fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "beh_fisc_ext", "fed_fisc_ext", "gas_fisc_ext", "gas_corp_fisc_e", "fisc_ext_lr", "total_cost"

global `1'_xlab 1 `"Consumers"' 2 `""Global" "Env.""' 3 `""Local" "Env.""' 4 `"Rebound"' 5 `""Dynamic" "Env.""' 6 `""Dynamic" "Price""' 7 `""Gasoline" "Producers""' 8 `"Total WTP"' 10 `""Program" "Cost""' 11 `""State" "Subsidy""' 12 `""Federal" "Subsidy""' 13 `""Gas" "Tax""' 14 `""Profits" "Tax""' 15 `""Climate" "FE""' 16 `""Govt" "Cost""' ///

*color groupings
global color_group1_`1' = 1
global color_group2_`1' = 4
global color_group3_`1' = 6
global color_group4_`1' = 7
global cost_color_start_`1' = 10
global color_group5_`1' = 15





global `1'_name "HEV USA - Sales Tax Waiver"



// Stuff for the description
if `marg_mvpf' == 1{
	local mvpf_def "Marginal"
	if `s_0' == 1{
		local s_def "s_0"
	}
	if `s_1' == 1{
		local s_def "s_1"
	}
	if `s_bar' == 1{
		local s_def "s_bar"
	}
}
if `non_marg_mvpf' == 1{
	local mvpf_def "Non-Marginal"
	local s_def "N/A"
}
if `new_cost_curve' == 1{
	local cc_def "Dynamic Battery Fraction"
}
if `old_cost_curve' == 1{
	local cc_def "Fixed Battery Fraction"
}

local y_ub = `WTP_cc' + 0.3
global note_`1' = ""
global normalize_`1' = 1
global yscale_`1' = "range(0 `y_ub')"


di in red "Main Estimates"
di "`4'"
di `wtp_cons'
di `wtp_marg'
di `wtp_inf'
di `wtp_prod_s'
di `wtp_yes_hev'
di `wtp_no_ice'
di `wtp_soc'
di `env_cost_wtp'
di `cost_wtp'
di `WTP_cc'
di `program_cost'
di `beh_fisc_ext'
di `fed_fisc_ext'
di `gas_fisc_ext'
di `fisc_ext_lr'
di `total_cost'
di in red "End of Main Estimates"

di in red "Cost Curve Inputs"
di `epsilon'
di `discount'
di `farmer_theta'
di `batt_cost'
di `msrp'
di `prod_cost'
di `batt_per_kwh_cost'
di `batt_cap'
di `fixed_cost_frac'
di `marg_sales'
di `cum_sales'
di `enviro_ext'
di in red "End of Cost Curve Inputs"

di in red "Behavioral Fiscal Externality Inputs"
di `semie'
di `avg_subsidy'
di `adj_rebate_cost'
di `rebate_cost'
di ${cpi_`dollar_year'}
di ${cpi_${policy_year}}
di in red "End of Fiscal Externality Inputs"

if "${latex}" == "yes"{
	if "`hev_cf'" == "muehl" & ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs semie msrp net_msrp total_subsidy total_hev_damages_glob hev_first_damages_g wtp_yes_hev_g wtp_no_ice_global_tot ///
					wtp_no_ice_g wtp_glob wtp_loc wtp_soc_rbd marg_sales cum_sales batt_frac fixed_cost_frac ice_gas_consumed_year_one total_hev_damages_glob_n ///
					total_ice_damages_glob_n total_ice_damages_loc total_ice_damages_loc_n batt_per_kwh_cost batt_cap env_cost_wtp cost_wtp ///
					tot_gal gas_markup wtp_prod_s WTP_cc total_hev_damages_loc_n total_damages_loc_n ///
					avg_fed_subsidy avg_fed_subsidy_n fed_fisc_ext avg_subsidy beh_fisc_ext gas_fisc_ext tax_rate fisc_ext_lr ///
					total_cost MVPF semie_paper epsilon hev_mpg hev_gas_consumed_year_one per_diff_cost_driving hev_rebound ///
					wtp_yes_hev_loc_no_rbd batt_damages_n batt_man_ext hev_cf_mpg gas_corp_fisc_e
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy/BEVandHEVAppendices/macros_`1'_`4'.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'}" _n
		foreach i of local outputs{

			local original = "`i'"
			local newname = "`i'"

			// Remove underscores from the variable name
			while strpos("`newname'", "_"){
				local newname = subinstr("`newname'", "_", "", .)
			}
			local 1 = subinstr("`1'", "_", "", .)
			local 4 = subinstr("`4'", "_", "", .)

			if inlist("`i'", "msrp", "net_msrp", "marg_sales", "cum_sales", "batt_per_kwh_cost", "tot_kwh", "ice_gas_consumed_year_one", "avg_subsidy", "total_subsidy") | inlist("`i'", "tot_gal") {
				local `original' = trim("`: display %8.0gc ``original'''")
			}
			else if inlist("`i'", "avg_fed_subsidy", "total_subsidy") {
				local `original' = trim("`: display %5.2fc ``original'''")
			}
			else if inlist("`i'", "semie", "gas_corp_fisc_e"){
				local `original' = trim("`: display %5.4fc ``original'''")
			}
			else{
				local `original' = trim("`: display %5.3fc ``original'''")
			}
			local command = "\newcommand{\\`newname'`1'`4'}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}

	if "`hev_cf'" == "new_car" & ${sc_CO2_2020} == 193{

		** Latex Output with dirty counterfactual
		local outputs MVPF
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy/BEVandHEVAppendices/macros_`1'_`4'_dirty_cf.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'_dirty_cf}" _n
		foreach i of local outputs{

			local original = "`i'"
			local newname = "`i'"

			// Remove underscores from the variable name
			while strpos("`newname'", "_"){
				local newname = subinstr("`newname'", "_", "", .)
			}
			local 1 = subinstr("`1'", "_", "", .)
			local 4 = subinstr("`4'", "_", "", .)

			
			local `original' = trim("`: display %5.3fc ``original'''")
			
			local command = "\newcommand{\\`newname'`1'`4'dirtycf}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}
}
