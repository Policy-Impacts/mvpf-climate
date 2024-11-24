*************************************************************
/* Purpose: Calculate per-gallon externality from diesel-powered, light-duty vehicle. */
*************************************************************
local truck_types 						 mdv hdv  // Leave as is. Includes medium- and heavy-duty trucks.
local vmt_externalities 				 PM25_TBW accidents congestion road_damage // Handles weighting differently. 
local diesel_driving					 accidents congestion road_damage

global mdv_emissions_toggle				 "Heavy-duty"

global diesel_year_list 					 2006 2020
foreach yr of global diesel_year_list {

local dollar_year `yr'

preserve 
{
	* Assorted parameters 
	import excel "${policy_assumptions}", first clear sheet("driving_parameters")

	local fe_class car truck 
	foreach type of local fe_class {
	
		sum estimate if parameter == "diesel_mpg_diff_`type'"
			local diesel_mpg_diff_`type' = r(mean)
	
	}
	
	sum estimate if parameter == "diesel_ldv_vmt_diff"
		local diesel_ldv_vmt_diff = r(mean)
		
	sum estimate if parameter == "diesel_CO2_per_gallon"
		local diesel_CO2_content = r(mean)
		
	sum estimate if parameter == "diesel_congestion_diff"
		local diesel_congestion_diff = r(mean)
		
	sum estimate if parameter == "mec_road_damage"
		local mec_road_damage = r(mean)
		local mec_road_damage_dollar_year = 1997 // In 1997 dollars.
		
	sum estimate if parameter == "ppm_to_g_gal_diesel"
	global diesel_ppm_conversion = r(mean) 

		
	* Fuel Economy
	import excel "${policy_assumptions}", first clear sheet("fuel_economy_1975_2022")

	gen ModelYear_str = strlen(ModelYear)
		split ModelYear, parse()
		replace ModelYear = ModelYear2 if ModelYear_str>4
		destring ModelYear, replace
	keep ModelYear RealWorldMPG VehicleType
		keep if inlist(VehicleType, "All Car", "All Truck")
	
	rename ModelYear model_year
	rename RealWorldMPG mpg
	rename VehicleType vehicle_type_merge
	
	tempfile fuel_economy_diesel
		save "`fuel_economy_diesel.dta'", replace 
		
	sum model_year
		local year_min = r(min) // Used to coordinate across diesel vehicle types. 
		
		
	* Heavy-duty diesel emissions
	import excel "${policy_assumptions}", first clear sheet("diesel_emissions_hdv")
	tempfile diesel_emissions_hdv
		save "`diesel_emissions_hdv.dta'", replace
		
		
	* Sulfur content of diesel.
	import excel "${policy_assumptions}", first clear sheet("sulfur_content_diesel")
	
	ipolate sulfur_content_ppm year, gen(adj_sulfur_content_ppm)
	replace sulfur_content_ppm = adj_sulfur_content_ppm
		drop adj*
	
	qui sum sulfur_content_ppm if year == `dollar_year'
		local diesel_SO2_content = r(mean)
		
		
	* Composition of diesel fleet. 
	import excel "${policy_assumptions}", first clear sheet("diesel_fleet_composition")
	keep if fuel_type == "Diesel"
	cap replace sample_thousands = "0" if sample_thousands == "S"
		destring sample_thousands, replace
	
	collapse (sum) sample_thousands, by(type)
	egen total_diesel_fleet_size = total(sample_thousands)
		gen fleet_comp_share = sample_thousands / total_diesel_fleet_size
	keep type fleet_comp_share

	tempfile diesel_fleet_shares
		save "`diesel_fleet_shares.dta'", replace
	
}				
restore

*===============================================================================
* Step #1: Handle CH4 and N2O emissions from light-duty, diesel vehicles.
*===============================================================================
preserve

	*===============================================================================
	* Step #1a: Save production shares from U.S. EPA fuel economy data. 
	*===============================================================================
	import excel "${policy_assumptions}", clear first sheet("diesel_ldv_production")
	drop if inlist(VehicleType, "All", "All Car", "All Truck")

	replace PowertrainDiesel = "0" if PowertrainDiesel == "-"
		destring PowertrainDiesel, replace
	gen diesel_vehicles = Production000 * PowertrainDiesel

	bysort ModelYear : egen diesel_vehicles_total = total(diesel_vehicles)
	gen production_share = diesel_vehicles / diesel_vehicles_total
		
	gen vehicle_type_merge = ""
		replace vehicle_type_merge = "All Car" if inlist(VehicleType, "Car SUV", "Sedan/Wagon")
		replace vehicle_type_merge = VehicleType if VehicleType == "Truck SUV"
		replace vehicle_type_merge = "Light Truck" if inlist(VehicleType, "Minivan/Van", "Pickup")
	drop if vehicle_type_merge == ""
		
	collapse (sum) ProductionShare, by(ModelYear vehicle_type_merge)
	bysort ModelYear : egen production_share_check = total(ProductionShare)
	assert round(production_share_check, 0.1) == 1
		drop production_share_check
		
	rename ModelYear model_year 
	keep model_year vehicle_type_merge ProductionShare
	tempfile production_shares_diesel_ldv
		save "`production_shares_diesel_ldv.dta'", replace
		
	*===============================================================================
	* Step #1b: Import and clean additional emission factors from GREET (Argonne Nat'l. Lab) 
	*===============================================================================
	import excel "${policy_assumptions}", first clear sheet("GREET_data_ldv_diesel")
	merge 1:1 model_year vehicle_type_merge using "`production_shares_diesel_ldv.dta'", nogen assert(2 3)
		drop if model_year > `dollar_year'
	
	sum model_year if CH4 != .
		local year_last = r(min)
	
	ds CH4 N2O
	foreach var in `r(varlist)' {
		
		levelsof(vehicle_type_merge), local(vehicle_loop)
		foreach type of local vehicle_loop {
		
			qui sum `var' if model_year == `year_last' & vehicle_type_merge == "`type'"
			replace `var' = r(mean) if model_year < `year_last' & vehicle_type_merge == "`type'"
		}
	}
	sort vehicle_type_merge model_year
	
	bysort model_year : egen production_share_check = total(ProductionShare)
	assert round(production_share_check, 0.01) == 1
		drop production_share_check
		
	collapse (mean) CH4 N2O [aw=ProductionShare], by(model_year)
	gen type = "Light-duty"
	
	tempfile GREET_diesel_ldv_save
		save "`GREET_diesel_ldv_save.dta'", replace

restore

*===============================================================================
* Step #2: Handle medium- and heavy-duty diesel vehicle distributions and fuel economies.  
*===============================================================================
preserve 

foreach type of local truck_types {
	
	import excel "${policy_assumptions}", first clear sheet("diesel_`type'_fuel_econ")
	cap replace sample_thousands = "0" if sample_thousands == "S"
		destring sample_thousands, replace
	collapse (mean) avg_fuel_econ [aw=sample_thousands]
	
	assert _n == 1
	
	sum avg_fuel_econ
		local `type'_fuel_econ = r(mean)
		

	import excel "${policy_assumptions}", first clear sheet("diesel_`type'_dist")
	collapse (sum) sample_thousands vmt_millions , by(model_year)
	
	ds *_thousands 
	foreach var in `r(varlist)' { 
		
		replace `var' = `var' * 1000 
		
		local newname = substr("`var'", 1, strlen("`var'") - 10)
		rename `var' `newname'
		
	}
	
	ds *_millions
	foreach var in `r(varlist)' {
		
		replace `var' = `var' * 1000000
		
		local newname = substr("`var'", 1, strlen("`var'") - 9)
		rename `var' `newname'_total
		
	}

	gen avg_vmt = vmt_total / sample
		drop vmt_total 
	egen sample_total = total(sample)
		gen age_share = sample / sample_total
		drop sample*
				
	egen age_share_check = total(age_share)
		assert age_share_check == 1
		drop age_share_check	
	
	** Add observations for years earlier than 2012 (earliest year observed in VIUS).
	split model_year
	replace model_year = model_year1 if model_year2 != ""
		drop model_year1 model_year2 model_year3
	destring model_year, replace
	
	sum model_year 
	gen age = (r(max) - model_year) + 1
		qui sum age
			asser r(min) == 1
		
	sum age 
		local age_first = r(max) + 1
		local age_last =  (`dollar_year' - `year_min') + 5
			
	forval y = `age_first'(1)`age_last' {
		
		insobs 1, before(1)
		qui replace age = `y' if _n == 1
		
		qui sum avg_vmt if age == `age_first' - 1
			replace avg_vmt = r(mean) if _n == 1
		
	}
	sort age
		drop if age > `yr' - `year_min' + 1
			local above_age_max = `yr' - `year_min' + 1
	drop model_year
	
	qui sum age
		local age_last = r(max)
		
	local age_share_replace = (`age_last' - `age_first') + 2
	sum age_share if age == `age_first' - 1
	replace age_share = r(mean) / `age_share_replace' if inrange(age, `age_first' - 1, `age_last')
		egen age_share_check = total(age_share)
		assert age_share_check == 1
		drop age_share_check
					
	** Calculate age of vehicle using model year; used to merge with emissions data. 	
	keep age age_share avg_vmt 
	gen type = ""'
	
	if "`type'" == "mdv" {
		replace type = "Medium-duty"
	}
	if "`type'" == "hdv" {
		replace type = "Heavy-duty"
	}
					
	gen mpg_diesel = ``type'_fuel_econ'
	
	tempfile `type'_append
		save "``type'_append.dta'", replace
}

append using "`mdv_append.dta'"
	order age
	sort age
	
tempfile mdv_hdv_combined
	save "`mdv_hdv_combined.dta'", replace
			
restore

*===============================================================================
* Step #3: Calculate split between diesel-powered, light-duty cars and trucks.  
*===============================================================================
preserve

	import excel "${policy_assumptions}", clear first sheet("diesel_ldv_production")
	keep if inlist(VehicleType, "All Car", "All Truck")
	
	replace PowertrainDiesel = "0" if PowertrainDiesel == "-"
		destring PowertrainDiesel, replace
	gen diesel_vehicles = Production000 * PowertrainDiesel
	
	bysort ModelYear : egen diesel_vehicles_total = total(diesel_vehicles)
	gen production_share = diesel_vehicles / diesel_vehicles_total
	
	rename ModelYear model_year
	rename VehicleType vehicle_type_merge 
		keep model_year vehicle_type_merge production_share
		
	tempfile diesel_production
		save "`diesel_production.dta'", replace
				
restore
		
*===============================================================================
* Step #4: Merge datasets and calculate % differences b/w gas and diesel.
*===============================================================================
preserve 

	import excel "${policy_assumptions}", clear first sheet("diesel_emissions_ldv")
	
	* Data on differences only go to 2000. Assume % difference for all model years pre-2000 = 2000.
	forval y = 1975(1)1999 {

		levelsof(pollutant), local(pollutant_loop) 
		foreach p of local pollutant_loop {
			
			levelsof(vehicle_type_merge), local(vehicle_loop)
			foreach v of local vehicle_loop {
				
				insobs 1, before(1)
				
				replace model_year = `y' if _n == 1
				replace pollutant = "`p'" if _n == 1 
				replace vehicle_type_merge = "`v'" if _n == 1
 				
			}
			
		}
	
	}
	
	gen percent_diff_diesel = (emission_rate_diesel - emission_rate_gas)/emission_rate_gas
	// Diesel vehicle is X% more/less polluting than a gasoline vehicle of the same model year and type. 
		
	merge m:1 model_year vehicle_type_merge using "`diesel_production.dta'", keep(2 3) nogen 
	merge m:1 model_year vehicle_type_merge using "`fuel_economy_diesel.dta'", keep(2 3) nogen

	foreach p of local pollutant_loop {
		
		foreach v of local vehicle_loop {
			
			sum percent_diff_diesel if model_year == 2000 & vehicle_type_merge == "`v'" & pollutant == "`p'"
			replace percent_diff_diesel = r(mean) if model_year < 2000 & vehicle_type_merge == "`v'" & pollutant == "`p'"
			
		}
		
	}
		
	* Production data for 1993 and 1994 missing. Assume production shares same as in 1993.
	sum model_year if production_share == .
		local min_observed = r(min) - 1

	foreach p of local pollutant_loop {
		
		foreach v of local vehicle_loop {
			
			sum production_share if model_year == `min_observed' & vehicle_type_merge == "`v'" & pollutant == "`p'"
			replace production_share = r(mean) if production_share == . & vehicle_type_merge == "`v'" & pollutant == "`p'"
			
		}
		
	}		
			
*===============================================================================
* Step #5: Handle fuel economy of diesel vehicles. 
*===============================================================================

* Fuel economies are average light-duty vehicle; diesel vehicles of the same model and class are more fuel efficient. 
replace mpg = mpg * (1 + `diesel_mpg_diff_car') if vehicle_type_merge == "All Car" 
replace mpg = mpg * (1 + `diesel_mpg_diff_truck') if vehicle_type_merge == "All Truck" 

collapse (mean) mpg percent_diff_diesel emission* [aw=production_share] , by(model_year pollutant)

	tempfile collapsed_diesel_ldv
	save "`collapsed_diesel_ldv.dta'", replace
	
restore

*===============================================================================
* Step #6: (Interlude) Calculate % difference b/w heavy-duty diesel and light-duty gasoline.
*===============================================================================
preserve

use "`collapsed_diesel_ldv.dta'", clear
keep model_year pollutant emission_rate_gas
	drop if emission_rate_gas == . // Production-weighted average gas LDV emission rate from MOVES.
	
merge 1:1 model_year pollutant using "`diesel_emissions_hdv.dta'", assert(3) nogen

gen percent_diff_diesel = (emission_rate_diesel - emission_rate_gas)/emission_rate_gas
keep model_year pollutant percent*
reshape wide percent_diff_diesel, i(model_year) j(pollutant) str

ds percent*
foreach var in `r(varlist)' {
	
	local rename = substr("`var'", 20, .)	
	rename `var' pd_`rename'
	
}
gen type = "Heavy-duty"

drop if model_year >  `dollar_year'

tempfile hdv_emissions_diff
	save "`hdv_emissions_diff.dta'", replace

restore

*===============================================================================
* Step #7: Bring in adjusted emission rates from Jacobsen et al. 2023 (used in gas tax MVPFs).
*===============================================================================
preserve

use "`collapsed_diesel_ldv.dta'", clear
drop emission*

reshape wide mpg percent_diff_diesel, i(model_year) j(pollutant) str
	keep model_year percent* mpgCO
	rename mpgCO mpg_diesel
	
ds percent*
foreach var in `r(varlist)' {
	
	local rename = substr("`var'", 20, .)	
	rename `var' pd_`rename'
	
}
	
merge 1:1 model_year using "${assumptions}/diesel_vehicles/diesel_emission_rates_`dollar_year'", nogen
	drop if model_year < 1975
	drop if model_year > `dollar_year'
	// Emission rates already have decay factors applied. 
	drop *weights mpg age_share
	
* Apply percent difference to gasoline-powered vehicle emission rates. 
ds PM25* 
foreach var in `r(varlist)' { 
	
	rename `var' `var'_mi
	
}

ds *_mi	
foreach var in `r(varlist)' {
	
	rename `var' `var'_gas
	
}

local pollution_adj HC CO NOx PM25_exhaust PM25_TBW
foreach p of local pollution_adj { 
	
	gen `p'_mi_diesel = `p'_mi_gas * (1 + pd_`p')
	
}

levelsof(model_year), local(model_loop)
foreach m of local model_loop {
	
	foreach p of local pollution_adj {
		
		assert `p'_mi_diesel > 0 if model_year == `m'
		
	}
	
}
drop pd* // Will import percent differences for heavy-duty vehicles next.

*===============================================================================
* Step #8: Adjust age and VMT distributions for light-duty, diesel-powered vehicles. 
*===============================================================================
rename fleet_avg_vmt avg_vmt

* Diesel vehicles drive slightly more on average; account for difference. Assume age distriubtion is the same. 
replace avg_vmt = avg_vmt * (1 + `diesel_ldv_vmt_diff')

merge 1:1 age using "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", nogen noreport

qui sum age
	if r(max) > `above_age_max' {
		
		assert `yr' == 2006 // Should only have this issue with in-context calculation.
		qui sum age_share if age > `above_age_max'
			replace age_share = age_share + (r(mean)/3) if inrange(age, 30, 32)
				drop if age > `above_age_max'
	}
		
	qui sum age
		local age_max = r(max)
	qui sum age if age_share != .
		local age_min = r(max)
		
	qui sum fleet_avg_vmt if age == `age_min'
		local vmt_replace = r(mean)
		replace fleet_avg_vmt = `vmt_replace' if inrange(age, `age_min', `age_max')
					
	qui sum age_share if age == `age_min'
		local age_remainder = r(mean)
		local age_count = `age_max' - `age_min' + 1
		
	replace age_share = `age_remainder'/`age_count' if inrange(age, `age_min', `age_max')
		
	cap egen age_check = total(age_share)
		assert age_check == 1
	drop age_check 
	
	
gen type = "Light-duty"
	order age type

	
*===============================================================================
* Step #9: Combine light-, medium-, and heavy-duty data. Handle emissions from medium- and heavy-duty. 
*===============================================================================
append using "`mdv_hdv_combined.dta'"
	qui sum age if type == "Light-duty"
		drop if age > r(max) & type != "Light-duty"
	bysort age : egen obs_check = count(age)
		assert obs_check == 3
			drop obs_check					
			
levelsof(age), local(age_loop)
foreach a of local age_loop {
	
	sum model_year if age == `a'
	replace model_year = r(mean) if age == `a' & model_year == .
	
}

assert  (`dollar_year' - model_year + 1) == age		
		
* Heavy-duty vehicle emissions. 
merge 1:1 model_year type using "`hdv_emissions_diff.dta'", nogen

foreach p of local pollution_adj {
	
	sum model_year if type == "Heavy-duty" & pd_`p' != .
		local year_min = r(min)
	
	sum pd_`p' if type == "Heavy-duty" & model_year == `year_min'
	replace pd_`p' = r(mean) if type == "Heavy-duty" & model_year < `year_min'
	
}
sort type model_year

foreach a of local age_loop {
	
	foreach p of local pollution_adj {
		
		
		qui sum `p'_mi_gas if age == `a' & type == "Light-duty" 
		replace `p'_mi_diesel = r(mean) * (1+pd_`p') if type == "Heavy-duty" & age == `a'
		
	}
	
}
drop pd* *_gas

* Determine how to handle medium-duty vehicles (toggle-dependent).
foreach p of local pollution_adj {
	
	assert type == "Medium-duty" if `p'_mi_diesel == .
	
}

foreach a of local age_loop {
	
	foreach p of local pollution_adj {
		
		qui sum `p'_mi_diesel if age == `a' & type == "${mdv_emissions_toggle}" 
		replace `p'_mi_diesel = r(mean) if type == "Medium-duty" & age == `a' & `p'_mi_diesel == .
		
	}
	
}
sort age

foreach a of local age_loop {
	
	foreach p of local pollution_adj {
		
		qui sum `p'_mi_diesel if age == `a' & type == "${mdv_emissions_toggle}" 
		assert r(mean) == `p'_mi_diesel if age == `a' & type == "Medium-duty" 
	
	}
}

ds *_diesel
foreach var in `r(varlist)' {
	
	local newname = substr("`var'", 1, strlen("`var'") - 7)
	rename `var' `newname'
	
}
sort age type, stable

tempfile diesel_fleet_save
	save "`diesel_fleet_save.dta'", replace
		
restore

*===============================================================================
* Step #10: Incorporate remaining pollutants (CO2, SO2, CH4, N2O) 
*===============================================================================
preserve

* For CH4 and N2O, do not need to worry about percent differences b/c gas emissions come from same dataset. 
import excel "${policy_assumptions}", first clear sheet("GREET_data_hdv")
	gen type = "Heavy-duty"
append using "`GREET_diesel_ldv_save.dta'"

merge 1:1 model_year type using "`diesel_fleet_save.dta'"
	sort type model_year
drop if model_year >  `dollar_year'	

* Heavy-duty missing pre-1990 data. 
qui sum model_year if CH4 != . & type == "Heavy-duty"
	local year_min = r(min)

ds CH4 N2O
foreach var in `r(varlist)' {
	
	sum `var' if type == "Heavy-duty" & model_year == `year_min'
		replace `var' = r(mean) if type == "Heavy-duty" & model_year < `year_min' & `var' == .
	
}

* Determine how to handle N2O and CH4 for medium-duty vehicles (toggle-dependent). 
ds CH4 N2O
foreach var in `r(varlist)' {

	foreach a of local age_loop {

		qui sum `var' if age == `a' & type == "${mdv_emissions_toggle}" 
		replace `var' = r(mean) if type == "Medium-duty" & age == `a' & `var' == .
		
	}
	
	rename `var' `var'_mi
	
}
sort age

* Convert all pollutants added thus far to per-gallon emission rates.
rename PM25_TBW_mi PM25_TBW // Handled differently.
ds *_mi
foreach var in `r(varlist)' {
	
	local newname = substr("`var'", 1, strlen("`var'") - 3)
	gen `newname'_gal = `var' * mpg
	
	drop `var'
}

* Incorporate CO2 and SO2 emissions from consuming a gallon of diesel. 
gen CO2_gal = `diesel_CO2_content'
gen SO2_gal = `diesel_SO2_content' * ${diesel_ppm_conversion}

*===============================================================================
* Step #11: Accidents, congestion, and road damage. 
*===============================================================================

gen accidents = .
	replace accidents = (${accidents_per_mi}*(${cpi_`dollar_year'}/${cpi_2020})) * mpg // Assuming same for all. 
	
gen congestion = . 
	replace congestion = (${congestion_per_mi}*(${cpi_`dollar_year'}/${cpi_2020})) * mpg if type == "Light-duty"
	replace congestion = (${congestion_per_mi}*(${cpi_`dollar_year'}/${cpi_2020})) * (1+`diesel_congestion_diff') * mpg if type == "Heavy-duty"
	
	if "${mdv_emissions_toggle}" == "Heavy-duty" {
		
		replace congestion = (${congestion_per_mi}*(${cpi_`dollar_year'}/${cpi_2020})) * (1+`diesel_congestion_diff') * mpg if type == "Medium-duty"
		
	}
	if "${mdv_emissions_toggle}" == "Light-duty" {
		
		replace congestion = (${congestion_per_mi}*(${cpi_`dollar_year'}/${cpi_2020})) * mpg if type == "Medium-duty"
		
	}
	
gen road_damage = . 	
	replace road_damage = 0 if type == "Light-duty"
	replace road_damage = (`mec_road_damage'*(${cpi_`dollar_year'}/${cpi_`mec_road_damage_dollar_year'})) * mpg if type == "Heavy-duty"
	
	if "${mdv_emissions_toggle}" == "Heavy-duty" {
		
		replace road_damage = (`mec_road_damage'*(${cpi_`dollar_year'}/${cpi_`mec_road_damage_dollar_year'})) * mpg if type == "Medium-duty"
		
	}
	if "${mdv_emissions_toggle}" == "Light-duty" {
		
		replace road_damage = 0 if type == "Medium-duty"
		
	}

*===============================================================================
* Step #12: Construct weights and perform collapses. 
*===============================================================================
merge m:1 type using "`diesel_fleet_shares.dta'", assert(3) nogen

gen vmt_externality_weights = avg_vmt * age_share * fleet_comp_share
gen gallons_weights = (avg_vmt/mpg) * age_share * fleet_comp_share

drop avg_vmt age_share fleet_comp_share

tempfile diesel_pre_collapse
	save "`diesel_pre_collapse.dta'", replace
	
restore

	*===============================================================================
	* Step #12a: Fleet Composition Weights (gallons_weights)
	*===============================================================================
	preserve
	
		use "`diesel_pre_collapse'", clear
			drop `vmt_externalities' vmt_externality_weights
		collapse (mean) *_gal [aw=gallons_weights]
		gen fleet_year =  `dollar_year'
		
		tempfile gallon_externalities_save 
			save "`gallon_externalities_save.dta'", replace
			
	restore
	
	*===============================================================================
	* Step #12b: VMT Weights (vmt_externality_weights)
	*===============================================================================
	preserve
	
		use "`diesel_pre_collapse'", clear
			drop *_gal gallons_weights
		collapse (mean) `vmt_externalities' mpg  [aw=vmt_externality_weights]
		gen fleet_year =  `dollar_year'
		rename mpg fleet_mpg
		
		gen PM25_TBW_gal = PM25_TBW * fleet_mpg
			drop PM25_TBW
		
		merge 1:1 fleet_year using "`gallon_externalities_save.dta'", nogen assert(3)
		rename HC_gal VOC_gal
		order fleet_year fleet_mpg
		
		// NOTE: Accidents, congestion, and road damage have been valued already. Pollution has not--still in g/gal.

*===============================================================================
* Step #13: Value On-Road Pollution Damages
*===============================================================================	

* Import Social Costs.
local ghg CO2 CH4 N2O
foreach g of local ghg {
	
	local social_cost_`g' = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
		
}	

local md_w SO2 PM25 NOx VOC CO
foreach p of local md_w {
	
	local social_cost_`p' = ${md_`p'_`dollar_year'_weighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
	
}


local md_u SO2 PM25 NOx VOC NH3 CO
foreach p of local md_u  {
	
	local social_cost_`p'_uw = ${md_`p'_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
	
}
	

* Pollution Externalities: Social Cost * Emissions per Gallon
ds *_gal
foreach var in `r(varlist)' {
	
	local `var' = `var' / 1000000 // Grams to metric tons.
	
}

foreach val of global pollutants_list {
	
	if "`val'" == "VOC"| "`val'" == "CO" | "`val'" == "PM25_TBW" | "`val'" == "PM25_exhaust" {
		if "`val'" == "VOC" | "`val'" == "CO" {
			local wtp_`val'_local = -``val'_gal'*`social_cost_`val''
			local wtp_`val'_global = -``val'_gal'*(${`val'_gwp}*`social_cost_CO2')
				local wtp_`val' = `wtp_`val'_local' + `wtp_`val'_global'				
		}
		
		if "`val'" == "PM25_TBW" | "`val'" == "PM25_exhaust" {
			local check_PM25 = substr("`val'", 1, 4)
			local wtp_`val' = -``val'_gal' * `social_cost_`check_PM25''
		}
		
	}
	
	else {
		local wtp_`val' = -`social_cost_`val'' * ``val'_gal' 				
	}
			
} 

ds accidents congestion road_damage
foreach var in `r(varlist)' {
	
	local wtp_`var' = `var'
	
}

local fleet_mpg = fleet_mpg

	
restore 	

*===============================================================================
* Step #14: Collect WTPs.
*===============================================================================	
preserve

	clear
	insobs 1

	gen year = `dollar_year'	
	
	gen mpg = `fleet_mpg'
	
	foreach p of global pollutants_list {
		
		if "`p'" == "PM25_TBW" {
			
			gen wtp_`p' = `wtp_`p'' * -1
			
		}
		
		else {
			
			gen wtp_`p' = `wtp_`p'' * -1
			
		}
		
	}
	
	foreach e of local diesel_driving {
		
		gen wtp_`e' = `wtp_`e''
		
	}

	gen local_VOC = -`wtp_VOC_local'
	gen global_VOC = -`wtp_VOC_global'
		assert round(local_VOC + global_VOC, 0.01) == round(wtp_VOC, 0.01)
	
	gen local_CO = -`wtp_CO_local'
	gen global_CO = -`wtp_CO_global'
		assert round(local_CO + global_CO, 0.01) == round(wtp_CO, 0.01)
	
	tempfile data_`dollar_year'_save
		save "`data_`dollar_year'_save.dta'", replace
		
restore 

}		

clear
foreach yr of global diesel_year_list {

	append using "`data_`yr'_save.dta'"

}

levelsof(year), local(year_loop)
foreach y of local year_loop {
	
	qui sum wtp_CO2 if year == `y'
		local CO2_`y'_check = r(mean)
	
}

merge 1:1 year using "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", keep(3) nogen noreport
	
levelsof(year), local(year_loop)
foreach y of local year_loop {
	
	assert round(wtp_CO2, 0.0001) == round(`CO2_`y'_check', 0.0001) if year == `y' // Checking merge did not overwrite existing variables w/ same names.
	
}	

*===============================================================================
* Step #15: Calculate Totals.
*===============================================================================	
ds wtp*
	egen wtp_total = rowtotal(`r(varlist)')

global damages_local_diesel 	${damages_local} road_damage
gen wtp_local = 0
foreach val of global damages_local_diesel {
				
	if "`val'" == "NOx" | "`val'" == "SO2" {
			
		replace wtp_local = wtp_local + wtp_`val' + wtp_upstream_`val'
			
	}
		
	if "`val'" == "PM25" {
			
		replace wtp_local =	wtp_local + wtp_upstream_`val' + wtp_`val'_exhaust + wtp_`val'_TBW
			
	}
		
	if "`val'" == "NH3" {
			
		replace wtp_local =	wtp_local + wtp_upstream_`val' 
			
	}
		
	if "`val'" == "local_VOC"| "`val'" == "local_CO" {
			
		replace wtp_local =	wtp_local + `val' + `val'_upstream
			
	}

	if "`val'" == "accidents" | "`val'" == "congestion" | "`val'" == "road_damage" {
			
		replace wtp_local = wtp_local + wtp_`val'
			
	}	
}

gen wtp_global = 0 
foreach val of global damages_global {
		
	if !inlist("`val'", "global_VOC", "global_CO") {
			
		replace wtp_global = wtp_global + wtp_`val' + wtp_upstream_`val'
			
	}
	else {
			
		replace wtp_global = wtp_global + `val' + `val'_upstream
			
	}
}

assert round(wtp_total, 0.1) == round(wtp_local + wtp_global, 0.1)

gen CO2_total = wtp_CO2 + wtp_upstream_CO2 

qui levelsof(year), local(year_loop)
foreach y of local year_loop {
	
	replace CO2_total = CO2_total / (${sc_CO2_`y'} * (${cpi_`y'} / ${cpi_${sc_dollar_year}})) if year == `y'

		
}

*===============================================================================
* Step #16: Save Globals and Final Dataset.
*===============================================================================	

save "${user_specific_assumptions}/files_v${user_name}/Diesel Externalities/diesel_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", replace 

gen local_driving = wtp_accidents + wtp_congestion + wtp_road_damage