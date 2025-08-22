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
local ev_193_exists = 0
local solar_193_exists = 0
local wind_193_exists = 0
local ev_76_exists = 0
local solar_76_exists = 0
local wind_76_exists = 0
local ev_337_exists = 0
local solar_337_exists = 0
local wind_337_exists = 0

* Check if 193 timepath has been created already
* timepaths must be created in the order of 193, 76 and then 337, as ordered in the masterfile

if "${scc}" == "76" | "${scc}" == "337" | "${scc}" == "1367" {
	* Check if required 193 timepaths exist
	local ev_193_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_193_age17_vmt.615_gridUS.dta")
	
	local solar_193_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc193_age25.dta")
	
	local wind_193_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc193_age25.dta")
	
	if (`ev_193_exists' + `solar_193_exists' + `wind_193_exists' < 3) {
		di as error "Please run the analysis with SCC = 193 first, timepaths must be created in this order: 193, 76, 337, and then 1367."
		exit 198 
	}
}
	

if "${scc}" == "337" | "${scc}" == "1367" {
	* Check if required 76 timepaths exist
	local ev_76_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_76_age17_vmt.615_gridUS.dta")
	
	local solar_76_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc76_age25.dta")
	
	local wind_76_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc76_age25.dta")
	
	if (`ev_76_exists' + `solar_76_exists' + `wind_76_exists' < 3) {
		di as error "Please run the analysis with SCC = 76 first, timepaths must be created in this order: 193, 76, 337, and then 1367."
		exit 198 
}
}

if "${scc}" == "1367" {
	* Check if required 337 timepaths exist
	local ev_337_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_337_age17_vmt.615_gridUS.dta")
	
	local solar_337_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc337_age25.dta")
	
	local wind_337_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc337_age25.dta")
	
	if (`ev_337_exists' + `solar_337_exists' + `wind_337_exists' < 3) {
		di as error "Please run the analysis with SCC = 337 first, timepaths must be created in this order: 193, 76, 337, and then 1367."
		exit 198 
}
}
	

local cases "renewables_loop" "change_grid" "solar_output_change" "wind_emissions_change" "lifetime_change" "no_cap_reduction" "wind_lifetime_change" "VMT_change_robustness"

foreach case in `cases' {
	
	if "${`case'}" == "yes" {
		
		local special = 1
	}
}

if "${change_grid}" != "" {
	local special = 1
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
	
	if "${change_grid}" != "" {
		local ev_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${change_grid}.dta")
		local solar_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc${scc}_age25_${change_grid}.dta")  
		local wind_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc${scc}_age25_${change_grid}.dta")
		
		di in red "EV file exists: `ev_exists'"
		di in red "Solar file exists: `solar_exists'"
		di in red "Wind file exists: `wind_exists'"
	}
	else {
		local ev_exists = fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${ev_grid}_${renewables_percent}.dta")
		local solar_exists = fileexists("${assumptions}/timepaths/solar_externalities_time_path_scc${scc}_age25_${renewables_percent}.dta")  
		local wind_exists = fileexists("${assumptions}/timepaths/wind_externalities_time_path_scc${scc}_age25_${renewables_percent}.dta")
	}
	
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
