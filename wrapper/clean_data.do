/*-----------------------------------------------------------------------
* Prepare Input Datasets
*-----------------------------------------------------------------------*/

// Install reclink if not already installed
capture which reclink
if _rc != 0 {
    ssc install reclink
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

