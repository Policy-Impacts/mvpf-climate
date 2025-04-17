****************************************************************
*Creating an Ado file for a dynamic grid
*Input the annual kwh, starting year, and number of years
*It will output total local and global environmental externality
*Old file without updated coal/ng change
****************************************************************

cap prog drop dynamic_grid_v2
prog def dynamic_grid_v2, rclass


syntax anything, /// annual kwh
	starting_year(integer) /// 
	lifetime(integer) /// lifetime of appliance/program
	discount_rate(real) ///
	ef(string) /// either marginal, average, high, or low
	geo(string) /// either US or other state abbreviation
	[type(string) /// if marginal, then this is either solar, wind, or uniform
	 grid_specify(string) /// either "yes" or "no"
	 model(string) /// either "optimistic" "conservative" "frozen" "midpoint" or "static"
	]
	
*Override US grid if we are running a robustness specification on new grid
if "${change_grid}" != "" {
	local geo = "${change_grid}"
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

local negative_kwh = 0

if `anything' < 0 {
	local anything = `anything' * -1
	local negative_kwh = 1
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

preserve
import excel "${policy_assumptions}", first clear sheet("princeton_grid")

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
	import excel "${assumptions}/grid_pollution", first clear sheet("2020_dirty_share")
	qui sum combustion_percent if State == "`geo'"
	local share_dirty_`geo'_2020 = `r(mean)'
	restore
	
	forvalues y = 2021(1)2050 {
		local year_before = `y' - 1
		local share_dirty_`geo'_`y' = ((`share_dirty_US_`y'' - `share_dirty_US_`year_before'')/`share_dirty_US_`year_before'') * `share_dirty_`geo'_`year_before'' + `share_dirty_`geo'_`year_before''
	}
	
}

local dirty_2020 = (1/`share_dirty_`geo'_2020') * `enviro_ext_2020' // This is the externality if the entire 2020 grid was from fossil fuels


local ending_year = `starting_year' + `lifetime' - 1

*If the starting year is less than 2020, get the externality for the years before 2020
if "`ef'" == "high" {
	local geo = "HIGH"
}

if "`ef'" == "low" {
	local geo = "LOW"
}
if `starting_year' < 2020 {
	if `starting_year' + `lifetime' > 2020 {
		local years_with_data = 2020 - `starting_year'
		local first_ending_year  = `starting_year' + `years_with_data' - 1
	}
	
	if `starting_year' + `lifetime' <= 2020 {
		local first_ending_year  = `ending_year'
	}

	forvalues t = `starting_year'(1)`first_ending_year' {
		local discount_year = `t' - `starting_year' + 1
		local local_enviro_ext = (`anything' *  ${local_`ef_factor'_`geo'_`t'} * (${cpi_`starting_year'}/${cpi_`t'})) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
		local global_enviro_ext = (`anything' *  ${global_`ef_factor'_`geo'_`t'} * (${cpi_`starting_year'}/${cpi_`t'})) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
		local carbon_content_ext = ((`anything' *  ${global_`ef_factor'_`geo'_`t'})/${sc_CO2_`t'})

		local total_local = `total_local' + `local_enviro_ext'
		local total_global = `total_global' + `global_enviro_ext'
		local carbon_content = `carbon_content' + `carbon_content_ext'
	}
}

*Get the externality for the years after 2020
if "`ef'" == "high" {
	local geo = "${state_dirty_2020}"
}

if "`ef'" == "low" {
	local geo = "${state_clean_2020}"
}

if `starting_year' + `lifetime' > 2020 {
	
	if `starting_year' <= 2020 {
		local start = 2020
		local inflation_year = `starting_year'
	}
	
	if `starting_year' > 2020 {
		local start = `starting_year'
		local inflation_year = 2020
	}
	
	forvalues y = `start'(1)`ending_year' {
		local discount_year = `y' - `starting_year' + 1
		if `y' > 2050 {
			local share_dirty_`geo'_`y' = `share_dirty_`geo'_2050'
		}
		local enviro_ext = (`anything' *  (`dirty_2020' * `share_dirty_`geo'_`y'' * (${cpi_`inflation_year'}/${cpi_2020}))) * (1/(1+`discount_rate')^`discount_year') // anything is the annual kwh
		
		local carbon_content_ext = (`enviro_ext' * `global_split' *  ${carbon_`carbon_scale'_`geo'_2020} * (`baseline_scc_`y''/`baseline_scc_2020')) /${sc_CO2_`y'}
		
		local total_local = `total_local' + `enviro_ext' * (1-`global_split')
// 		local global_inter = `global_inter' + `enviro_ext' * `global_split'
		local total_global = `total_global' + `enviro_ext' * `global_split' * (1 - ${carbon_`carbon_scale'_`geo'_2020}) + (`enviro_ext' * `global_split' *  ${carbon_`carbon_scale'_`geo'_2020} * (`baseline_scc_`y''/`baseline_scc_2020'))
		local carbon_content = `carbon_content' + `carbon_content_ext'
	}
}

if "`ef'" == "high" {
	local geo = "HIGH"
}

if "`ef'" == "low" {
	local geo = "LOW"
}

if "`model'" == "static" | "`model'" == "sta" {
	local total_local = (`anything' * ${local_`ef_factor'_`geo'_`starting_year'}/`discount_rate') * (1 - (1/(1+`discount_rate')^(`lifetime')))
	
	local total_global = (`anything' * ${global_`ef_factor'_`geo'_`starting_year'}/`discount_rate') * (1 - (1/(1+`discount_rate')^(`lifetime')))
	
	local carbon_content = (`anything' * ${global_`ef_factor'_`geo'_`starting_year'} * `lifetime')/${sc_CO2_`starting_year'}
}

if `negative_kwh' == 1 {
	local total_local = `total_local' * -1
	local total_global = `total_global' * -1
	local carbon_content = `carbon_content' * -1
}

return scalar local_enviro_ext = `total_local'
return scalar global_enviro_ext = `total_global'
return scalar carbon_content = `carbon_content'

di `total_local'
di `total_global'
di `carbon_content'

end
