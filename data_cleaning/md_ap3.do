*************************************************************
/* 1. Save Data Sets.					 */
*************************************************************

	*************************************************************
	/* 1a. County Orderings for AP3.					 */
	*************************************************************
	import delimited "${assumptions}/marginal_damages/fips_apeep.csv", clear
		gen merge_id = _n
			qui sum merge_id 
				assert r(max) == 3109 // AP3 has data for 3,109 counties.
	tempfile ap3_counties_merge
		save "`ap3_counties_merge'", replace
	
	*************************************************************
	/* 1b. VMT by County.					 */
	*************************************************************
	import excel "${policy_assumptions}", first clear sheet("vmt_by_county")
		drop Share* *buses* Notes *Region
		
	ds *vmt
	foreach var in `r(varlist)' {
		
		replace `var' = "0" if `var' == "-"
			destring `var', replace
		
	}
	gen vmt_total = passenger_car_vmt + truck_vmt	
		drop *car* *truck*

	destring StateandCountyFIPSCode, replace
		rename StateandCountyFIPSCode fips
		rename CountyName county_check
			replace county_check = strlower(county_check)
		rename PostalStateCode state

	tempfile vmt_weights
		save "`vmt_weights'", replace
		
	*************************************************************
	/* 1c. Electricity Generation by County.					 */
	*************************************************************	
	import excel "${assumptions}/marginal_damages/plant_id_2020.xlsx", first clear
		tempfile plant_id_save
			save "`plant_id_save'", replace
	
	import excel "${assumptions}/marginal_damages/generation_by_plant_2020.xlsx", first clear
		drop if PlantId == 99999
			merge m:1 PlantId using "`plant_id_save'", nogen noreport keep(3)
			
	drop if inlist(State, "AK", "HI")
		gen county = subinstr(strlower(County), " ", "", .)
	
	rename State state
		drop Zip County Street* Utility* Grid* PlantId
		drop if TotalFuelConsumptionQuantity == 0
			drop if inlist(ReportedFuelTypeCode, "WAT")
		
	collapse (sum) TotalFuelConsumptionMMBtu (firstnm) state, by(county)
		drop if TotalFuelConsumptionMMBtu  < 0 // Changes no data.
	tempfile generation_by_county_2020
		save "`generation_by_county_2020'", replace
	
*************************************************************
/* 2. Calculate Avg. Ground-level Marginal Damages, Weighted by VMT.					 */
*************************************************************
import delimited "${assumptions}/marginal_damages/md_Area_2014_VSL${VSL_dollar_year}.csv", clear
	gen merge_id = _n
		qui sum merge_id 
			assert r(max) == 3109 // AP3 has data for 3,109 counties.
merge 1:1 merge_id using "`ap3_counties_merge'", nogen noreport assert(3)
	drop merge_id
		order state county fips

	*************************************************************
	/* 2a. Rename Variables, Following AP3 Output Ordering.					 */
	*************************************************************	
	rename v1 md_NH3
	rename v2 md_NOx
	rename v3 md_PM25
	rename v4 md_SO2
	rename v5 md_VOC 
	
	*************************************************************
	/* 2b. Rename Variables, Following AP3 Output Ordering.					 */
	*************************************************************	
	replace county = strlower(county)
		gen county_ind = substr(county, strlen(county) - 5, .)
	gen county_check = ""
		replace county_check = substr(county, 1, strlen(county) - 7) if inlist(county_ind, "county", "parish")
		replace county_check = county if county_check == ""
		
	replace county_check = "de kalb" if fips == 18033	
		
	merge 1:1 state county_check using "`vmt_weights'"
		drop if inlist(state, "AK", "HI") // Not in AP3.
			keep if _merge == 3 // Only two counties do not align. 
	drop _merge
	
	*************************************************************
	/* 2c. Average across Counties, Weighting by VMT.					 */
	*************************************************************	
	collapse (mean) md* [aw = vmt_total]
	
	ds md*
	foreach var in `r(varlist)' {
		
		global `var'_vmt_weighted = `var'
		
	}
	
*************************************************************
/* 3. Calculate Avg. Marginal Damages, Weighted by Power Generation.					 */
*************************************************************	

	*************************************************************
	/* 3a. Collect Emissions and Damages by Plant Type.					 */
	*************************************************************	
	local height_types		Low Medium Tall1 Tall2
	foreach h of local height_types {
		
		preserve
		
			import delimited "${assumptions}/marginal_damages/AP3 Raw Data/data_`h'_2014", clear
				assert v3 == 0
					drop v3
			rename v1 q_NH3
			rename v2 q_NOx
			rename v4 q_PM25
			rename v5 q_SO2
			rename v6 q_VOC 
			
			gen merge_id = _n
				tempfile `h'_save
					save "``h'_save'", replace
			
			import delimited "${assumptions}/marginal_damages/md_`h'_2014_VSL${VSL_dollar_year}.csv", clear
				rename v1 md_NH3
				rename v2 md_NOx
				rename v3 md_PM25
				rename v4 md_SO2
				rename v5 md_VOC 
			gen merge_id = _n	
				merge 1:1 merge_id using "``h'_save'", nogen noreport assert(3)
				
			if inlist("`h'", "Low", "Medium") {
				
				merge 1:1 merge_id using "`ap3_counties_merge'", nogen noreport assert(3)
					drop merge_id
				drop if inlist(state, "AK", "HI")	
				
			}	
			
			if inlist("`h'", "Tall1", "Tall2") {
				
				rename merge_id row
					merge 1:1 row using "${assumptions}/marginal_damages/AP3 Raw Data/id_`h'", nogen noreport assert(3)
				destring fips, replace		
				drop if inlist(state, "AK", "HI")
				
					keep md_* q_* fips county state
				
			}
			
			tempfile final_`h'_save 
				save "`final_`h'_save'", replace
			
		restore
		
	}
	
	*************************************************************
	/* 3b. Collect Results.					 */
	*************************************************************	
	use "`final_Low_save'", clear
	foreach h of local height_types {
		
		if "`h'" == "Low" {
			continue
		}
		else {
			append using "`final_`h'_save'"
		}
		
	}
	replace fips = fips2 if fips == .
		drop fips2
		
	ds q_*
	foreach var in `r(varlist)' {
		
		qui sum `var' if missing(fips)
			assert `r(mean)' == 0 
		
	}
	drop if missing(fips)
	
	sort county
	
	merge m:1 fips using "`ap3_counties_merge'", nogen noreport assert(3)
		drop longitude lat merge_id
		drop if missing(fips) // No changes made here.	
					
	*************************************************************
	/* 3c. Collect Results.					 */
	*************************************************************
	replace county = strlower(county)		
	gen county_check = substr(county, strlen(county) - 5, .)	
		replace county = substr(county, 1, strlen(county) - 7) if inlist(county_check, "county", "parish")
			drop county_check
	replace county = subinstr(county, " ", "", .)	
		replace county = subinstr(county, "-", "", .)
			replace county = subinstr(county, ".", "", .)
				replace county = subinstr(county, "'", "", .)
		
		
	sort fips county
		bysort fips : egen county_obs_num = count(fips)
	qui levelsof(fips), local(county_loop)
	foreach c of local county_loop {
		
		qui sum county_obs_num if fips == `c'
			qui replace county = county[`r(max)'] if county == "" & fips == `c'
				assert county != "" if fips == `c'
		
	}
	assert !missing(county)
	
	*************************************************************
	/* 3d. Calculate Average MD by County, Across Height Types.					 */
	*************************************************************				
	local pollution_list          NH3 NOx PM25 SO2 VOC
	foreach p of local pollution_list {
		
		preserve
		
			keep md_`p' q_`p' state county fips state
				collapse (mean) md_`p' (firstnm) county (firstnm) state [aw = q_`p'], by(fips)
			tempfile save_`p'
				save "`save_`p''", replace
		
		restore
		
	}
	
	foreach p of local pollution_list {
		
		if "`p'" == "NH3" {
			use "`save_`p''", clear
				order fips county state
		}
		else {
			merge 1:1 county fips using "`save_`p''", nogen noreport
		}
		
	}
	ds md_*
	foreach var in `r(varlist)' {
		
		replace `var' = 0 if `var' == .
		
	}
	
	*************************************************************
	/* 3e. Weight by Generation.					 */
	*************************************************************
	preserve	
		merge 1:1 county state using "`generation_by_county_2020'"
			collapse (mean) md* [aw = TotalFuelConsumptionMMBtu]
		ds md*
		foreach var in `r(varlist)' {
			
			global `var'_elec_weighted = `var'
			
		}
	restore
