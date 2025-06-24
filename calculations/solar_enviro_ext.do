*Check if the user is running alternative specifications
local alternative_spec = ""

if "${renewables_loop}" == "yes" {
	local alternative_spec = "_${renewables_percent}"
}


tempname solar_enviro_ext
postfile `solar_enviro_ext' str18 policy year enviro_ext local_ext global_ext using "${assumptions}/timepaths/solar_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", replace 

local solar_lca_co2e = 40 / 1000000 // in g/kWh, so need to divide by 1e6 to get t/kWh

forvalues y = 2006(1)2045 {
	local discount = 0.02
	local replacement = "marginal"
	local dollar_year = `y'

	preserve
			import excel "${policy_assumptions}", first clear sheet("Solar")
			
			levelsof Parameter, local(levels)
			foreach val of local levels {
				qui sum Estimate if Parameter == "`val'"
				global `val' = `r(mean)'
			}
			
			local system_capacity = ${system_capacity}
			local annual_output = ${output} / (`system_capacity' * 1000)
			local lifetime = ${lifetime}
			local marginal_val = ${marginal_val}
			local federal_subsidy = 0.3
		restore

	local annual_kwh = `system_capacity' * `annual_output' * 1000

	* Social Costs

	dynamic_grid `annual_kwh', starting_year(`dollar_year') lifetime(`lifetime') discount_rate(`discount') ef("marginal") type("solar") geo("${State}") grid_specify("yes") model("${grid_model}")
	local local_pollutants = `r(local_enviro_ext)'
	local global_pollutants = `r(global_enviro_ext)'
	local carbon = `r(carbon_content)'

	rebound ${rebound}
	local r = `r(r)'
	
	local lca_annual = `annual_kwh' * `solar_lca_co2e' * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_2020}))
	
	local lca_ext = `lca_annual' + (`lca_annual'/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1 )))

	if `y' < 2020 {
		local local_ext = (`local_pollutants' - ((`local_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'}
		local global_ext = (`global_pollutants' - `lca_ext' - ((`global_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'}
		local enviro_ext = (`local_pollutants' + `global_pollutants' - `lca_ext' - ((`local_pollutants' + `global_pollutants') * (1-`r'))) * ${cpi_2020}/${cpi_`y'} // externality for the system to use in cost curve estimate
	}
	if `y' >= 2020 {
		local local_ext = (`local_pollutants' - ((`local_pollutants') * (1-`r')))
		local global_ext = (`global_pollutants' - `lca_ext' - ((`global_pollutants') * (1-`r')))
		local enviro_ext = (`local_pollutants' + `global_pollutants' - `lca_ext' - ((`local_pollutants' + `global_pollutants') * (1-`r'))) // externality for the system to use in cost curve estimate
	}

	post `solar_enviro_ext' ("Solar") (`y') (`enviro_ext') (`local_ext') (`global_ext')
}

postclose `solar_enviro_ext'	
use "${assumptions}/timepaths/solar_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", clear
save "${assumptions}/timepaths/solar_externalities_time_path_${scc_ind_name}_age25`alternative_spec'.dta", replace