*-----------------------------------------------------------------------
* Check if Timepaths Should Re-run
*-----------------------------------------------------------------------
cap prog drop check_timepaths
prog def check_timepaths, rclass

syntax anything, /// yes or no 
		[weighted_average(string)] ///
		
*Check if it is a special case (running robustness/alternative assumptions) or not
local special = 0 
local ev_exists = 0
local solar_exists = 0
local wind_exists = 0

local cases "renewables_loop" "change_grid" "solar_output_change" "wind_emissions_change" "lifetime_change" "no_cap_reduction" "wind_lifetime_change"

foreach case in `cases' {
	
	if "${`case'}" == "yes" {
		
		local special = 1
	}
}

*For cases that are not special
if `special' == 0 {
	
	local ev_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age17_vmt${EV_VMT_car_adjustment_ind}_gridUS.dta")
	
	local solar_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc${scc}_age25.dta")  
	
	local wind_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc${scc}_age25.dta")
	
}

if "${renewables_loop}" == "yes" {
	local ev_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${ev_grid}_${renewables_percent}.dta")
	
	local solar_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc${scc}_age25_${renewables_percent}.dta")  
	
	local wind_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc${scc}_age25_${renewables_percent}.dta")
}

if `special' == 1 & "${renewables_loop}" == "no" {
	
	local ev_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${ev_grid}_${renewables_percent}.dta")

	if `ev_exists' == 1 {
		global ev_simulation_max_year 2022
		global rerun_timepaths = "no"
		global rerun_solar_wind_timepaths = "yes"
	}
}

if (`ev_exists' + `solar_exists' + `wind_exists' < 3) {
	global rerun_timepaths = "yes"
	global ev_simulation_max_year 2050
	global rerun_macros = "yes"
}

if (`ev_exists' + `solar_exists' + `wind_exists' == 3) {
	global rerun_timepaths = "no"
	global ev_simulation_max_year 2022
}

end
