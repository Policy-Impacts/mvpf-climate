/*-----------------------------------------------------------------------
* Prepare Input Datasets
*-----------------------------------------------------------------------*/

// Install reclink if not already installed
capture which reclink
if _rc != 0 {
    ssc install reclink
}

global code_files                = "${dropbox}"
global assumptions               = "${code_files}/1_assumptions"

global policy_assumptions		= "${assumptions}/policy_category_assumptions_MASTER.xlsx"

		import excel "${policy_assumptions}", first clear sheet("cpi_index")
		gen year = year(FREDYear)
		qui sum year
		local first_year_missing_cpi = r(max) + 1
		
		levelsof(year), local(year_loop)
		foreach y of local year_loop {
			
			qui sum index if year == `y'
			global cpi_`y' = r(mean) 
			
		}

		forval y = `first_year_missing_cpi'(1)2050 {
			
			global cpi_`y' = ${cpi_2020}
			
		}
		

do "${github}/data_cleaning/build_batt_data.do"

do "${github}/data_cleaning/build_batt_sales_data.do"

do "${github}/data_cleaning/clean_2023_kbb_data.do"

do "${github}/data_cleaning/build_bev_fed_subsidy_data.do"

do "${github}/data_cleaning/build_ev_vmt_by_age_state.do"

do "${github}/data_cleaning/build_ev_kwh_msrp_batt_cap.do"

do "${github}/data_cleaning/build_ice_vmt_by_age_state.do"

do "${github}/data_cleaning/clean_state_pop.do"

do "${github}/data_cleaning/build_hev_data.do"

