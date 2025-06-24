*Check if the user is running alternative specifications
local alternative_spec = ""

if "${renewables_loop}" == "yes" {
	local alternative_spec = "_${renewables_percent}"
}

tempname wind_enviro_ext
postfile `wind_enviro_ext' str18 policy year enviro_ext local_ext global_ext using "${assumptions}/timepaths/wind_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", replace 

forvalues y = 2006(1)2045 {
	local discount = 0.02
	local replacement = "marginal"
	local dollar_year = `y'
*Wind Environment Externality
	preserve
		import excel "${policy_assumptions}", first clear sheet("Wind")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local lifetime = ${lifetime}
		local capacity_factor = ${capacity_factor} // capacity factor for wind
		local average_size = ${average_size}
		local credit_life = ${credit_life}
		local current_ptc = ${current_ptc}
		local capacity_reduction = ${capacity_reduction}
		local wind_emissions = ${wind_emissions}

	restore
	
	local hrs = 8760 // hours per year
	local corporate_disc = `discount'

	local annual_kwh = `average_size' * `hrs'*`capacity_factor' * 1000 // After the first ten years we need to scale this down by the capacity reduction factor

	rebound ${rebound}
	local r = `r(r)'

	* Social Costs
	dynamic_grid `annual_kwh', starting_year(`y') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // First 10 years
	local f10_local_pollutants = `r(local_enviro_ext)'
	local f10_global_pollutants = `r(global_enviro_ext)'
	local carbon = `r(carbon_content)'
		
	local new_annual_kwh = (1 - `capacity_reduction') * `annual_kwh'

	dynamic_grid `new_annual_kwh', starting_year(`y') lifetime(`lifetime') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // Total 20 years
	local t20_local_pollutants = `r(local_enviro_ext)'
	local t20_global_pollutants = `r(global_enviro_ext)'
	local carbon = `carbon' + `r(carbon_content)'

	dynamic_grid `new_annual_kwh', starting_year(`y') lifetime(`credit_life') discount_rate(`discount') ef("`replacement'") type("wind") geo("${State}") grid_specify("yes") model("${grid_model}") // First 10 years with lower capacity factor
	local inter_local_pollutants = `r(local_enviro_ext)'
	local inter_global_pollutants = `r(global_enviro_ext)'
	local carbon = `carbon' - `r(carbon_content)'

	local local_pollutants = `f10_local_pollutants' + (`t20_local_pollutants' - `inter_local_pollutants')
	local global_pollutants = `f10_global_pollutants' + (`t20_global_pollutants' - `inter_global_pollutants')

	local sc_cost_2020 = ${sc_CO2_`dollar_year'} * ${cpi_`dollar_year'}/${cpi_${sc_dollar_year}} // SCC for year of interest converted to correct dollar year.

	local env_cost = ((`wind_emissions' * 1/1000000 * `annual_kwh' * `credit_life') + (`wind_emissions' * 1/1000000 * `annual_kwh' * (1 - `capacity_reduction') * (`lifetime' - `credit_life'))) * `sc_cost_2020'	
	
	if `y' < 2020 {
		local local_ext = (`local_pollutants' - ((`local_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'}
		local global_ext = (`global_pollutants' - `env_cost' - ((`global_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'}
		local enviro_ext = (`local_pollutants' + `global_pollutants' - `env_cost' - ((`local_pollutants' + `global_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'} // externality for the system to use in cost curve estimate
	}
	if `y' >= 2020 {
		local local_ext = (`local_pollutants' - ((`local_pollutants') * (1-`r')))
		local global_ext = (`global_pollutants' - `env_cost' - ((`global_pollutants') * (1-`r')))
		local enviro_ext = `local_pollutants' + `global_pollutants' - `env_cost' - ((`local_pollutants' + `global_pollutants') * (1-`r'))
	}

	
	post `wind_enviro_ext' ("Wind") (`y') (`enviro_ext') (`local_ext') (`global_ext')
}


postclose `wind_enviro_ext'	
use "${assumptions}/timepaths/wind_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", clear
save "${assumptions}/timepaths/wind_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", replace