*************************************************************************
/* Purpose: Calculate environmental externality over BEV lifetime. */
*************************************************************************

* Note: the values output from this .do file should be used with the "current" mode.

global ext_min_year = 2011 // No lower than 2011 -- earliest year with all necessary data points. 
global ext_max_year = ${ev_simulation_max_year}

**********************************
**# /* 0. Define and Set Toggles. */
**********************************
local discount = ${discount_rate}

*****************************************************************
/* 1. Calculate Externalities from Charging and Driving an EV. */
*****************************************************************
local vmt_type_loop car avg

foreach v of local vmt_type_loop {

	forval run_year = $ext_min_year (1) $ext_max_year {

		*************************************************
		/* 1a. Pull in EV MVPF Parameters. */
		*************************************************
		import excel "${policy_assumptions}", first clear sheet("evs")
		levelsof Parameter, local(levels)
		foreach val of local levels {
			
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
			
		}
		
		*************************************************
		/* 1b. Pull in Data on Electric Vehicle Energy Consumption. */
		*************************************************
		use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
		qui sum year
		if `run_year' > r(max) {
			keep if year == r(max)
		}
		else {
			keep if year == `run_year'
		}
		
		qui sum avg_kwh_per_mile
		local kwh_per_mile = r(mean)
			
		qui sum avg_batt_cap
		local battery_cap = r(mean)

		*************************************************
		/* 1c. Pull in Data on VMT. */
		*************************************************	
		if "`v'" == "avg" {
			
			use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_`v'.dta", clear
			keep if age <= ${vehicle_`v'_lifetime}
			drop age_share
			levelsof(age), local(age_loop)
			foreach a of local age_loop {
				
				qui sum fleet_avg_vmt if age == `a'
				local ice_miles_traveled`a' = r(mean)
				local ev_miles_traveled`a' = `ice_miles_traveled`a'' * ${EV_VMT_`v'_adjustment}
				
			}
						
		}
		
		if "`v'" == "car" {
		
			use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_`v'.dta", clear
			keep if age <= ${vehicle_`v'_lifetime}	
			drop age_share
			levelsof(age), local(age_loop)
			foreach a of local age_loop {
				
				qui sum vmt_avg_car if age == `a'
				local ice_miles_traveled`a' = r(mean)
				local ev_miles_traveled`a' = `ice_miles_traveled`a'' * ${EV_VMT_`v'_adjustment}
				
			}

		}			


		*************************************************
		/* 1d. Loop over Dynamic Grid Options. */
		*************************************************
		local grid_ub = (`run_year' + ${vehicle_`v'_lifetime}) - 1
		
		if `run_year' > 2022 {
			
			global kwh_price_`run_year'_US = ${kwh_price_2020_US} // Shouldn't have to use anywhere.
			global producer_surplus_`run_year'_US = ${producer_surplus_2020_US} // Shouldn't have to use anywhere.
			global government_revenue_`run_year'_US = ${government_revenue_2020_US} // Shouldn't have to use anywhere.

		}

		local local_benefit = 0
		local global_benefit = 0
		local carbon_content = 0
		local kwh_savings = 0
		local kwh_profits = 0
		local kwh_revenue = 0
		
		local age = 1
		
		forval y = `run_year' (1) `grid_ub' {

			local kwh_used = (`ev_miles_traveled`age'' * `kwh_per_mile')

			if "${change_grid}" != "" {
				global ev_grid = "${change_grid}"
			}
			
			if "${ev_grid}" == "" | "${change_grid}" == "" {
				global ev_grid US
			}

			qui {
				dynamic_split_grid `kwh_used', starting_year(`run_year') ext_year(`y') discount_rate(`discount') ///
				ef("${replacement}") type("uniform") geo("${ev_grid}") grid_specify("yes") model("${grid_model}")
				
				if `age' == 1 & "`v'" == "car"{
					global ev_first_damages_g_`run_year' = `r(global_enviro_ext)'
				}
					
				local local_benefit = `local_benefit' + `r(local_enviro_ext)'
				local global_benefit = `global_benefit' + `r(global_enviro_ext)'
				local carbon_content = `carbon_content' + `r(carbon_content)'
				
				local kwh_savings = `kwh_savings' + ((`kwh_used' * ${kwh_price_`run_year'_US}) / ((1+`discount')^(`y' - `run_year')))
				local kwh_profits = `kwh_profits' + ((`kwh_used' * ${producer_surplus_`run_year'_US}) / ((1+`discount')^(`y' - `run_year')))
				local kwh_revenue = `kwh_revenue' + ((`kwh_used' * ${government_revenue_`run_year'_US}) / ((1+`discount')^(`y' - `run_year')))
								
				local age = `age' + 1
			}
			
			global local_`v'_`run_year' = `local_benefit'
			global global_`v'_`run_year' = `global_benefit'
			global CO2_`v'_`run_year' = `carbon_content'
			global kwh_savings_`v'_`run_year' = `kwh_savings'
			global kwh_profits_`v'_`run_year' = `kwh_profits'
			global kwh_revenue_`v'_`run_year' = `kwh_revenue'				

		}
					
	}	
	
}

*************************************************
/* 2. Collect Results. */
*************************************************
clear
	
qui forval y = $ext_min_year (1) $ext_max_year {
	
	insobs 1
	cap gen year = .
	replace year = `y' if year == .
		
	foreach v of local vmt_type_loop {
		cap gen grid_ext_`v'_local_no_r = .
		replace grid_ext_`v'_local_no_r = ${local_`v'_`y'} if year == `y'
				
		cap gen grid_ext_`v'_global_no_r = .
		replace grid_ext_`v'_global_no_r = ${global_`v'_`y'} if year == `y'
				
		cap gen grid_ext_`v'_CO2_no_r = .
		replace grid_ext_`v'_CO2_no_r = ${CO2_`v'_`y'} if year == `y'
		
		cap gen grid_charging_`v'_savings = .
		replace grid_charging_`v'_savings = ${kwh_savings_`v'_`y'} if year == `y'
			
		cap gen grid_charging_`v'_profits_no_r = .
		replace grid_charging_`v'_profits = ${kwh_profits_`v'_`y'} if year == `y'
			
		cap gen grid_charging_`v'_revenue_no_r = .
		replace grid_charging_`v'_revenue = ${kwh_revenue_`v'_`y'} if year == `y'
				
	}
			
}
	
*************************************************
/* 3. Apply Rebound Effect to EV Externalities. */
*************************************************	
rebound ${rebound}
local r = `r(r)'

foreach v of local vmt_type_loop {

	gen grid_ext_`v'_total_no_r = grid_ext_`v'_local_no_r + grid_ext_`v'_global_no_r
	
	
	gen grid_ext_`v'_local = grid_ext_`v'_local_no_r * `r'
	gen grid_ext_`v'_global = grid_ext_`v'_global_no_r * `r'
	gen grid_ext_`v'_total = grid_ext_`v'_local + grid_ext_`v'_global
	gen grid_ext_`v'_CO2 = grid_ext_`v'_CO2_no_r * `r'
			
	// Apply rebound but not storing rbd as own quantity	
	gen grid_charging_`v'_profits = grid_charging_`v'_profits_no_r * `r'
	gen grid_charging_`v'_revenue = grid_charging_`v'_revenue_no_r * `r'	
	
	gen grid_ext_`v'_rbd_local = (grid_ext_`v'_local_no_r) * (1 - `r')
	*assert round(grid_ext_`v'_local_no_r - grid_ext_`v'_rbd_local, 0.1) == round(grid_ext_`v'_local, 0.1)
		
	gen grid_ext_`v'_rbd_global = (grid_ext_`v'_global_no_r) * (1 - `r')
	*assert round(grid_ext_`v'_global_no_r - grid_ext_`v'_rbd_global, 0.1) == round(grid_ext_`v'_global, 0.1)

	gen grid_ext_`v'_rbd_total = (grid_ext_`v'_total_no_r) * (1 - `r')
	*assert round(grid_ext_`v'_total_no_r - grid_ext_`v'_rbd_total, 0.1) == round(grid_ext_`v'_total, 0.1)
	
	gen grid_ext_`v'_rbd_CO2 = (grid_ext_`v'_CO2_no_r) * (1 - `r')
	*assert round(grid_ext_`v'_CO2_no_r - grid_ext_`v'_rbd_CO2, 0.1) == round(grid_ext_`v'_CO2, 0.1)

}

*************************************************
/* 4. Save Results. */
*************************************************	
save "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/EV Charging/ev_charging_${grid_model}_${replacement}_${scc_ind_name}_${dr_ind_name}.dta", replace