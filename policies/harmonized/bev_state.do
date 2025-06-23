*************************************************************************************
/*       0. Program: State-Level Battery Electric Vehicle (BEV) Rebate        */
*************************************************************************************

/*
Clinton, Bentley C., and Daniel C. Steinberg. 
"Providing the Spark: Impact of financial incentives on battery electric vehicle 
adoption." Journal of Environmental Economics and Management 98 (2019): 102255.
* https://www.sciencedirect.com/science/article/pii/S0095069618303115
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

local dynamic_grid = 1
local static_grid = 0

local want_rebound = 1

local bev_cf = "${bev_cf}"
local veh_lifespan_type = substr("${bev_cf}", strpos("${bev_cf}", "_") + 1, .)

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

local farmer_theta = -0.421 // Way et al. (2022)

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
/* 3a. EV Counterfactual Vehicle Fuel Economy Data */
****************************************************
preserve
	use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
	forvalues y = 2011(1)2014{
		qui sum total_sales if year == `y'
		local total_sales`y' = r(mean)
	}
	if "`4'" == "baseline"{
		keep if year >= 2011 & year <= 2014
		forvalues y = 2011(1)2014{
			qui sum total_sales if year == `y'
			local total_sales`y' = r(mean)
			qui sum cf_mpg if year == `y'
			local cf_mpg_`y' = r(mean)
		}
		local ev_cf_mpg = (`total_sales2011' * `cf_mpg_2011' + `total_sales2012' * `cf_mpg_2012' + `total_sales2013' * `cf_mpg_2013' + `total_sales2014' * `cf_mpg_2014') ///
							/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
	}
	else{
		keep if year == ${run_year}
		qui sum cf_mpg
		local ev_cf_mpg = r(mean)
	}
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
		keep tax2011 tax2012 tax2013 tax2014 state
		replace tax2011 = tax2011 * (${cpi_${dollar_year}} / ${cpi_2011})
		replace tax2012 = tax2012 * (${cpi_${dollar_year}} / ${cpi_2012})
		replace tax2013 = tax2013 * (${cpi_${dollar_year}} / ${cpi_2013})
		replace tax2014 = tax2014 * (${cpi_${dollar_year}} / ${cpi_2014})
		keep if state == "California" | state == "Hawaii" | state == "Illinois" | state == "Massachusetts" | state == "Pennsylvania" | state == "Tennessee" | state == "Texas"
		merge m:1 state using "${assumptions}/evs/processed/pop_by_state", keep(match)
		gen N = pop2011 + pop2012 + pop2013 + pop2014
		gen weighted_avg = pop2011 * tax2011 + pop2012 * tax2012 + pop2013 * tax2013 + pop2014 * tax2014
		replace weighted_avg = weighted_avg / N
		
		egen N_states = total(N)
		egen weighted_avg_states = total(N * weighted_avg)
		replace weighted_avg_states = weighted_avg_states / N_states
		sum weighted_avg_states
		local tax_rate = r(mean) / 100

		use "${gas_price_data}/gas_data_monthly", clear
		keep if inrange(year, 2010, 2014)
		drop if year == 2014 & month > 6
		* Clinton and Steinberg 2019 look at BEV rebates for Q1 2010 through Q2 2014. 
		* Calculate gas price for 2014 using only 6 months in 2014 sample. 

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
/* 3c. EV Specific Assumptions */
****************************************************
preserve
	qui import excel "${policy_assumptions}", first clear sheet("evs")
		
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}
		
	local val_given = ${val_given}
	
	if "${vehicle_lifetime_change}" == "yes" {
		global vehicle_car_lifetime = ${new_vehicle_lifetime}
	}

	local lifetime = ${vehicle_`veh_lifespan_type'_lifetime}
restore

****************************************************
/* 3d. EV Energy Consumption Data */
****************************************************
preserve
	use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
	if "`4'" == "baseline"{
		forvalues y = 2011(1)2014{
			qui sum avg_kwh_per_mile if year == `y'
			local kwh_per_mile`y' = r(mean)
			qui sum avg_batt_cap if year == `y'
			local batt_cap`y' = r(mean)
		}

		local kwh_per_mile = (`total_sales2011' * `kwh_per_mile2011' + `total_sales2012' * `kwh_per_mile2012' + `total_sales2013' * `kwh_per_mile2013' + `total_sales2014' * `kwh_per_mile2014') ///
							/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
		local batt_cap = (`total_sales2011' * `batt_cap2011' + `total_sales2012' * `batt_cap2012' + `total_sales2013' * `batt_cap2013' + `total_sales2014' * `batt_cap2014') ///
							/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
	}
	else{
		keep if year == ${run_year}
		qui sum avg_kwh_per_mile
		local kwh_per_mile = r(mean)
		qui sum avg_batt_cap
		local batt_cap = r(mean)
	}
restore


****************************************************
/*                  3e. EV Price Data             */
****************************************************
preserve
	use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
	forvalues y = 2011(1)2014{
		replace avg_msrp = avg_msrp * (${cpi_2011} / ${cpi_`y'}) if year == `y'
		qui sum avg_msrp if year == `y'
		local msrp`y' = r(mean)
	}
	* calculating fixed price in paper's sample period for use in calculating a constant elasticity
	local elas_msrp = (`total_sales2011' * `msrp2011' + `total_sales2012' * `msrp2012' + `total_sales2013' * `msrp2013' + `total_sales2014' * `msrp2014') ///
					/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
	if "`4'" == "baseline"{
		local msrp = `elas_msrp'
	}
	else{
		use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
		keep if year == ${run_year}
		qui sum avg_msrp
		local msrp = r(mean) * (${cpi_`dollar_year'} / ${cpi_${run_year}})
	}
restore

****************************************************
/* 3f. Population Data */
****************************************************
preserve
	** avg over policy's time period (2011-2014) and across states
	** No Hawaii!!!
	if "`4'" == "baseline"{
		use "${assumptions}/evs/processed/pop_by_state_2000_2019", clear
		forvalues y = 2011(1)2014{
			qui sum pop`y' if state == "California"
			local CA_pop_`y' = r(mean)
			qui sum pop`y' if state == "Illinois"
			local IL_pop_`y' = r(mean)
			qui sum pop`y' if state == "Massachusetts"
			local MA_pop_`y' = r(mean)
			qui sum pop`y' if state == "Pennsylvania"
			local PA_pop_`y' = r(mean)
			qui sum pop`y' if state == "Tennessee"
			local TN_pop_`y' = r(mean)
			qui sum pop`y' if state == "Texas"
			local TX_pop_`y' = r(mean)
		}
		keep if state == "California" | state == "Massachusetts" | state == "Pennsylvania" | state == "Tennessee" | state == "Texas"
		collapse (sum) pop2011 pop2012 pop2013 pop2014
		forvalues y = 2011(1)2014{
			qui sum pop`y'
			local total_pop`y' = r(mean)
		}
	}
restore

****************************************************
/* 3g. EV and ICE Age-State-Level VMT Data */
****************************************************
local ub = `lifetime'
local states CA IL MA PA TN TX

preserve
 	if "`4'" == "baseline"{
 		use "${assumptions}/evs/processed/ev_vmt_by_state_by_age", clear
 		keep if state == "CA" | state == "HI" | state == "IL" | state == "MA" | state == "PA" | state == "TN" | state == "TX"
 		keep state age vmt_by_state_age
 		gen population = .
 		foreach s of local states{
 			local state_pop = 0
 			forvalues y = 2011(1)2014{
 				local state_pop = `state_pop' + ``s'_pop_`y''
 			}
 			replace population = `state_pop' / 4 if state == "`s'"
 		}
 		bysort age: egen N = total(population)
 		by age: egen weighted_avg = total(vmt_by_state_age * population)
 		replace weighted_avg = weighted_avg / N

 		local ub = `lifetime'
 		duplicates drop age weighted_avg, force
 		sort age
 		forvalues y = 1(1)`ub'{
 			local ev_miles_traveled`y' = weighted_avg[`y']
 		}
 	}
 	else{
 		use "${assumptions}/evs/processed/ev_vmt_by_age", clear
 		local ub = `lifetime'
 		duplicates drop age vmt, force
 		sort age
 		forvalues y = 1(1)`ub'{
 			local ev_miles_traveled`y' = vmt[`y']
 		}
 	}
restore

preserve
	if "`4'" == "baseline"{
		use "${assumptions}/evs/processed/ice_vmt_by_state_by_age", clear
		keep if state == "CA" | state == "HI" | state == "IL" | state == "MA" | state == "PA" | state == "TN" | state == "TX"
		keep state age vmt_by_state_age
		gen population = .
		foreach s of local states{
			local state_pop = 0
			forvalues y = 2011(1)2014{
				local state_pop = `state_pop' + ``s'_pop_`y''
			}
			replace population = `state_pop' / 4 if state == "`s'"
		}
		bysort age: egen N = total(population)
		by age: egen weighted_avg = total(vmt_by_state_age * population)
		replace weighted_avg = weighted_avg / N

		local ub = `lifetime'
		duplicates drop age weighted_avg, force
		sort age
		forvalues y = 1(1)`ub'{
			local ice_miles_traveled`y' = weighted_avg[`y'] * ${EV_VMT_car_adjustment}
		}
	}
	else{
		use "${assumptions}/evs/processed/ice_vmt_by_age", clear
		duplicates drop age vmt, force
		sort age
		forvalues y = 1(1)`ub'{
			local ice_miles_traveled`y' = vmt[`y'] * ${EV_VMT_car_adjustment}
		}
	}	
restore

** Fixing EVs vmt at same levels as ICE
forvalues y = 1(1)`ub'{
	local ev_miles_traveled`y' = `ice_miles_traveled`y''
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
	use "${assumptions}/evs/processed/cyl_batt_costs_combined", clear
	if "`4'" == "baseline"{
		forvalues y = 2011(1)2014{
			qui sum prod_cost_2018 if year == `y'
			local prod_cost`y' = r(mean)
		}
		local prod_cost = (`total_sales2011' * `prod_cost2011' + `total_sales2012' * `prod_cost2012' + `total_sales2013' * `prod_cost2013' + `total_sales2014' * `prod_cost2014') ///
						/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
		local batt_per_kwh_cost = `prod_cost' * (${cpi_2020} / ${cpi_2018})
	}
	else{
		keep if year == `dollar_year'
		qui sum prod_cost_2018
		local prod_cost = r(mean)
		local batt_per_kwh_cost = `prod_cost' * (${cpi_2020} / ${cpi_2018})
	}
restore

****************************************************
/* 3i. Subsidy Levels */
****************************************************
preserve
	** Federal Subsidy
	
	use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
	keep if year >= 2011 & year <= 2014
	egen N = total(subsidy_N)
	egen weighted_avg = total(subsidy_weighted_avg * subsidy_N)
	replace weighted_avg = weighted_avg / N
	qui sum weighted_avg
	local elas_avg_fed_subsidy = r(mean)

	if "`4'" == "baseline"{
		local avg_fed_subsidy = `elas_avg_fed_subsidy'
	}
	else{
		use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
		keep if year == ${run_year}
		qui sum subsidy_weighted_avg
		local avg_fed_subsidy = r(mean)

		local avg_state_subsidy = 604.27 // see NST-EST2023-POP spreadsheet in data/1_assumptions/evs
	}
	if "${ev_fed_subsidy}" != ""{
		if ${ev_fed_subsidy} != -1 {
			local avg_fed_subsidy = ${ev_fed_subsidy}
		}
	}
restore

****************************************************
/* 4. Set local assumptions unique to this policy */
****************************************************
** Cost assumptions:
* Program costs - US$, (Table 8) 
if (`s_1' == 1 & `marg_mvpf' == 1) | (`non_marg_mvpf' == 1){
	local rebate_cost = 185444000 / 69972 // numerator from Table 8, denominator is sum of BEV registrations in Panel A of Table 1
}
else if `s_0' == 1{
	local rebate_cost = 0
}
else if `s_bar' == 1{
	local rebate_cost = 2912 / 2 // From Table 2 of Clinton et al. (2019)
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

local net_elas_msrp = `elas_msrp' - `elas_avg_fed_subsidy' - 0.5 * `elas_avg_subsidy' //we take the midpoint of the subsidy (0.5) to estimate the elasticity
local epsilon = -`semie' * `net_elas_msrp'

local net_msrp = `msrp' - `avg_subsidy' - `avg_fed_subsidy'
local total_subsidy = `avg_subsidy' + `avg_fed_subsidy'
if "`4'" != "baseline"{
	local semie = -`epsilon' / `net_msrp'
}

if `marg_mvpf' == 1{
	local beh_response = `semie' // positive
}
else if `non_marg_mvpf' == 1{
	local beh_response = `semie' * `avg_subsidy'
}

* oil producers
local producer_price = `consumer_price' - `tax_rate'
local producer_mc = `producer_price' - `markup'

* utility companies
if "`4'" == "baseline"{
	* not including Hawaii for utility producer surplus or gov revenue
	forvalues y = 2011(1)2014{
		local util_gov_revenue_`y' = (`CA_pop_`y'' * ${government_revenue_`y'_CA} + `IL_pop_`y'' * ${government_revenue_`y'_IL} + `MA_pop_`y'' * ${government_revenue_`y'_MA} + `PA_pop_`y'' * ${government_revenue_`y'_PA} + `TN_pop_`y'' * ${government_revenue_`y'_TN} + `TX_pop_`y'' * ${government_revenue_`y'_TX}) ///
									/ (`CA_pop_`y'' + `IL_pop_`y'' + `MA_pop_`y'' + `PA_pop_`y'' + `TN_pop_`y'' + `TX_pop_`y'')
		local util_producer_surplus_`y' = (`CA_pop_`y'' * ${producer_surplus_`y'_CA}  + `IL_pop_`y'' * ${producer_surplus_`y'_IL} + `MA_pop_`y'' * ${producer_surplus_`y'_MA} + `PA_pop_`y'' * ${producer_surplus_`y'_PA} + `TN_pop_`y'' * ${producer_surplus_`y'_TN} + `TX_pop_`y'' * ${producer_surplus_`y'_TX}) ///
									/ (`CA_pop_`y'' + `IL_pop_`y'' + `MA_pop_`y'' + `PA_pop_`y'' + `TN_pop_`y'' + `TX_pop_`y'')
	}
	local util_gov_revenue = (`util_gov_revenue_2011' * `total_pop2011' + `util_gov_revenue_2012' * `total_pop2012' + `util_gov_revenue_2013' * `total_pop2013' + `util_gov_revenue_2014' * `total_pop2014') ///
									/ (`total_pop2011' + `total_pop2012' + `total_pop2013' + `total_pop2014')
	local util_producer_surplus = (`util_producer_surplus_2011' * `total_pop2011' + `util_producer_surplus_2012' * `total_pop2012' + `util_producer_surplus_2013' * `total_pop2013' + `util_producer_surplus_2014' * `total_pop2014') ///
									/ (`total_pop2011' + `total_pop2012' + `total_pop2013' + `total_pop2014')
}

else{
	local util_gov_revenue ${government_revenue_`dollar_year'_${State}}
	local util_producer_surplus ${producer_surplus_`dollar_year'_${State}}
}

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

local utility_fisc_ext = 0
forvalues y = 1(1)`ub'{
	local utility_fisc_ext = `utility_fisc_ext' + (`beh_response' * `ev_miles_traveled`y'' * `kwh_per_mile' * `util_gov_revenue') / ((1 + `discount')^(`y' - 1)) // gain in profit tax from highter utility profits + gain in gov revenue since 28% of utilities are publicly owned (EIA 2019)
}

if "`4'" == "baseline"{
	local gas_fisc_ext = 0
	forvalues y = 1(1)`ub'{
		local gas_fisc_ext = `gas_fisc_ext' + ((`beh_response' * (`ice_miles_traveled`y'' / `ev_cf_mpg') * `tax_rate') / ((1+`discount')^(`y' - 1)))
	}
}
else{
	local gas_fisc_ext = `beh_response' * ${`bev_cf'_cf_gas_fisc_ext_`dollar_year'}
	local tax_rate = ${nominal_gas_tax_`dollar_year'} // for Latex
}


local fed_fisc_ext = `beh_response' * `avg_fed_subsidy'
local avg_fed_subsidy_n = `avg_fed_subsidy' / `net_msrp'

local beh_fisc_ext = `semie' * `avg_subsidy'

if `marg_mvpf' == 1{
	local total_cost = `program_cost' - `utility_fisc_ext' + `gas_fisc_ext' + `fed_fisc_ext' + `beh_fisc_ext'
}
else if `non_marg_mvpf' == 1{
	local total_cost = `program_cost' - `utility_fisc_ext' + `gas_fisc_ext' + `fed_fisc_ext'
}


*************************
/* 7. WTP Calculations */
*************************

* consumers
local wtp_cons = 1

* marginal and inframarginal consumers
local wtp_marg = 0.5 * `beh_response' * `avg_subsidy'
local wtp_inf = `avg_subsidy'

local wtp_prod_u = 0
local wtp_prod_s = 0

if "${value_profits}" == "yes"{

	if "`4'" == "baseline"{
		local tot_gal = (${`bev_cf'_gal_2011} * `total_sales2011' + ${`bev_cf'_gal_2012} * `total_sales2012' + ${`bev_cf'_gal_2013} * `total_sales2013' + ${`bev_cf'_gal_2014} * `total_sales2014') ///
									  / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014') // for Latex
		local gas_markup = (${nominal_gas_markup_2011} * (${cpi_${dollar_year}} / ${cpi_2011}) * `total_sales2011' + ${nominal_gas_markup_2012} * (${cpi_${dollar_year}} / ${cpi_2012}) * `total_sales2012' + ${nominal_gas_markup_2013} * (${cpi_${dollar_year}} / ${cpi_2013}) * `total_sales2013' + ${nominal_gas_markup_2014} * (${cpi_${dollar_year}} / ${cpi_2014}) * `total_sales2014') ///
									  / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014') // for Latex

		local wtp_prod_s = 0
		forvalues y = 1(1)`ub'{
			local wtp_prod_s = `wtp_prod_s' + ((`beh_response' * (`ice_miles_traveled`y'' / `ev_cf_mpg') * (`producer_price' - `producer_mc')) / ((1 + `discount')^(`y' - 1))) // positive
		}
	}

	else{
		local tot_gal = ${`bev_cf'_gal_`dollar_year'} // for Latex
		local gas_markup = ${nominal_gas_markup_`dollar_year'} // for Latex

		local wtp_prod_s = `beh_response' * ${`bev_cf'_wtp_prod_s_`dollar_year'} 

	}

	* producers - utilities
	local wtp_prod_u = 0
	local tot_kwh = 0

	forvalues y = 1(1)`ub'{
		local tot_kwh = `tot_kwh' + (`ev_miles_traveled`y'' * `kwh_per_mile') // for Latex
		local wtp_prod_u = `wtp_prod_u' + ((`beh_response' * (`ev_miles_traveled`y'' * `kwh_per_mile') * `util_producer_surplus') / ((1 + `discount')^(`y' - 1)))
	}
}

** take out the 21% corporate effective tax rate
local total_wtp_prod_s = `wtp_prod_s'
local wtp_prod_s = `total_wtp_prod_s' * (1 - 0.21)
local gas_corp_fisc_e = `total_wtp_prod_s' * 0.21

local profits_fisc_e = `gas_corp_fisc_e' - `utility_fisc_ext'

if `marg_mvpf' == 1{
	local wtp_private = `wtp_cons' - `wtp_prod_s' + `wtp_prod_u'
}
else if `non_marg_mvpf' == 1{
	local wtp_private = `wtp_marg' + `wtp_inf' - `wtp_prod_s' + `wtp_prod_u'
}


* learning by doing
local prod_cost = `prod_cost' * (${cpi_`dollar_year'} / ${cpi_2018}) // data is in 2018USD

local batt_cost = `prod_cost' * `batt_cap'
local batt_frac = `batt_cost' / `msrp'

local fixed_cost_frac = 1 - `batt_frac'

local car_theta = `farmer_theta' * `batt_frac'


** Externality and WTP for driving a battery electric vehicle

if "`4'" == "baseline"{
	
	local kwh_used_year_one = `ev_miles_traveled1' * `kwh_per_mile' // for Latex
	
	*** dynamic grid stuff
	local kwh_used `ev_miles_traveled1' * `kwh_per_mile'
	local end_year = `dollar_year' + `ub' - 1
	* no HI rip
	local states CA MA PA TN TX
	foreach s of local states{
		local i = 1
		local kwh_used `ev_miles_traveled1' * `kwh_per_mile'
		forvalues y = `dollar_year'(1)`end_year'{
			dynamic_split_grid `kwh_used', starting_year(`dollar_year') ext_year(`y') discount_rate(`discount') ef(${replacement}) geo("`s'") type("uniform") grid_specify("yes") model(${grid_model})
			if `i' == 1{
				local ev_first_damages_g_`s' = `r(global_enviro_ext)' // for Latex
			}
			local i = `i' + 1
			if `i' < 20{
				local kwh_used `ev_miles_traveled`i'' * `kwh_per_mile'
			}
			local local_benefit_`s' = `local_benefit_`s'' + `r(local_enviro_ext)'
			local global_benefit_`s' = `global_benefit_`s'' + `r(global_enviro_ext)'

			local carbon_content_`s' = `carbon_content_`s'' + `r(carbon_content)'
		}
	}
	local ev_first_damages_g = (`ev_first_damages_g_CA'* `CA_pop_2011' + `ev_first_damages_g_MA' * `MA_pop_2011' + `ev_first_damages_g_PA' * `PA_pop_2011' + `ev_first_damages_g_TN' * `TN_pop_2011' + `ev_first_damages_g_TX' * `TX_pop_2011') / (`CA_pop_2011' + `MA_pop_2011' + `PA_pop_2011' + `TN_pop_2011' + `TX_pop_2011')
	local local_benefit = (`local_benefit_CA' * `CA_pop_2011' + `local_benefit_MA' * `MA_pop_2011' + `local_benefit_PA' * `PA_pop_2011' + `local_benefit_TN' * `TN_pop_2011' + `local_benefit_TX' * `TX_pop_2011') / (`CA_pop_2011' + `MA_pop_2011' + `PA_pop_2011' + `TN_pop_2011' + `TX_pop_2011')
	local global_benefit = (`global_benefit_CA' * `CA_pop_2011' + `global_benefit_MA' * `MA_pop_2011' + `global_benefit_PA' * `PA_pop_2011' + `global_benefit_TN' * `TN_pop_2011' + `global_benefit_TX' * `TX_pop_2011') / (`CA_pop_2011' + `MA_pop_2011' + `PA_pop_2011' + `TN_pop_2011' + `TX_pop_2011')
	local carbon_content = (`carbon_content_CA' * `CA_pop_2011' + `carbon_content_MA' * `MA_pop_2011' + `carbon_content_PA' * `PA_pop_2011' + `carbon_content_TN' * `TN_pop_2011' + `carbon_content_TX' * `TX_pop_2011') / (`CA_pop_2011' + `MA_pop_2011' + `PA_pop_2011' + `TN_pop_2011' + `TX_pop_2011')
	local q_carbon_yes_ev = -`beh_response' * `carbon_content'
	local q_carbon_yes_ev_mck = -`carbon_content'

	local total_bev_damages_glob = `global_benefit' // for Latex
	local total_bev_damages_glob_n = `total_bev_damages_glob' / `net_msrp' // for Latex
	local total_bev_damages_loc_n = -`local_benefit' / `net_msrp' // for Latex

	local wtp_yes_ev_local = -`beh_response' * `local_benefit'
	local wtp_yes_ev_global_tot = -`beh_response' * `global_benefit'
	local wtp_yes_ev_g = `wtp_yes_ev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	** need US-wide stuff for scaling cost curve outputs
	local us_wtp_yes_ev_local = -`beh_response' * ${yes_ev_damages_local_no_r_`dollar_year'}
	local us_wtp_yes_ev_global_tot = -`beh_response' * ${yes_ev_damages_global_no_r_`dollar_year'} 
	local us_wtp_yes_ev_g = `us_wtp_yes_ev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	local us_wtp_yes_ev = `us_wtp_yes_ev_local' + `us_wtp_yes_ev_g'
}


else{
	local kwh_used_year_one = `ev_miles_traveled1' * `kwh_per_mile' // for Latex
	local total_bev_damages_glob = ${yes_ev_damages_global_no_r_`dollar_year'} // for Latex
	local total_bev_damages_glob_n = `total_bev_damages_glob' / `net_msrp' // for Latex
	local total_bev_damages_loc_n = -${yes_ev_damages_local_no_r_`dollar_year'} / `net_msrp' // for Latex
	if "${latex}" == "yes"{
		local ev_first_damages_g = ${ev_first_damages_g_2020} // for Latex
	}

	local wtp_yes_ev_local = -`beh_response' * ${yes_ev_damages_local_no_r_`dollar_year'}
	local wtp_yes_ev_global_tot = -`beh_response' * ${yes_ev_damages_global_no_r_`dollar_year'}
	local wtp_yes_ev_g = `wtp_yes_ev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local q_carbon_yes_ev = -`beh_response' * ${yes_ev_carbon_content_`dollar_year'}
	local q_carbon_yes_ev_mck = -${yes_ev_carbon_content_`dollar_year'}
}

local yes_ev_local_ext = `wtp_yes_ev_local' / `beh_response'
local yes_ev_global_ext_tot = `wtp_yes_ev_global_tot' / `beh_response'

local wtp_yes_ev = `wtp_yes_ev_local' + `wtp_yes_ev_g'

local yes_ev_ext = `wtp_yes_ev' / `beh_response'

** Calculating the gallons used in the first year of a vehicle's lifetime for Latex
preserve
	
	if "`4'" == "baseline"{
		use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_car.dta", clear
		qui sum vmt_avg_car if age == 1
		local vmt_age_1 = `r(mean)'
	
		use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", clear
		forvalues y = 2011(1)2014{
			qui sum `bev_cf'_mpg if year == `y'
			local cf_mpg_`y' = `r(mean)'

			local gas_consumed_year_one_`y' = `vmt_age_1' / `cf_mpg_`y''
		}

		local gas_consumed_year_one = (`gas_consumed_year_one_2011' * `total_sales2011' + `gas_consumed_year_one_2012' * `total_sales2012' + `gas_consumed_year_one_2013' * `total_sales2013' + `gas_consumed_year_one_2014' * `total_sales2014') ///
									  / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')

	}

	else{
		use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_car.dta", clear
		qui sum vmt_avg_car if age == 1
		local vmt_age_1 = `r(mean)'

		use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", clear
		qui sum `bev_cf'_mpg if year == 2020
		local cf_mpg_2020 = `r(mean)'

		local gas_consumed_year_one = `vmt_age_1' / `cf_mpg_2020'
	}

restore

** Externality and WTP for driving an ICE vehicle

if "`4'" == "baseline"{
	local wtp_no_ice_local = `beh_response' * ((${`bev_cf'_cf_damages_loc_2011} * `total_sales2011' + ${`bev_cf'_cf_damages_loc_2012} * `total_sales2012' + ${`bev_cf'_cf_damages_loc_2013} * `total_sales2013' + ${`bev_cf'_cf_damages_loc_2014} * `total_sales2014') ///
												 / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014'))
	
	local wtp_no_ice_global_tot = `beh_response' * ((${`bev_cf'_cf_damages_glob_2011} * `total_sales2011' + ${`bev_cf'_cf_damages_glob_2012} * `total_sales2012' + ${`bev_cf'_cf_damages_glob_2013} * `total_sales2013' + ${`bev_cf'_cf_damages_glob_2014} * `total_sales2014') ///
												/ (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014'))
	local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local total_ice_damages_glob = `wtp_no_ice_global_tot' / `beh_response' // for Latex
	local total_ice_damages_glob_n = `total_ice_damages_glob' / `net_msrp' // for Latex
	local total_ice_damages_loc = `wtp_no_ice_local' / `beh_response' // for Latex
	local total_ice_damages_loc_n = `total_ice_damages_loc' / `net_msrp' // for Latex
	local total_damages_loc_n = `total_bev_damages_loc_n' + `total_ice_damages_loc_n' // for Latex


	local q_carbon_no_ice = `beh_response' * ((${`bev_cf'_cf_carbon_2011} * `total_sales2011' + ${`bev_cf'_cf_carbon_2012} * `total_sales2012' + ${`bev_cf'_cf_carbon_2013} * `total_sales2013' + ${`bev_cf'_cf_carbon_2014} * `total_sales2014') / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014'))
	local q_carbon_no_ice_mck = `q_carbon_no_ice' / `beh_response'


	** need US-wide stuff for scaling cost curve outputs
	local us_wtp_no_ice_local = `beh_response' * ${`bev_cf'_cf_damages_loc_`dollar_year'}
	local us_wtp_no_ice_global_tot = `beh_response' * ${`bev_cf'_cf_damages_glob_`dollar_year'} 
	local us_wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	local us_wtp_no_ice = `us_wtp_no_ice_local' + `us_wtp_no_ice_g'
}
else{
	local wtp_no_ice_local = `beh_response' * ${`bev_cf'_cf_damages_loc_`dollar_year'}
	local wtp_no_ice_global_tot = `beh_response' * ${`bev_cf'_cf_damages_glob_`dollar_year'}
	local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	local total_ice_damages_glob = `wtp_no_ice_global_tot' / `beh_response' // for Latex
	local total_ice_damages_glob_n = `total_ice_damages_glob' / `net_msrp' // for Latex
	local total_ice_damages_loc = `wtp_no_ice_local' / `beh_response' // for Latex
	local total_ice_damages_loc_n = `total_ice_damages_loc' / `net_msrp' // for Latex
	local total_damages_loc_n = `total_bev_damages_loc_n' + `total_ice_damages_loc_n' // for Latex

	local q_carbon_no_ice = `beh_response' * ${`bev_cf'_cf_carbon_`dollar_year'}
	local q_carbon_no_ice_mck = ${`bev_cf'_cf_carbon_`dollar_year'}
}

local no_ice_local_ext = `wtp_no_ice_local' / `beh_response'
local no_ice_global_ext_tot = `wtp_no_ice_global_tot' / `beh_response'

local wtp_no_ice = `wtp_no_ice_local' + `wtp_no_ice_g'

if "`4'" == "baseline"{
	local us_wtp_local = `us_wtp_yes_ev_local' + `us_wtp_no_ice_local'
	local us_wtp_g = `us_wtp_yes_ev_g' + `us_wtp_no_ice_g'
}

local no_ice_ext = `wtp_no_ice' / `beh_response'

*** Battery manufacturing emissions, 59.5 kg CO2eq/kWh for NMC111 batteries ***

* Averaging the SCC for 2011-2014
if "`4'" == "baseline"{
	local relevant_scc = (${sc_CO2_2011} * `total_sales2011' + ${sc_CO2_2012} * `total_sales2012' + ${sc_CO2_2013} * `total_sales2013' + ${sc_CO2_2014} * `total_sales2014') ///
									  / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
}
else{
	local relevant_scc = ${sc_CO2_`dollar_year'}
}

local batt_emissions = 59.5 * `batt_cap' // for Latex, 59.5 from Winjobi et al. (2022)

local batt_damages = `batt_emissions' * 0.001 * `relevant_scc' // unit conversion
local batt_damages_n = (`batt_emissions' * 0.001 * `relevant_scc') / `net_msrp'

local batt_man_ext = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

local batt_man_ext_tot = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc'

local wtp_soc = `wtp_yes_ev' + `wtp_no_ice' - `batt_man_ext'

local us_wtp_g = `us_wtp_g' - `batt_man_ext' // nothing location specific for battery emissiosn, so the externality is the same for the in-context estimate and the US-wide 2011-14 estimate 
local wtp_glob = `wtp_yes_ev_g' + `wtp_no_ice_g' - `batt_man_ext'
local wtp_loc = `wtp_yes_ev_local' + `wtp_no_ice_local'

if "`4'" == "baseline"{
	local us_wtp_soc = `us_wtp_yes_ev' + `us_wtp_no_ice'
}




if `want_rebound' == 1{
	** rebound effect
	rebound ${rebound}
	local rbd_coeff = `r(r)'
	local wtp_soc_rbd =  -(1 - `rbd_coeff') * `wtp_yes_ev'
	local wtp_soc_rbd_l = -(1 - `rbd_coeff') * `wtp_yes_ev_local'
	local wtp_soc_rbd_global_tot = -(1 - `rbd_coeff') * `wtp_yes_ev_global_tot'
	local wtp_soc_rbd_g = -(1 - `rbd_coeff') * `wtp_yes_ev_g'
	
	local q_carbon_rbd = -(1 - `rbd_coeff') * `q_carbon_yes_ev'
	local q_carbon_rbd_mck = -(1 - `rbd_coeff') * `q_carbon_yes_ev_mck'
	
    * Adding the rebound effect to the utility producer WTP
	local wtp_private = `wtp_private' - (1 - `rbd_coeff') * `wtp_prod_u'
	local wtp_prod_u = `rbd_coeff' * `wtp_prod_u' 

	* Adding the rebound effect to the utility fiscal externality
	local total_cost = `total_cost' + (1 - `rbd_coeff') * `utility_fisc_ext'
	local utility_fisc_ext =  `utility_fisc_ext' - (1 - `rbd_coeff') * `utility_fisc_ext' // rebound makes the utility fe smaller

	if "`4'" == "baseline"{
		local us_wtp_soc_rbd_l = -(1 - `rbd_coeff') * `us_wtp_yes_ev_local'
		local us_wtp_soc_rbd_g = -(1 - `rbd_coeff') * `us_wtp_yes_ev_g'
	}
    
}

local local_enviro_ext = (`wtp_no_ice_local' + `wtp_yes_ev_local') / `beh_response'
local global_enviro_ext_tot = (`wtp_no_ice_global_tot' + `wtp_yes_ev_global_tot') / `beh_response'


local enviro_ext = `wtp_soc' / `beh_response'
local enviro_ext_l = (`wtp_loc' + `wtp_soc_rbd_l') / `beh_response'
local enviro_ext_g = (`wtp_glob' + `wtp_soc_rbd_g') / `beh_response'

if "`4'" == "baseline"{
	local us_enviro_ext = `us_wtp_soc' / `beh_response'
	local us_enviro_ext_l = (`us_wtp_local' + `us_wtp_soc_rbd_l') / `beh_response'
	local us_enviro_ext_g = (`us_wtp_g' + `us_wtp_soc_rbd_g') / `beh_response'
}

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
	local lbd_cf = ("`bev_cf'" == "new_car")
	** --------------------- COST CURVE --------------------- **
	if "`4'" == "baseline"{

		cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
							   curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_local) ///
							   start_year(`dollar_year') scc(${scc_import_check}) new_car(`lbd_cf') vmt(${EV_VMT_car_adjustment})
		local dyn_enviro_local = `r(enviro_mvpf)' * (`enviro_ext_l' / `us_enviro_ext_l')
		di in red "dynamic enviro local is `dyn_enviro_local'"

		cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
							   curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_global) ///
							   start_year(`dollar_year') scc(${scc_import_check}) new_car(`lbd_cf') vmt(${EV_VMT_car_adjustment})
		local dyn_enviro_global_tot = `r(enviro_mvpf)' * (`enviro_ext_g' / `us_enviro_ext_g')
		local dyn_enviro_global = `dyn_enviro_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
		di in red "dynamic enviro global is `dyn_enviro_global'"
		
	}
	else{
		cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
							   curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_local) time_path_age(`lifetime') ///
							   scc(${scc_import_check}) new_car(`lbd_cf') vmt(${EV_VMT_car_adjustment}) ev_grid(${ev_grid})
		local dyn_enviro_local = `r(enviro_mvpf)'

		cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
							   curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_global) time_path_age(`lifetime') ///
							   scc(${scc_import_check}) new_car(`lbd_cf') vmt(${EV_VMT_car_adjustment}) ev_grid(${ev_grid})
		local dyn_enviro_global_tot = `r(enviro_mvpf)'
		local dyn_enviro_global = `dyn_enviro_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	}

	if `marg_mvpf' == 1{
		local dyn_price = `r(cost_mvpf)'
		local cost_wtp = `r(cost_mvpf)' * `program_cost'
		local env_cost_wtp = (`dyn_enviro_local' + `dyn_enviro_global') * `program_cost'
		local env_cost_wtp_l = `dyn_enviro_local' * `program_cost'
		local env_cost_wtp_global_tot = `dyn_enviro_global_tot' * `program_cost'
		local env_cost_wtp_g = `dyn_enviro_global' * `program_cost'
	}
	else if `non_marg_mvpf' == 1{
		local cost_wtp = (`r(cost_mvpf)' * `program_cost') / (1 + `beh_response')
		local env_cost_wtp = (`r(enviro_mvpf)' * `program_cost') / (1 + `beh_response')
	}
}

local q_carbon = `q_carbon_no_ice' + `q_carbon_yes_ev' + `q_carbon_rbd'
local q_carbon_no = `q_carbon'
local q_carbon_cost_curve = `dyn_enviro_global_tot' / ${sc_CO2_`dollar_year'}
local q_carbon_cost_curve_mck = `q_carbon_cost_curve' / `beh_response'
local q_carbon_mck = `q_carbon_no_ice_mck' + `q_carbon_yes_ev_mck' + `q_carbon_rbd_mck' 
local q_carbon = `q_carbon' + `q_carbon_cost_curve'


********** Long-Run Fiscal Externality **********

local fisc_ext_lr = -1 * (`wtp_no_ice_global_tot' + `wtp_yes_ev_global_tot' + `wtp_soc_rbd_global_tot' + `env_cost_wtp_global_tot' + `batt_man_ext_tot') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
local total_cost = `total_cost' + `fisc_ext_lr' + `gas_corp_fisc_e'

************************************************

if "${value_savings}" == "yes" & "`4'" == "current" {
	
	local wtp_savings = `beh_response' * (${`bev_cf'_cf_gas_savings_`dollar_year'} - ${yes_ev_savings_`dollar_year'}) 
	
}
else {
	
	local wtp_savings = 0
	
}

* Total WTP
local WTP = `wtp_private' + `wtp_soc' + `wtp_soc_rbd' + `wtp_savings' // not including learning-by-doing
local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp'

// Quick Decomposition

/* Assumptions:

	- wtp_private, cost_wtp -> US Present
	- wtp_soc, env_cost_wtp -> US Future & Rest of the World

*/

local WTP_USPres = `wtp_private' + `wtp_yes_ev_local' + `wtp_no_ice_local' + `env_cost_wtp_l' + `wtp_soc_rbd_l'
local WTP_USFut = (${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC})) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot')
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot') + `cost_wtp'

**************************
/* 8. MVPF Calculations */
**************************

local MVPF = `WTP_cc' / `total_cost'
local MVPF_no_cc = `WTP' / `total_cost'

****************************************
/* 9. Cost-Effectiveness Calculations */
****************************************
local avg_lcoe = ${energy_cost}
local energy_cost = `avg_lcoe'

local lifetime_energy_cost = 0
forvalues y = 1(1)`ub'{
	local lifetime_energy_cost = `lifetime_energy_cost' + (`ev_miles_traveled`y'' * `kwh_per_mile' * `energy_cost') / ((1 + `discount')^(`y' - 1))
}

di in red "lifetime energy cost is `lifetime_energy_cost'"

local purchase_price_diff = 8166 * (${cpi_2020} / ${cpi_2023}) // from Vincentric's 2024 Electric Vehicle Cost of Ownership Analysis
di in red "purchase price difference is `purchase_price_diff'"

local lifetime_gas_cost = ${clean_car_cf_gas_savings_2020} - ${clean_car_wtp_prod_s_2020} - 0.08 * ${clean_car_cf_gas_savings_2020} - ${clean_car_cf_gas_fisc_ext_2020} ////economy-wide 8% markup from De Loecker et al. (2020)

di in red "lifetime gas cost is `lifetime_gas_cost'"

local resource_cost = `purchase_price_diff' + `lifetime_energy_cost' - `lifetime_gas_cost'

di in red "resource cost is `resource_cost'"

local q_carbon_yes_ev_mck = -${yes_ev_carbon_content_2020} - (59.5 * `batt_cap' * 0.001) - ${yes_ev_rbd_CO2_2020} // need to remove the rebound effect, 59.5 from Winjobi et al. (2022), unit conversion
di in red "yes ev carbon is `q_carbon_yes_ev_mck'"
local q_carbon_no_ice_mck = ${clean_car_cf_carbon_2020}
di in red "no ice carbon is `q_carbon_no_ice_mck'"

local q_carbon_mck = `q_carbon_yes_ev_mck' + `q_carbon_no_ice_mck'
di in red "carbon is `q_carbon_mck'"

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `semie' * `q_carbon_mck' + (1 - `rbd_coeff') * `semie' * `q_carbon_mck'

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
global wtp_deal_`1' = 0
global wtp_prod_s_`1' = -`wtp_prod_s'
global wtp_prod_u_`1' = `wtp_prod_u'

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
global utility_fisc_ext_`1' = -`utility_fisc_ext'
global gas_fisc_ext_`1' = `gas_fisc_ext'
global beh_fisc_ext_`1' = `beh_fisc_ext'
global state_fisc_ext_`1' = 0
global fed_fisc_ext_`1' = `fed_fisc_ext'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global gas_corp_fisc_e_`1' = `gas_corp_fisc_e'
global `1'_`4'_ep = round(`epsilon', 0.001)

global profits_fisc_e_`1' = `gas_corp_fisc_e' - `utility_fisc_ext'

global wtp_soc_`1' = `wtp_soc'
global wtp_glob_`1' = `wtp_glob' 
global wtp_loc_`1'= `wtp_loc'

global wtp_no_ice_`1' = `wtp_no_ice'
global wtp_no_ice_local_`1' = `wtp_no_ice_local'
global wtp_no_ice_g_`1' = `wtp_no_ice_g'

global wtp_yes_ev_`1' = `wtp_yes_ev'
global wtp_yes_ev_local_`1' = `wtp_yes_ev_local'
global wtp_yes_ev_g_`1' = `wtp_yes_ev_g'

global wtp_soc_rbd_`1' = `wtp_soc_rbd'
global wtp_soc_rbd_l_`1' = `wtp_soc_rbd_l'
global wtp_soc_rbd_g_`1' = `wtp_soc_rbd_g'

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

global wtp_comps_`1' wtp_cons wtp_deal wtp_glob wtp_loc wtp_soc_rbd env_cost_wtp cost_wtp wtp_prod_s wtp_prod_u WTP_cc
global wtp_comps_`1'_commas "wtp_cons", "wtp_deal", "wtp_glob", "wtp_loc", "wtp_soc_rbd", "env_cost_wtp", "wtp_prod_s", "wtp_prod_u"
global wtp_comps_`1'_commas2 "cost_wtp", "WTP_cc"

global cost_comps_`1' program_cost beh_fisc_ext fed_fisc_ext gas_fisc_ext profits_fisc_e fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "beh_fisc_ext", "fed_fisc_ext", "gas_fisc_ext", "profits_fisc_e", "fisc_ext_lr", "total_cost"

global `1'_xlab 1 `"Consumers"' 2 `"Dealers"' 3 `""Global" "Env.""' 4 `""Local" "Env.""' 5 `"Rebound"' 6 `""Dynamic" "Env.""' 7 `""Dynamic" "Price""' 8 `""Gasoline" "Producers""' 9 `"Utilities"' 10 `"Total WTP"' 12 `""Program" "Cost""' 13 `""State" "Subsidy""' 14 `""Federal" "Subsidy""' 15 `""Gas" "Tax""' 16 `""Profits" "Tax""' 17 `""Climate" "FE""' 18 `""Govt" "Cost""' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 5
global color_group3_`1' = 7
global color_group4_`1' = 9
global cost_color_start_`1' = 12
global color_group5_`1' = 17

global `1'_name "State-level Battery Electric Vehicle Financial Incentives"



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


if "${latex}" == "yes"{
	if "`bev_cf'" == "clean_car" & ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs semie msrp net_msrp kwh_per_mile total_subsidy kwh_used_year_one total_bev_damages_glob ev_first_damages_g wtp_yes_ev_g wtp_no_ice_global_tot ///
					wtp_no_ice_g wtp_glob wtp_loc wtp_soc_rbd marg_sales cum_sales batt_frac fixed_cost_frac gas_consumed_year_one total_bev_damages_glob_n ///
					total_ice_damages_glob_n total_ice_damages_loc total_ice_damages_loc_n batt_per_kwh_cost batt_cap env_cost_wtp cost_wtp ///
					tot_gal gas_markup wtp_prod_s WTP_cc tot_kwh util_producer_surplus wtp_prod_u total_bev_damages_loc_n total_damages_loc_n ///
					avg_state_subsidy avg_fed_subsidy avg_state_subsidy_n avg_fed_subsidy_n fed_fisc_ext state_fisc_ext avg_subsidy beh_fisc_ext gas_fisc_ext tax_rate utility_fisc_ext util_gov_revenue fisc_ext_lr ///
					total_cost MVPF epsilon semie_paper EV_increase ep_avg_subsidy net_elas_msrp ev_cf_mpg avg_subsidy_n batt_emissions batt_damages_n batt_man_ext
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

			if inlist("`i'", "msrp", "net_msrp", "marg_sales", "cum_sales", "batt_per_kwh_cost", "tot_kwh", "gas_consumed_year_one", "avg_subsidy", "net_elas_msrp") | inlist("`i'", "tot_gal", "avg_state_subsidy") {
				local `original' = trim("`: display %8.0gc ``original'''")
			}
			else if inlist("`i'", "avg_fed_subsidy", "total_subsidy", "ep_avg_subsidy") {
				local `original' = trim("`: display %5.2fc ``original'''")
			}
			else if inlist("`i'", "semie"){
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

	if "`bev_cf'" == "new_car" & ${sc_CO2_2020} == 193{

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



	if "`bev_cf'" == "clean_car" & ${sc_CO2_2020} == 193{

		** Latex Output for cost per ton measures
		local outputs ev_price ice_price 
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/Cost per Ton Measures/macros_`1'_`4'_ce.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'_ce}" _n
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