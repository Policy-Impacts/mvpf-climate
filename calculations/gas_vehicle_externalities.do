*************************************************************
/* Purpose: Calculate per-gallon externality from gasoline-powered, light-duty vehicle. */
*************************************************************

*************************************************
/* 1. Define Locals and Globals; Set Toggles. */
*************************************************

*************************************************
/* 1a. Set File Paths. */
*************************************************
global gas_vehicle_files "${assumptions}/gas_vehicles"
	
global gas_price_data "${gas_vehicle_files}/gas_price_data"
	
global gas_refinery_data "${gas_vehicle_files}/refinery_data"
	
global gas_fleet_emissions "${gas_vehicle_files}/fleet_emissions"	
	
global assumptions_model_year "${gas_fleet_emissions}/model_year"	
	
*************************************************
/* 1b. Define Local Lists [Do NOT change]. */
*************************************************
	
global upstream 												         CO2 CH4 N2O CO NH3 NOx PM25 SO2 VOC
// All pollutants that have an upstream component.
	  
global driving_list 										           		      		accidents congestion 
// Driving externalities from light-duty vehicles (road damage is diesel-specific).
	
	global pollutants_list 				        	        SO2 CO2 CO VOC PM25_exhaust PM25_TBW NOx CH4 N2O
	// All pollutants that have an on-road component. 		
	
	global damages_local 								 NH3 local_VOC local_CO NOx PM25 SO2 ${driving_list}
	global damages_global 													CO2 CH4 global_CO N2O global_VOC
	
*************************************************
/* 1c. Define and Set Toggles [Can Change]. */
*************************************************
global yield_toggle     "total"
// Set to: "total" or "motor." Governs how we allocate pollution from upstream production process.
// Default: "total"
// "motor" assumes that all refinery emissions come from producing gasoline
	
global fleet_composition     			upstream_total SO2 CO2 CO VOC NOx PM25_exhaust CH4 N2O // Can include the previously defined lists, or specific pollutants. 
	
global vehicle_miles_traveled     		${driving_list} PM25_TBW // Remove pollutants if you want to NOT apply beta. 

global adjust_for_ethanol 				yes // If set to no, will not adjust emission rates to account for ethanol.
	

*************************************************
/* Run Generalized Gas Tax MVPF for All Years. */
*************************************************
	
forval year = 1990(1)2022 {

	local dollar_year `year'
	
	*************************************************
	/* 2. Model the Light-duty, Gasoline-powered Vehicle Fleet. */
	*************************************************

	*===============================================================================
	* Step #2a: Pull relevant parameters from driving parameter Excel sheet. 
	*===============================================================================
	preserve

	import excel "${policy_assumptions}", first clear sheet("driving_parameters")

	* Catalytic converter decay parameters. 
	
	qui sum estimate if parameter == "decay_age_cutoff"
		global decay_age_cutoff = r(mean)
	
	qui sum estimate if parameter == "CO_decay"
		global CO_decay = (r(mean)/100)

	qui sum estimate if parameter == "HC_decay"
		global HC_decay = (r(mean)/100)
	
	qui sum estimate if parameter == "NOx_decay"
		global NOx_decay = (r(mean)/100)
		
	** Global Warming Potential Factors.
	qui sum estimate if parameter == "CO_gwp"
		global CO_gwp = r(mean)
		
	qui sum estimate if parameter == "VOC_gwp"
		global VOC_gwp = r(mean)
		
	* Gasoline composition parameters. 
	qui sum estimate if parameter == "CO2_per_gallon"
	global CO2_per_gallon = r(mean)
	
	qui sum estimate if parameter == "ppm_to_g_gal"
	global sulfur_ppm_conversion = r(mean)	

	import excel "${policy_assumptions}", first clear sheet("sulfur_content_gas")
	qui sum year
	if `dollar_year' < r(min) {
		qui sum year
		qui sum sulfur_content_ppm if year == r(min) // Earliest year in data.
			local SO2_gal = r(mean)
	}
	
	qui sum year
	if `dollar_year' > r(max) {
		
		qui sum year
		qui sum sulfur_content_ppm if year == r(max) // Last year in data.
			local SO2_gal = r(mean)

	}
	
	qui sum year
	if `dollar_year' <= r(max) & `dollar_year' >= r(min) {
		qui sum sulfur_content_ppm if year == `dollar_year'
			local SO2_gal = r(mean)
	}	
	
	restore 	
		
	*===============================================================================
	* Step #2b: Prepare VMT, fuel economy, and age distribution data for later. 
	*===============================================================================
	
	preserve
	* Fuel Economy.
	import excel "${policy_assumptions}", first clear sheet("fuel_economy_1975_2022")

	gen ModelYear_str = strlen(ModelYear)
	split ModelYear, parse()
	replace ModelYear = ModelYear2 if ModelYear_str > 4
	destring ModelYear, replace
	
	keep ModelYear RealWorldMPG RegulatoryClass
	keep if RegulatoryClass == "All"
	drop RegulatoryClass
	
	rename ModelYear model_year
	rename RealWorldMPG mpg
	
	qui sum mpg if model_year == 1975
	local mpg_overlap_1975_2022 = r(mean)
	
	tempfile fuel_economy_1975_2022
	save "`fuel_economy_1975_2022.dta'", replace 
						
	import excel "${policy_assumptions}", first clear sheet("fuel_economy_1957_1974")

	qui sum mpg if model_year == 1975 
	local mpg_overlap_1957_1975 = r(mean)
	
	* Splice data to have same mean in 1975 (from Jacobsen et al. 2023).
	replace mpg = mpg + (`mpg_overlap_1975_2022' - `mpg_overlap_1957_1975')
	
	drop if model_year == 1975

		append using "`fuel_economy_1975_2022.dta'"
		
		tempfile fuel_economy
		save "`fuel_economy.dta'", replace
		
		save "${assumptions_model_year}/fuel_economy_final.dta", replace // Used in EV calculations.

	restore
	
	*===============================================================================
	* Step #2c: Calculate emissions for PM2.5 (Exhaust), PM2.5 (Tires and Breaks), CH4, and N2O (from GREET).
	*===============================================================================
	preserve

	* Save production shares from U.S. EPA fuel economy data. 
	import excel "${policy_assumptions}", first clear sheet("fuel_economy_1975_2022")
	keep ModelYear RegulatoryClass VehicleType ProductionShare
	
	gen ModelYear_str = strlen(ModelYear)
	split ModelYear, parse()
	replace ModelYear = ModelYear2 if ModelYear_str>4
	destring ModelYear, replace
	drop ModelYear1 ModelYear2
		
	replace ProductionShare = "." if ProductionShare=="-"
	destring ProductionShare, replace
	qui sum ModelYear 
	local year_max = r(max) - 1
		
	levelsof(VehicleType), local(type_loop)
	foreach val of local type_loop {
		qui sum ProductionShare if ModelYear == `year_max' & VehicleType == "`val'"
		replace ProductionShare = r(mean) if ModelYear == `year_max' + 1 & VehicleType == "`val'"
	}
		
	gen vehicle_type_merge = ""
	replace vehicle_type_merge = VehicleType if VehicleType == "All Car"
	replace vehicle_type_merge = VehicleType if VehicleType == "Truck SUV"
	replace vehicle_type_merge = "Light Truck" if inlist(VehicleType, "Minivan/Van", "Pickup")
	
	drop if vehicle_type_merge == ""
	collapse (sum) ProductionShare, by(ModelYear vehicle_type_merge)
	bysort ModelYear : egen production_share_check = total(ProductionShare)
	assert round(production_share_check, 0.00001) == 1
	drop production_share_check
	
	rename ModelYear model_year 
	keep model_year vehicle_type_merge ProductionShare
	tempfile production_shares
	save "`production_shares.dta'", replace
		
		
	* Import and clean emission factors from GREET.
	import excel "${policy_assumptions}", first clear sheet("GREET_data_ldv_gas")
	merge 1:1 model_year vehicle_type_merge using "`production_shares.dta'", noreport
	drop if model_year > `dollar_year'

	qui sum model_year if PM25_exhaust != .
	local model_year_min = r(min)
	levelsof(vehicle_type_merge), local(class_loop)
	foreach class of local class_loop {
		ds PM25* CH4 N2O
		foreach val in `r(varlist)' {
			qui sum `val' if model_year == `model_year_min' & vehicle_type_merge == "`class'"
			replace `val' = r(mean) if model_year < `model_year_min' & vehicle_type_merge == "`class'"
		}
	}	
	
	
	qui sum model_year if PM25_exhaust != .
	local model_year_max = r(max)
	levelsof(vehicle_type_merge), local(class_loop)
	foreach class of local class_loop {
		ds PM25* CH4 N2O
		foreach val in `r(varlist)' {
			qui sum `val' if model_year == `model_year_max' & vehicle_type_merge == "`class'"
			replace `val' = r(mean) if model_year > `model_year_max' & vehicle_type_merge == "`class'"
		}
	}
	
	bysort model_year : egen production_share_check = total(ProductionShare)
	assert round(production_share_check, 0.00001) == 1
	drop production_share_check
		
	collapse (mean) PM25* CH4 N2O [aw=ProductionShare], by(model_year)
	tempfile GREET_emissions
		save "`GREET_emissions.dta'", replace
	
	if `dollar_year' == 2020 {
		save "${assumptions_model_year}/GREET_emissions_final.dta", replace // Used in EV calculations.
	}
	
	restore
		
	*===============================================================================
	* Step #2d: Combine model year emission rates from Jacobsen et al. 2023.
	*===============================================================================
	preserve
	use "${assumptions_model_year}/input_data/combined_aes73_copy", clear

	rename emissions_new_CO_natl emissions_new_CO
	rename emissions_new_HC_natl emissions_new_HC
	rename emissions_new_NOX_natl emissions_new_NOX
	keep emissions_new_CO emissions_new_HC emissions_new_NOX model_year
	
	tempfile temp
		save "`temp.dta'", replace

	
	use "${assumptions_model_year}/input_data/combined_newcars_copy", clear
	
	collapse (mean) emissions_new*, by(model_year)
	merge 1:1 model_year using "`temp.dta'", nogen noreport
		rename emissions_new_NOX emissions_new_NOx
		
	sort model_year 
	qui sum model_year 
		local model_year_min = r(min)
	
	save "${assumptions_model_year}/combined_Jacobsen_replicated", replace 
	restore

	*===============================================================================
	* Step #2e: Format data to incorporate age factors from Jacobsen et al. 2023. 
	*===============================================================================
	preserve
	clear 
	local obs_num = (`dollar_year' - `model_year_min') + 1
	insobs `obs_num'

	gen loop_ind = _n
	gen model_year = .
		forval val = 1(1)`obs_num' { 
			replace model_year = `model_year_min' + `val' - 1 if loop_ind == `val'
	}

	merge 1:1 model_year using "${assumptions_model_year}/combined_Jacobsen_replicated", noreport

	* Missing emission rates for 1994 and 1995, consistent with Jacobsen et al. 2023. 
	ds emissions_new*
	foreach var in `r(varlist)' {
		
		ipolate `var' model_year, generate(`var'_fixed) 
		replace `var' = `var'_fixed if `var' == .
		drop `var'_fixed
		
	}
	drop _merge 
		
	* 2021 and 2022 not in model year data set.
	if `dollar_year' > 2020 {
		
		ds emissions*
		foreach var in `r(varlist)' {
			
			qui sum `var' if model_year == 2020 // Max year.
				replace `var' = r(mean) if model_year > 2020
			
		}
		
	}
		
	cap drop weighted*

	*===============================================================================
	* Step #2f: Adjust emission rates.
	*===============================================================================
	gen age = (`dollar_year' - model_year) + 1
	gen decay_ind = age - 1
		replace decay_ind = ${decay_age_cutoff} if age > ${decay_age_cutoff}
		replace decay_ind = 0 if model_year < 1975 // Cars pre-1975 don't decay because they didn't have modern emission abatement technologies.
		
	ds emissions_new*
	foreach var in `r(varlist)' {
		
		gen `var'_decay = .
		
	}

	local p_list CO HC NOx
	foreach pollutant of local p_list {	
		
		replace emissions_new_`pollutant'_decay = ///
				emissions_new_`pollutant' * (1 + ${`pollutant'_decay})^(decay_ind)	
				
	}

	keep model_year *decay age
	
	*===============================================================================
	* Step #2g: Integrate fuel economy data and other emission estimates. 
	*===============================================================================
	merge 1:1 model_year using "`fuel_economy.dta'", keep(3) nogen noreport

	merge 1:1 model_year using "`GREET_emissions.dta'", keep(1 3) nogen noreport
	ds PM25* CH4 N2O
	foreach var in `r(varlist)' {
		
		qui sum model_year if `var' != . 
			local model_year_last = r(min)
			
		qui sum `var' if model_year == `model_year_last'
			local replace_`var' = r(mean)
			replace `var' = `replace_`var'' if model_year < `model_year_last'
			
	}
	drop if model_year > `dollar_year'
		
	*===============================================================================
	* Step #2h: Calculate weights. 
	*===============================================================================
	merge 1:1 age using "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", nogen noreport
	
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
	
	* Weight calculations.
	gen vmt_externality_weights = fleet_avg_vmt * age_share
	gen gallons_weights = (fleet_avg_vmt / mpg) * age_share
		
	*===============================================================================
	* Step #2i: Prepare data for two collapses. 
	*===============================================================================
	ds emissions*
	foreach var in `r(varlist)' {
		
		local newname = substr("`var'", 15, .)
		rename `var' `newname'
		
	}
	
	ds *_decay 
	foreach var in `r(varlist)' {
		
		local str_break = strpos("`var'", "_")
		local newname = substr("`var'", 1, `str_break' - 1)
		rename `var' `newname'_mi
		
	}
	rename CH4 CH4_mi
	rename N2O N2O_mi
	
	* Save data for other uses. 
	if inlist(`dollar_year', 2006, 2020) {
		save "${assumptions}/diesel_vehicles/diesel_emission_rates_`dollar_year'", replace	
	}
	
	* Calculate per-gallon estimates by vehicle age.
	ds *_mi
	foreach var in `r(varlist)' {
		
		local str_break = strpos("`var'", "_")
		local newname = substr("`var'",1, `str_break' - 1)

		gen `newname'_gal = `var'*mpg
		
	}
	
	ds PM25_exhaust
	foreach var in `r(varlist)' {
		
		gen `var'_gal = `var'*mpg
		
	}
	
	* Incorporate CO2 and SO2 emissions (defined per-gallon).
	gen CO2_gal = ${CO2_per_gallon}
	gen SO2_gal = `SO2_gal' * ${sulfur_ppm_conversion}
		
	drop *_mi PM25_exhaust
		rename PM25_TBW PM25_TBW_mi

	* Save data for other uses. 
	tempfile rebate_data_save 
		save "`rebate_data_save.dta'", replace
		
	rename mpg fleet_mpg 
	
	tempfile pre_collapse_save
		save "`pre_collapse_save'"
	
	restore
	
	*===============================================================================
	* Step #2j: Collapse data using appropriate weights. 
	*===============================================================================
	preserve
		use "`pre_collapse_save'", clear
		keep model_year PM25_TBW_mi vmt_externality_weights fleet_mpg
			collapse (mean) PM25_TBW_mi fleet_mpg [aw=vmt_externality_weights]
		gen PM25_TBW_gal = PM25_TBW_mi * fleet_mpg	
		drop PM25_TBW_mi
			
		ds 
		foreach var in `r(varlist)' {
			
			qui sum `var'
			local `var' = r(mean)
			
		}
	restore 		
			
			
	preserve
		use "`pre_collapse_save'", clear
		drop PM25_TBW_mi 
			collapse (mean) *_gal [aw=gallons_weights]
			
		gen fleet_mpg = `fleet_mpg'
		gen PM25_TBW_gal = `PM25_TBW_gal'
		gen fleet_year = `dollar_year'

		rename HC_gal VOC_gal
		order fleet_year fleet_mpg 
		
			save "${gas_fleet_emissions}/fleet_year_final", replace

	restore
	
	*===============================================================================
	* Step #2k: Calculate driving (accident and congestion) externalities. 
	*===============================================================================
	preserve

	import excel "${policy_assumptions}", first clear sheet("vmt_total_annual")
		keep if year == 2008 // Year most of data from Jacobsen (2013) come from.
		local vmt_calc = (total_vmt_millions*1000000)*-0.01

	import excel "${policy_assumptions}", first clear sheet("driving_parameters")	
	
	* Unit Conversions:
	split unit, parse("/") 
	gen adj_estimate = estimate
	order parameter paper estimate adj_estimate
		
	replace adj_estimate = (adj_estimate * 0.621371) if unit2=="km" 
	replace unit = unit1 + "/" + "mi" if unit2=="km" 
			
	replace adj_estimate = (estimate * ${VSL}) / `vmt_calc' if parameter == "mec_accidents" & paper == "Jacobsen 2013"
				
	replace dollar_year = "$VSL_dollar_year" if parameter == "mec_accidents" & paper == "Jacobsen 2013"

	* Inflation Adjustments: 
	replace dollar_year = "`dollar_year'" if dollar_year == "N/A"
		destring dollar_year, replace 
	gen order_loop = _n
	
	qui sum order_loop
	local max_loop = r(max)
	forval loop = 1(1)`max_loop' {
		
		qui sum dollar_year if order_loop==`loop'
		global base_year = r(mean)
		replace adj_estimate = adj_estimate*(${cpi_`dollar_year'}/${cpi_${base_year}}) if order_loop==`loop'
		
	}
		
	* Create locals for every parameter group; average if using multiple estimates.
	qui levelsof(parameter), local(externality)
	foreach value in `externality' {
		
		qui sum adj_estimate if parameter=="`value'"
		local `value' = r(mean)
		
	}	
		
	restore
			
**# Where We Import Social Costs
****************************************************
/* 3. Import Social Costs and Marginal Damages */
****************************************************
preserve

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
	
restore

	****************************************************
	/* 4. Pull in Emissions and Fuel Economy Data */
	****************************************************
	preserve

	use "${gas_fleet_emissions}/fleet_year_final", clear
	keep if fleet_year==`dollar_year'
	
	ds fleet_mpg *_gal
	foreach var in `r(varlist)' {
		
		replace `var' = `var'/1000000 if `var' != fleet_mpg
			* Converting from grams per gallon to metric tons per gallon.
			qui sum `var'
			local `var' = r(mean)
		}
		
	restore

	****************************************************
	/* 5. Upstream Emissions */
	****************************************************
	preserve

		****************************************************
		/* 5a. Calculate Upstream Emissions */
		****************************************************

		* Save upstream parameter from literature for later. 
		import excel "${policy_assumptions}", first clear sheet("driving_parameters")
		sum estimate if parameter == "MJ_conversion"
		global MJ_conversion = r(mean)
		
		sum estimate if parameter == "well_to_refinery_global"
		global well_to_refinery_emissions = (`r(mean)')*${MJ_conversion}
		* Convert from "g of CO2e per MJ of crude oil" to "g of CO2e per barrel of oil equivalent (BOE)."


		* Gather refinery production data.
		import excel "${policy_assumptions}", first clear sheet("refining_production")

		gen year = year(date)
		bysort year: drop if _N<12

		ds monthly* 
		foreach var in `r(varlist)' {
			replace `var'=`var'*1000
			* All reported as thousand barrels per month. Converting to barrels per month. 
			local newvar = substr("`var'",9,30)
			rename `var' `newvar'
		}

		collapse (sum) net*, by(year)
		tempfile refinery_production
		save "`refinery_production.dta'", replace

		
		* Add emissions data for refineries.
		import excel "${policy_assumptions}", first clear sheet("refining_emissions")

		ds *kt
		foreach var in `r(varlist)' {
			replace `var' = `var'*1000
			* Converting from kt to mt. N2O already reported as mt.
			local newname = substr("`var'",1,9)
			rename `var' `newname'_mt
		}

		ds *st
		foreach var in `r(varlist)' {
			replace `var' = `var'*0.907185
			ipolate `var' year, gen(`var'_extrap)
			replace `var' = `var'_extrap if `var' == .
			drop `var'_extrap
			
			qui sum `var' if year == 2020
				replace `var' = r(mean) if `var' ==. & year > 2020

			
			* Converting from short tons to metric tons. All 5 local pollutants reported in short tons. 
			local str_len = strlen("`var'")
			local newname = substr("`var'", 1, `str_len' - 3)
			rename `var' `newname'_mt
			
		}
		
		merge 1:1 year using "`refinery_production.dta'", keep(3) nogen noreport
	
		* Calculate marginal damages of refining a gallon of gas. 
		ds crude*
		foreach var in `r(varlist)' {
			local newname = substr("`var'",7,.)
			local str_ind = strpos("`newname'", "_")
			local newname = substr("`newname'",1,`str_ind' - 1)
			
			gen `newname'_emissions = `var'/net_input_total
			* Emissions per barrel of crude input.
		}

		gen refinery_yield_gal = ((net_output_${yield_toggle}*42)/net_input_total)

		ds *emissions 
		foreach var in `r(varlist)' {
			gen `var'_upstream = `var'/refinery_yield_gal
			* Emissions per gallon of petroleum product produced. 
		}
		
		keep year refinery_yield_gal *upstream
		
		* Add on well-to-refinery emissions.
		gen well_refinery_emissions_CO2e = (${well_to_refinery_emissions})/refinery_yield_gal
		* Now in terms of g of CO2e per gallon of petroleum product produced.

		replace well_refinery_emissions_CO2e = well_refinery_emissions_CO2e/1000000
		* Converting from g of CO2e to metric tons of CO2e. 

		gen CH4_well_to_refinery = (well_refinery_emissions_CO2e*0.34)/30
		// 34% of Masnadi et al. emissions are methane. 

		gen N2O_well_to_refinery = (well_refinery_emissions_CO2e*0.005)/265
		// <1% of Masnadi et al. emissions are N2O and VOC. Assuming half are N2O.
		// Don't need to do anything about VOC b/c we use the method as them to value it globally. 

		gen CO2_well_to_refinery = (well_refinery_emissions_CO2e*0.655)
		// Remainder: CO2 (and VOC)

		gen well_to_refinery_check = CH4_well_to_refinery*30 + N2O_well_to_refinery*265 + CO2_well_to_refinery
		assert round(well_to_refinery_check, 0.001) == round(well_refinery_emissions_CO2e, 0.001)
		drop well_to_refinery_check
			
		replace CH4_emissions_upstream = CH4_emissions_upstream + CH4_well_to_refinery
		replace CO2_emissions_upstream = CO2_emissions_upstream + CO2_well_to_refinery
		replace N2O_emissions_upstream = N2O_emissions + N2O_well_to_refinery

		keep *_emissions_upstream year refinery_yield_gal
					
		save "${gas_refinery_data}/upstream_emissions", replace
			
	restore
		
	****************************************************
	/* 5b. Import Upstream Emissions */
	****************************************************

	preserve
		
		use "${gas_refinery_data}/upstream_emissions", clear
		keep if year==`dollar_year'
		ds *emissions*
				
		foreach var in `r(varlist)' {
				
			local `var'=`var'
					
		}	
			
	restore

**# Where We Apply Social Costs
	****************************************************
	/* 6. Translate Externalities to Dollars per Gallon */
	****************************************************
	
* Pollution Externalities: Social Cost * Emissions per Gallon
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

* Upstream Externalities: Emissions per Gallon Produced * Social Cost (Unweighted Damages)
local wtp_upstream_total = 0
foreach val of global upstream {
	
	if inlist("`val'", "VOC", "CO", "PM25", "SO2", "NH3", "NOx") { 
		
		if "`val'" == "VOC" | "`val'" == "CO" {
			local wtp_upstream_`val'_local = -``val'_emissions_upstream'*`social_cost_`val'_uw'
			local wtp_upstream_`val'_global = -``val'_emissions_upstream'*(${`val'_gwp}*`social_cost_CO2')
				local wtp_upstream_`val' = `wtp_upstream_`val'_local' + `wtp_upstream_`val'_global'		
		}

		
		if inlist("`val'", "PM25", "SO2", "NH3", "NOx") {
			local wtp_upstream_`val' = ``val'_emissions_upstream'*-`social_cost_`val'_uw'
		}	
		
	}
	
	else {
		local wtp_upstream_`val' = ``val'_emissions_upstream'*-`social_cost_`val''
	}
	
	local wtp_upstream_total = `wtp_upstream_total' + `wtp_upstream_`val''
}

* Driving Externalities: Marginal External Cost per Mileg * MPG
foreach externality of global driving_list {
	
	local wtp_`externality' = -`mec_`externality''*`fleet_mpg'
	
}
			
	****************************************************
	/* 7. Save Results for Year y.  */
	****************************************************
	preserve

		clear
		insobs 1

		gen year = `dollar_year'	
		
		gen mpg = `fleet_mpg'
		
		foreach p of global pollutants_list {
			
			if "`p'" == "PM25_TBW" {
				
				gen wtp_`p' = `wtp_`p'' * -1 * `beta'
				
			}
			
			else {
				
				gen wtp_`p' = `wtp_`p'' * -1
				
			}
			
		}
		
		foreach e of global driving_list {
			
			gen wtp_`e' = `wtp_`e'' * -1 * `beta'
			
		}

		foreach u of global upstream {
			
			gen wtp_upstream_`u' = `wtp_upstream_`u'' * -1
			
		}
		
		gen local_VOC = -`wtp_VOC_local'
		gen global_VOC = -`wtp_VOC_global'
		gen global_VOC_upstream = -`wtp_upstream_VOC_global'
		gen local_VOC_upstream = -`wtp_upstream_VOC_local'
		
		gen local_CO = -`wtp_CO_local'
		gen global_CO = -`wtp_CO_global'
		gen global_CO_upstream = -`wtp_upstream_CO_global'
		gen local_CO_upstream = -`wtp_upstream_CO_local'

		tempfile data_`year'_save
		save "`data_`year'_save.dta'", replace
			
	restore 
	
}

****************************************************
/* 8. Combine Data Sets and Check Results  */
****************************************************
use "`data_1990_save.dta'", clear
forval year = 1991(1)2022 {
		
	append using "`data_`year'_save.dta'"
		
}

assert round(local_VOC + global_VOC, 0.0001) == round(wtp_VOC, 0.0001)
assert round(local_CO + global_CO, 0.0001) == round(wtp_CO, 0.0001)

****************************************************
/* 9. Adjust by Share of Ethanol in Gasoline.  */
****************************************************
if "${adjust_for_ethanol}" == "yes" {

preserve

	// Ethanol Emission Parameters.
	import excel "${policy_assumptions}", first clear sheet("ethanol_assumptions")
	
	levelsof(parameter), local(p_loop)
	foreach p of local p_loop {
		
		qui sum value if parameter == "`p'"
			global `p' = r(mean)
		
	}
	
	// Ethanol Shares by Year.
	import excel "${policy_assumptions}", first clear sheet("ethanol_blend_share")
	tempfile ethanol_shares
		save "`ethanol_shares'", replace
	
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
		keep year gas_consumption
		
		replace gas_consumption = ((gas_consumption * 1000) * (5.050 * 1000000)) / (10^12)
		// 5.050 = MMBTu per Barrel of Finished Motor Fuel. From thousands of barrels to trillions of Btu.
		
	merge 1:1 year using "`ethanol_shares'", nogen noreport
		keep if inrange(year, 1990, 2022)
	gen share_ethanol = ethanol_trillion_btu  / gas_consumption
		keep year share_ethanol
		tempfile ethanol_adjustment
			save "`ethanol_adjustment'", replace

restore

merge 1:1 year using "`ethanol_adjustment'", nogen noreport

// Save externalities before ethanol adjustment. 
save "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", replace 

	****************************************************
	/* 9a. Adjust Components Proportional to Gas Usage.  */
	****************************************************
	ds *upstream* wtp_CO2 wtp_CH4 wtp_N2O
	foreach var in `r(varlist)' {
		
		replace `var' = `var' * (1 - share_ethanol)
		// NOTE: SO2 reported ppm already reflects sulfur content.
		// NOTE: EPA fuel economy accounts for mileage penalty from ethanol. 
		// NOTE: Lifecycle analysis of ethanol includes CH4 and N2O from burning methane, so scaling down.
	
	}
	
	assert round(local_VOC + global_VOC, 0.0001) == round(wtp_VOC, 0.0001)
	assert round(local_CO + global_CO, 0.0001) == round(wtp_CO, 0.0001)
	
	
	****************************************************
	/* 9b. Adjust Local Pollution using % Change Estimates.  */
	****************************************************
	local ethanol_local_adj 	NOx CO VOC
	foreach p of local ethanol_local_adj {
		
		if "`p'" == "NOx" {
			replace wtp_`p' = wtp_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
		}
		if inlist("`p'", "CO", "VOC") {
			replace local_`p' = local_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
			replace global_`p' = global_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
		}
		
		// Assuming linear relationship b/w ethanol share and emission rate for low levels of ethanol. Paper tests percent decline in emissions for fuel w/ 9.8% ethanol.
		// Leaving PM2.5 unadjusted.

	}

	replace wtp_CO = local_CO + global_CO
	replace wtp_VOC = local_VOC + global_VOC
	
	****************************************************
	/* 9c. Account for Upstream Ethanol Emissions.  */
	****************************************************	
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		local upstream_CO2_ethanol = (((${upstream_CO2_intensity_`y'} + ${luc_CO2_intensity}) * ${mj_per_gal_ethanol})/1000000) * (${sc_CO2_`y'} * (${cpi_`y'}/${cpi_${sc_dollar_year}}))
		// Grams per MJ, multiplied by MJ per/gallon of ethanol, converted to tons, multiplied by SCC.
		
			replace wtp_upstream_CO2 = wtp_upstream_CO2 + (`upstream_CO2_ethanol' * share_ethanol) if year == `y'
			// Already scaled down petroleum upstream emissions by share petroleum; now adding upstream ethanol emissions.
		
	}
	
}

if "${adjust_for_ethanol}" == "no" {
	
	gen share_ethanol = 0
	
}
	
****************************************************
/* 10. Calculate Total, Local vs. Global Split, and CO2 Content  */
****************************************************
cap drop wtp_total wtp_local wtp_global

ds wtp*
egen wtp_total = rowtotal(`r(varlist)')

gen wtp_local = 0
foreach val of global damages_local {
				
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

	if "`val'" == "accidents" | "`val'" == "congestion" {
			
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

// assert round(wtp_total, 0.0001) == round(wtp_local + wtp_global, 0.0001)	
	
gen CO2_total = .	
levelsof(year), local(year_loop)
foreach y of local year_loop {
	
	replace CO2_total = wtp_global / (${sc_CO2_`y'} * (${cpi_`y'}/${cpi_${sc_dollar_year}}))
	
}	
	
	
****************************************************
/* 11. Save Dataset.  */
****************************************************
save "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", replace 

// LEAVING THESE GLOBALS HERE BECAUSE LOCAL DEPENDENT
qui sum year
	assert r(max) == 2022
global accidents_per_mi = `mec_accidents' * (${cpi_2020}/${cpi_2022}) // In 2020 dollars now. Converting from dollar year of last run to 2020 dollars.
global congestion_per_mi = `mec_congestion' * (${cpi_2020}/${cpi_2022}) // In 2020 dollars now. Converting from dollar year of last run to 2020 dollars.