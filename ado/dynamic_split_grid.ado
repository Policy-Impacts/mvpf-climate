****************************************************************
*Creating an Ado file for a dynamic grid
*Input the annual kwh, starting year, and number of years
*It will output total local and global environmental externality
****************************************************************

cap prog drop dynamic_split_grid
prog def dynamic_split_grid, rclass


syntax anything, /// annual kwh
	starting_year(integer) /// either policy year or 2020
	ext_year(integer) /// what year's externality do you want
	discount_rate(real) ///
	ef(string) /// either marginal, average, high, or low
	geo(string) /// either US or other state abbreviation
	[type(string) /// if marginal, then this is either solar, wind, or uniform
	 grid_specify(string) /// either "yes" or "no"
	 model(string) /// either "optimistic" "conservative" "frozen" or "midpoint"
	]

*Override US grid if we are running a robustness specification on new grid
if "${change_grid}" != "" {
	local geo = "${change_grid}"
}

if "${change_grid}" == "EU" {
	local geo = "US"
}

if "`ef'" == "average" {
	local ef_factor = "kwh"
	local carbon_scale = "avg"
	local enviro_ext_2020 = ${local_kwh_`geo'_2020} + ${global_kwh_`geo'_2020}
	local global_split = ${global_kwh_`geo'_2020} / `enviro_ext_2020'
}

if "`ef'" == "marginal" {
	local ef_factor = "`type'"
	local carbon_scale = "`type'"
	local enviro_ext_2020 = ${local_`type'_`geo'_2020} + ${global_`type'_`geo'_2020}
	local global_split = ${global_`type'_`geo'_2020} / `enviro_ext_2020'
}

if "`ef'" == "high" {
	local ef_factor = "kwh"
	local carbon_scale = "`type'"
	local geo = "HIGH"
	local type = "kwh"
	local enviro_ext_2020 = ${local_`type'_`geo'_2020} + ${global_`type'_`geo'_2020}
	local global_split = ${global_`type'_`geo'_2020} / `enviro_ext_2020'
}

if "`ef'" == "low" {
	local ef_factor = "kwh"
	local carbon_scale = "`type'"
	local geo = "LOW"
	local type = "kwh"
	local enviro_ext_2020 = ${local_`type'_`geo'_2020} + ${global_`type'_`geo'_2020}
	local global_split = ${global_`type'_`geo'_2020} / `enviro_ext_2020'
}

if "`grid_specify'" == "yes" {
	
	if "`model'" == "optimistic" | "`model'" == "opt" {
		local princeton_model = "opt"
	}

	if "`model'" == "conservative" | "`model'" == "cons"{
		local princeton_model = "cons"
	}

	if "`model'" == "frozen" | "`model'" == "frz" {
		local princeton_model = "frozen"
	}
	
	if "`model'" == "midpoint" | "`model'" == "static" | "`model'" == "mid" | "`model'" == "sta" {
		local princeton_model = "mid"
	}
}

if "`grid_specify'" == "no" {
	local princeton_model = "mid"
}

local negative_kwh = 0

if `anything' < 0 {
	local anything = `anything' * -1
	local negative_kwh = 1
}
local negative_kwh = 0

if `anything' < 0 {
	local anything = `anything' * -1
	local negative_kwh = 1
}
preserve
qui import excel "${policy_assumptions}", first clear sheet("princeton_grid")

forvalues y = 2020(1)2050 {
	qui sum Share_Clean_`princeton_model' if Year == `y'
	local share_dirty_US_`y' = 1 - `r(mean)'
	
	qui sum level_ng_`princeton_model' if Year == `y'
	local ng_level = `r(mean)'
	
	qui sum level_coal_`princeton_model' if Year == `y'
	local coal_level = `r(mean)'

	local share_ng_US_`y' = (`ng_level' / (`ng_level' + `coal_level')) * `share_dirty_US_`y''
	
	local share_coal_US_`y' = (`coal_level' / (`ng_level' + `coal_level')) * `share_dirty_US_`y''
	
}

qui import excel "${policy_assumptions}", first clear sheet("princeton_grid")

forvalues y = 2020(1)2050 {
	qui sum Share_Clean_`princeton_model' if Year == `y'
	local share_dirty_US_`y' = 1 - `r(mean)'
}
restore

forvalues y = 2020(1)2070 {
	local baseline_scc_`y' = ${sc_CO2_`y'}
}


*If it's not at the National level, get the dirtiness of state grid in 2020
if "`ef'" == "high" {
	local geo = "${state_dirty_2020}"
}

if "`ef'" == "low" {
	local geo = "${state_clean_2020}"
}
if "`geo'" !=  "US"{
	preserve
	qui import excel "${assumptions}/grid_pollution", first clear sheet("2020_dirty_share")
	qui sum combustion_percent if State == "`geo'"
	local share_dirty_`geo'_2020 = `r(mean)'
	restore
	
	forvalues y = 2021(1)2050 {
		local year_before = `y' - 1
		local share_dirty_`geo'_`y' = ((`share_dirty_US_`y'' - `share_dirty_US_`year_before'')/`share_dirty_US_`year_before'') * `share_dirty_`geo'_`year_before'' + `share_dirty_`geo'_`year_before''
	}
	
}

local dirty_2020 = (1/`share_dirty_`geo'_2020') * `enviro_ext_2020' // This is the externality if the entire 2020 grid was from fossil fuels

 
*If the starting year is less than 2020, get the externality for the years before 2020
if "`ef'" == "high" {
	local geo = "HIGH"
}

if "`ef'" == "low" {
	local geo = "LOW"
}
if `ext_year' < 2020 {

		local discount_year = `ext_year' - `starting_year'
		local discount_year = `ext_year' - `starting_year'
		local local_enviro_ext = (`anything' *  ${local_`ef_factor'_`geo'_`ext_year'} * (${cpi_`starting_year'}/${cpi_`ext_year'})) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
		local global_enviro_ext = (`anything' *  ${global_`ef_factor'_`geo'_`ext_year'} * (${cpi_`starting_year'}/${cpi_`ext_year'})) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh

		local total_local = `local_enviro_ext'
		local total_global = `global_enviro_ext'
		local carbon_content = (`anything' *  ${global_`ef_factor'_`geo'_`ext_year'}) / ${sc_CO2_`ext_year'}
			
}

*Get the externality for the years after 2020
	
local coal_to_ng_use = 0.1928/0.4047 // The 2020 grid is 19.28% coal and 40.47% natural gas // So for every one unit of natural gas there is 0.476 units of coal

local coal_to_ng_emissions = 2181.842/898.122 // From eGRID 2020, the output emissions rate (CO2e) for coal and natural gas // So if one unit of natural gas produces one unit of emissions, one unit of coal produces 2.429 units of emissions

local weighted_emissions_c_ng = `coal_to_ng_use' * `coal_to_ng_emissions' // Combining the previous two measures we have that the ratio of ng to coal emissions weighted by use is 1:1.157

local prop_emissions_coal = `weighted_emissions_c_ng' / (1 + `weighted_emissions_c_ng')
local prop_emissions_ng = 1 - `prop_emissions_coal'

local dirty_coal_2020 = (`enviro_ext_2020' * `prop_emissions_coal') * (1 / `share_coal_US_2020') 

local dirty_ng_2020 = (`enviro_ext_2020' * `prop_emissions_ng') * (1 / `share_ng_US_2020') 

if "`ef'" == "high" {
	local geo = "${state_dirty_2020}"
}

if "`ef'" == "low" {
	local geo = "${state_clean_2020}"
}

*We assume all the local pollutants from the grid post 2020 come from Coal. 
local local_coal_split = (1 - `global_split') / `prop_emissions_coal'
local global_coal_split = 1 - `local_coal_split'

*Forecast US Grid After 2020

if "`geo'" == "US" {

	if `ext_year' >= 2020  & `ext_year' <= 2050 { 
		
		if `starting_year' <= 2020 {
			local inflation_year = `starting_year'
		}
		
		if `starting_year' > 2020 {
			local inflation_year = 2020
		}
		
			
			local discount_year = `ext_year' - `starting_year'
			local kwh_emissions = (`dirty_coal_2020' * `share_coal_`geo'_`ext_year'') + (`dirty_ng_2020' * `share_ng_`geo'_`ext_year'')
			
			local temp_prop_coal = `share_coal_`geo'_`ext_year'' / (`share_coal_`geo'_`ext_year'' + `share_ng_`geo'_`ext_year'')

			local enviro_ext = (`anything' *  (`kwh_emissions' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
			
			
			local carbon_content = (((`anything' * `kwh_emissions') * (1 - `temp_prop_coal')) + ((`anything' * `kwh_emissions') * `temp_prop_coal' * `global_coal_split')) / ${sc_CO2_2020}
			
			local total_local = ((`enviro_ext' * `temp_prop_coal') * `local_coal_split')
			
			local total_global = ((`enviro_ext' * (1 - `temp_prop_coal')) + (`enviro_ext' * `temp_prop_coal' * `global_coal_split')) * (`baseline_scc_`ext_year''/`baseline_scc_2020')
			
	}


	if `ext_year' > 2050 { 
		
		if `starting_year' <= 2020 {
			local inflation_year = `starting_year'
		}
		
		if `starting_year' > 2020 {
			local inflation_year = 2020
		}
		
			local discount_year = `ext_year' - `starting_year'
			
			
			
			local kwh_emissions = (`dirty_coal_2020' * `share_coal_`geo'_2050') + (`dirty_ng_2020' * `share_ng_`geo'_2050')
			
			local temp_prop_coal = `share_coal_`geo'_2050' / (`share_coal_`geo'_2050' + `share_ng_`geo'_2050')

			local enviro_ext = (`anything' *  (`kwh_emissions' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
			
//			
//			
//			
// 			local temp_prop_coal = `share_coal_`geo'_2050' / (`share_coal_`geo'_2050' + `share_ng_`geo'_2050')
//			
// 			local enviro_ext = (`anything' *  (`dirty_2020' * `share_dirty_`geo'_2050' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
			
			local total_local = ((`enviro_ext' * `temp_prop_coal') * `local_coal_split')
			
			local total_global = ((`enviro_ext' * (1 - `temp_prop_coal')) + (`enviro_ext' * `temp_prop_coal' * `global_coal_split')) * (`baseline_scc_`ext_year''/`baseline_scc_2020')
			
			local carbon_content = (((`anything' * `kwh_emissions') * (1 - `temp_prop_coal')) + ((`anything' * `kwh_emissions') * `temp_prop_coal' * `global_coal_split')) / ${sc_CO2_2020}
			
// 			local total_local = `enviro_ext' * (1-`global_split')
// 			local total_global = `enviro_ext' * `global_split' * (1 - ${carbon_`carbon_scale'_`geo'_2020}) + (`enviro_ext' * `global_split' *  ${carbon_`carbon_scale'_`geo'_2020} * (`baseline_scc_2050'/`baseline_scc_2020'))
//			
// 			local carbon_content = ((`anything' *  (`dirty_2020' * `share_dirty_`geo'_2050')) * `global_split') / ${sc_CO2_2020}
			
// 			local carbon_content = `total_global' / ${sc_CO2_2050}
		
	}
}


if "`geo'" != "US" {

	if `ext_year' >= 2020  & `ext_year' <= 2050 { 
		
		if `starting_year' <= 2020 {
			local inflation_year = `starting_year'
		}
		
		if `starting_year' > 2020 {
			local inflation_year = 2020
		}
		
			
			local discount_year = `ext_year' - `starting_year'
			local kwh_emissions = `dirty_2020' * `share_dirty_`geo'_`ext_year''

			local enviro_ext = (`anything' *  (`kwh_emissions' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
			local total_local = `enviro_ext' * (1-`global_split')
			local total_global = `enviro_ext' * `global_split' * (1 - ${carbon_`carbon_scale'_`geo'_2020}) + (`enviro_ext' * `global_split' *  ${carbon_`carbon_scale'_`geo'_2020} * (`baseline_scc_`ext_year''/`baseline_scc_2020'))
			
			local carbon_content = `total_global' / ${sc_CO2_`ext_year'}
	}


	if `ext_year' > 2050 { 
		
		if `starting_year' <= 2020 {
			local inflation_year = `starting_year'
		}
		
		if `starting_year' > 2020 {
			local inflation_year = 2020
		}
		
			local discount_year = `ext_year' - `starting_year'
			local enviro_ext = (`anything' *  (`dirty_2020' * `share_dirty_`geo'_2050' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
			local total_local = `enviro_ext' * (1-`global_split')
			local total_global = `enviro_ext' * `global_split' * (1 - ${carbon_`carbon_scale'_`geo'_2020}) + (`enviro_ext' * `global_split' *  ${carbon_`carbon_scale'_`geo'_2020} * (`baseline_scc_2050'/`baseline_scc_2020'))
			
			local carbon_content = `total_global' / ${sc_CO2_2050}
		
	}
}


if "`ef'" == "high" {
	local geo = "HIGH"
}

if "`ef'" == "low" {
	local geo = "LOW"
}

if `ext_year' <= 2050 & ("`model'" == "static" | "`model'" == "sta") {
	local total_local = (`anything' * ${local_`ef_factor'_`geo'_`starting_year'}) * (1/(1+`discount_rate')^`discount_year')
	
	local total_global = (`anything' * ${global_`ef_factor'_`geo'_`starting_year'}) * (1/(1+`discount_rate')^(`discount_year'))
	
	local carbon_content = (`anything' * ${global_`ef_factor'_`geo'_`starting_year'})/${sc_CO2_`starting_year'}
}

if `ext_year' > 2050 & ("`model'" == "static" | "`model'" == "sta") {
	local total_local = (`anything' * ${local_`ef_factor'_`geo'_2050}) * (1/(1+`discount_rate')^`discount_year')
	
	local total_global = (`anything' * ${global_`ef_factor'_`geo'_2050}) * (1/(1+`discount_rate')^(`discount_year'))
	
	local carbon_content = (`anything' * ${global_`ef_factor'_`geo'_2050})/${sc_CO2_2050}
}


if `negative_kwh' == 1 {
	local total_local = `total_local' * -1
	local total_global = `total_global' * -1
	local carbon_content = `carbon_content' * -1
}

return scalar local_enviro_ext = `total_local'
return scalar global_enviro_ext = `total_global'
return scalar carbon_content = `carbon_content'

end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
