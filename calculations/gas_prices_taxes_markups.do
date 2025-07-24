*===============================================================================
* Purpose: Generate gas tax datasets. 
*===============================================================================
preserve

local avg_profits = 0.08 // Economy-wide average markup (%).
global gas_vehicle_files "${assumptions}/gas_vehicles"	
global gas_price_data "${gas_vehicle_files}/gas_price_data"
* Step #0: Pull refining cost assumption. 
import excel "${policy_assumptions}", first clear sheet("driving_parameters")
qui sum estimate if parameter == "refiner_var_cost"
	global refiner_var_cost = r(mean)

gen dollar_year_num = ""
	replace dollar_year_num = substr(dollar_year, 1, 4) if strlen(dollar_year) > 3
	destring dollar_year_num, replace
qui sum dollar_year_num if parameter == "refiner_var_cost"
	global refiner_var_cost_dollar_year = r(mean)

* Step #1: Save data as tempfiles for later merges.

	* Gas prices, consumption, and tax rates. 
	import excel "${policy_assumptions}", first clear sheet("gas_consumption")		
		tempfile gas_consumption
		save "`gas_consumption.dta'", replace
		
	import excel "${policy_assumptions}", first clear sheet("gas_data_early")
		tempfile gas_data_early
		save "`gas_data_early.dta'", replace
		
	import excel "${policy_assumptions}", first clear sheet("gas_tax_rates_state")
		tempfile gas_tax_rates_state
		save "`gas_tax_rates_state.dta'", replace
		
	import excel "${policy_assumptions}", first clear sheet("gas_tax_rates_federal")
		tempfile gas_tax_rates_federal
		save "`gas_tax_rates_federal.dta'", replace

	* Inflation adjustments. 
	import excel "${policy_assumptions}", first clear sheet("cpi_index")
		gen year = year(FREDYear)
			drop FREDYear
		tempfile cpi_index
		save "`cpi_index.dta'", replace

	* Crude oil markups and refinery production. 
	import excel "${policy_assumptions}", first clear sheet("crude_markup")
		gen month = month(date)
		gen year = year(date)
			replace date = mdy(month,1,year)
			drop month year 
		tempfile crude_markup
		save "`crude_markup.dta'", replace
		
	import excel "${policy_assumptions}", first clear sheet("refining_production")
		gen month = month(date)
		gen year = year(date)
			replace date = mdy(month,1,year)
			drop month year 
		tempfile refining_production
		save "`refining_production.dta'", replace
		
	* Aviation gasoline quantity consumed (for market sizing exercise).
	import excel "${policy_assumptions}", first clear sheet("aviation_prices")
	tempfile avgas
		save "`avgas.dta'", replace
		
	* WTI Spot Prices (for Crude Taxes).
	import excel "${policy_assumptions}", first clear sheet("crude_spot_price")
	tempfile wti_prices
		save "`wti_prices'", replace
		
	
* Step #2: Merge datasets. 
import excel "${policy_assumptions}", first clear sheet("gas_prices")
	gen year = year(date)
	bysort year: egen year_count = count(year)
	drop if year_count < 12
	drop year*

merge 1:m date using "`gas_consumption.dta'"
	sort date
	
	gen year = year(date)
	bysort year: egen year_count = count(year)
	drop if year_count < 12
	drop _merge year_count
	
merge m:1 year using "`gas_data_early.dta'", nogen

	* Splice data to have same mean in 1994, year of overlap.
	qui sum gas_price [aw=gas_consumption] if year == 1994
		local splice_late = r(mean)
		
	qui sum gas_price_early [aw=gas_consumption] if year == 1994
		local splice_early = r(mean)

	replace gas_price = ///
		gas_price_early + (`splice_late' - `splice_early') if year < 1994
		
	drop gas_price_early
	
merge 1:1 date using "`gas_tax_rates_federal.dta'", nogen
merge m:1 year using "`gas_tax_rates_state.dta'"
	qui sum year if _merge == 1
	qui sum avg_state_rate if year == r(mean) - 1
		replace avg_state_rate = r(mean) if _merge == 1
		drop _merge
order year date

merge m:1 year using "`cpi_index'", keep(3) nogen

replace avg_state_rate = avg_state_rate/100
replace federal_rate = federal_rate/100
ds *_rate
	egen avg_tax_rate = rowtotal(`r(varlist)')
drop avg_state_rate federal_rate


* Step #3: Incorporate markup data to calculate producer surplus. 
merge 1:1 date using "`crude_markup.dta'", keep(1 3) nogen
merge 1:1 date using "`refining_production.dta'", keep(1 3) nogen

	* Calculate markup for crude oil producers. 	
	gen refinery_yield = (monthly_net_output_total / monthly_net_input_total) * 42
	qui sum refinery_yield [aw=monthly_net_input_total] if refinery_yield != .
		replace refinery_yield = r(mean) if refinery_yield == .
		
	gen crude_markup = (refiner_crude_cost - crude_landed_cost) / refinery_yield
		replace crude_markup = 0 if crude_markup < 0 | crude_markup == .
	gen crude_markup_pct = crude_markup / gas_price
	
	* Calculate markup for refiners. 
	gen refining_markup_pct = .177 - (((${refiner_var_cost} * (index/${cpi_${refiner_var_cost_dollar_year}})) / refinery_yield) / gas_price)
		gen refining_markup = refining_markup_pct * gas_price
		
	* Calculate markup for gasoline retailers. 
	gen retail_markup_pct = (gas_price - dtw_price)/gas_price
	qui sum year if retail_markup_pct != .
		local retail_year_min = r(min)
	sum retail_markup_pct if year == `retail_year_min' [aw=monthly_net_input_total]
	replace retail_markup_pct = r(mean) if year < `retail_year_min'
	
	sum retail_markup_pct if year == 2021 [aw=monthly_net_input_total] // Data series ended in 2021.
		replace retail_markup_pct = r(mean) if year > 2021
		
	gen retail_markup = retail_markup_pct * gas_price
		replace retail_markup = 0 if retail_markup < 0
	
	** TOTAL MARKUP PER GALLON
	gen markup = crude_markup + refining_markup + retail_markup
	assert markup < gas_price
			
	gen pct_markup = markup / gas_price
	gen pct_check = crude_markup_pct + refining_markup_pct + retail_markup_pct
		drop pct_check
		
	replace pct_markup = pct_markup - `avg_profits'
		assert pct_markup > 0
	replace markup = gas_price * pct_markup
	
* Step #4: Save datasets in various formats for use in MVPF calculations. 

	* Save monthly dataset.
	gen month = month(date)
		save "${gas_price_data}/gas_data_monthly", replace 

	
	* Save annual dataset.
	bysort year : egen weight_annual = total(gas_consumption)
	collapse (mean) gas_price weight_annual *_rate index markup pct_markup crude_landed_cost refiner_crude_cost refining*  refinery* crude_markup* dtw_price retail* [aw=gas_consumption], by(year)
		rename weight_annual gas_consumption
	
	merge 1:1 year using "`avgas.dta'", keep(1 3) nogen
		drop jet_fuel*
	
	gen total_gal_finished_motor = gas_consumption * 42 * 1000 // Now thousands of gallons total.	
	gen total_gal_av_gas = aviation_gas_quantity * 42 * 1000 // Now thousands of gallons total.	
		gen total_gasoline_consumed = total_gal_finished_motor + total_gal_av_gas
		// Using EIA's definition of gasoline products. 
			gen gas_consumed_ldv = 0.91 * total_gasoline_consumed

	assert markup < (gas_price - avg_tax_rate)
	
	* Merge WTI Crude Spot Price Dataset (for Crude Taxes).
	merge 1:1 year using "`wti_prices'", nogen noreport keep(1 3)
	
		save "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", replace 

restore

* Step #5: Save tax rates as their own dataset. 
preserve 
	use "${gas_price_data}/gas_data_monthly", replace  
	keep year date *rate
	save "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_tax_rates", replace 
restore 