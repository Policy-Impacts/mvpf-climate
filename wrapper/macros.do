/***************************************************************************
 *           MACROS FILE FOR MVPF ENVIRONMENTAL PROJECT                    *
 ***************************************************************************
 
    This file generates the needed macros (namely, externalities) that
	policy-specific .do files use. This file allows you to either, (a)
	require datasets to be re-generated, or (b) to pull existing pre-run 
	datasets, provided they exist. It saves user-specific versions of datasets.
	
	NOTE: Toggles must be set before running this file. This file will not
	re-run datasets unless rerun_macros is set to "yes" or rerun_timepaths is 
	set to "yes". 
	
****************************************************************************/

global rerun_macros "no"

if "`1'" != ""{
	global rerun_macros "`1'" // if running macros.do through metafile.do
	di in red "Rerun macros set to ${rerun_macros} through a positional argument"
} 


global EV_VMT_car_adjustment_ind = round(${EV_VMT_car_adjustment}, .001)

check_timepaths check // Check if timepaths for learning by doing already exist
di in red "Rerun timepaths set to ${rerun_timepaths}"

// global rerun_timepaths "no"
// if fileexists("${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${ev_grid}.dta") != 1{
// 	global rerun_timepaths "yes"
//
// 	if "${scc}" == "" | "${vehicle_car_lifetime}" == "" | "{EV_VMT_car_adjustment_ind}" == "" | "${ev_grid}" == ""{
// 		if fileexists("${assumptions}/timepaths/ev_externalities_time_path_193_age17_vmt.615_gridUS.dta") == 1{
// 			global rerun_timepaths "no"
// 		}
// 		di in red "Rerun timepaths set to ${rerun_timepaths} because the globals are blank and the default timepaths exist"
// 	}
// 	else{
// 		di in red "Rerun timepaths set to ${rerun_timepaths} based on whether the file already exists"
// 	}
// }
//
// if "${rerun_timepaths}" == "yes" {
//	
// 	global ev_simulation_max_year 2050
// 	global rerun_macros 	"yes" // Rerun macros if saving timepaths. 
//
// 	di in red "Rerun macros set to ${rerun_macros} based on what rerun timepaths is set to"
//	
// }
//
//
// if "${rerun_timepaths}" == "no" {
//	
// 	global ev_simulation_max_year 2022
//	
// }

cap mkdir "${user_specific_assumptions}/files_v${user_name}"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/Diesel Externalities"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/EV Charging"
cap mkdir "${user_specific_assumptions}/files_v${user_name}/New Vehicle Externalities"

if "${rerun_macros}" == ""{
	global rerun_macros "no" // set this to yes for rep packet
	di in red "Rerun macros wasn't defined, so now it's set to no"
} 

if "${vehicle_lifetime_change}" == "yes" | "${car_change_ev}" == "yes" | "${car_change}" == "yes" | "${change_vmt_rebound}" == "yes"{
	global rerun_macros = "yes"
}

* Rerun macros after resetting globals from above to no, these are the specs following the 4 above.

if "${constant_semie}" == "yes" | "${incr_appliance_lifetimes}" == "yes" | "${vehicle_mar_val_chng}" == "yes"{
	global rerun_macros = "yes"
}


***************************************************************************************************************
/*                                0 - Run .ADO Files to Create Project Macros.                               */
***************************************************************************************************************	
cap qui do "${github}/ado/run_program.ado"

// Electricity Files
qui do "${github}/ado/dynamic_split_grid.ado"
qui do "${github}/ado/dynamic_grid.ado"
qui do "${github}/ado/dynamic_grid_v2.ado"
qui do "${github}/ado/rebound.ado"
	
// Types of MVPFs
qui do "${github}/ado/gas_tax.ado"
qui do "${github}/ado/vehicle_retirement.ado"
qui do "${github}/ado/wind_ado.ado"
qui do "${github}/ado/weatherization_ado.ado"
qui do "${github}/ado/solar.ado"


// Learning-by-Doing
qui do "${github}/cost_curve/cost_curve_masterfile.ado"

***************************************************************************************************************
/*           1 - Save Parameters That Do NOT Depend on SCC or Discount Rate, nor Creates New Files.          */
***************************************************************************************************************

*-----------------------------------------------------------------------
* 1a - Save CPI Globals.
*-----------------------------------------------------------------------
if "${rerun_macros}" == "yes" | "${cpi_2020}" == "" {
	
	local object_of_interest = "CPI Globals"
	
	if "${rerun_macros}" == "yes" {
		di in red "Asked to Resave `object_of_interest'"
	}
	if "${cpi_2020}" == "" {
		di in red "Saving CPI Globals because Currently Undefined."
	}
	
	qui {
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
		
	}
	
}

*-----------------------------------------------------------------------
* 1b - Define VMT Rebound.
*-----------------------------------------------------------------------
if "${rerun_macros}" == "yes" | "${vmt_rebound_elasticity}" == "" {
	
	local object_of_interest = "VMT Rebound"
	
	if "${rerun_macros}" == "yes" {
		di in red "Asked to Resave `object_of_interest'"
	}
	if "${vmt_rebound_elasticity}" == "" {
		di in red "Saving `object_of_interest' because Currently Undefined."
	}
	
	qui {
	
		import excel "${policy_assumptions}", first clear sheet("driving_parameters")
		sum estimate if parameter == "rebound_elasticity"
		global vmt_rebound_elasticity = r(mean)
	
	}
	
}

if "${change_vmt_rebound}" == "yes" {
	
	global vmt_rebound_elasticity = -0.000001 
}

*-----------------------------------------------------------------------
* 1c - Save Preferred EV Price Elasticity (for Gas Tax Learning-by-Doing).
*-----------------------------------------------------------------------
if "${rerun_macros}" == "yes" | "${gtcc_epsilon}" == "" {
	
	local object_of_interest = "EV Price Elasticity (Gas Tax LBD)"
	
	if "${rerun_macros}" == "yes" {
		di in red "Asked to Resave `object_of_interest'"
	}
	if "${gtcc_epsilon}" == "" {
		di in red "Saving `object_of_interest' because Currently Undefined."
	}
	
	qui {
		
		import excel "${causal_ests}/muehl_efmp.xlsx", clear  sheet("wrapper_ready") firstrow
		qui sum pe if estimate == "epsilon"
		if r(mean) > 0 {
			global gtcc_epsilon = r(mean) * -1
		}
		else {
			global gtcc_epsilon = r(mean)
		}
	
	}
	
}

*-----------------------------------------------------------------------
* 1d - Gasoline Prices, Taxes, and Markups.
*-----------------------------------------------------------------------
local object_of_interest = "Gasoline Prices, Taxes, and Markups"
	
if "${rerun_macros}" == "yes" {
	
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/gas_prices_taxes_markups"
	
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear

	* Save (nominal) prices as globals.
	qui levelsof(year), local(price_loop)
	foreach y of local price_loop {
		
		qui sum gas_price if year == `y'
		global nominal_gas_price_`y' = r(mean)
			
		qui sum avg_tax_rate if year == `y'
		global nominal_gas_tax_`y' = r(mean)
			
		qui sum markup if year == `y'
		global nominal_gas_markup_`y' = r(mean)
			
		qui sum gas_consumed_ldv if year == `y'
		global gasoline_consumed_ldv_`y' = r(mean)
	
	}
	
	forval y = 2023(1)2050{
		
		global nominal_gas_price_`y' = ${nominal_gas_price_2020}
		global nominal_gas_tax_`y' = ${nominal_gas_tax_2020}
		global nominal_gas_markup_`y' = ${nominal_gas_markup_2020}

	}
	
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final.dta") != 1 {
	di in red "Rerunning `object_of_interest' because Data Not Found."
	qui do "${calculation_files}/gas_prices_taxes_markups"
		
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear

	* Save (nominal) prices as globals.
	qui levelsof(year), local(price_loop)
	foreach y of local price_loop {
		
		qui sum gas_price if year == `y'
		global nominal_gas_price_`y' = r(mean)
			
		qui sum avg_tax_rate if year == `y'
		global nominal_gas_tax_`y' = r(mean)
			
		qui sum markup if year == `y'
		global nominal_gas_markup_`y' = r(mean)
			
		qui sum gas_consumed_ldv if year == `y'
		global gasoline_consumed_ldv_`y' = r(mean)
	}
	
}

if "${nominal_gas_price_2020}" == "" {
	
	di in red "Running `object_of_interest' because Macros Undefined."
	
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear

	* Save (nominal) prices as globals.
	qui levelsof(year), local(price_loop)
	foreach y of local price_loop {
		
		qui sum gas_price if year == `y'
		global nominal_gas_price_`y' = r(mean)
			
		qui sum avg_tax_rate if year == `y'
		global nominal_gas_tax_`y' = r(mean)
			
		qui sum markup if year == `y'
		global nominal_gas_markup_`y' = r(mean)
			
		qui sum gas_consumed_ldv if year == `y'
		global gasoline_consumed_ldv_`y' = r(mean)

	}
	
}
	
*-----------------------------------------------------------------------
* 1e - Run VMT Files.
*-----------------------------------------------------------------------
local object_of_interest = "Vehicle VMT Datasets"
	
if "${rerun_macros}" == "yes" {
	
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/vmt"
	
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta") != 1 {
	
	di in red "Rerunning `object_of_interest' because Data Not Found."
	qui do "${calculation_files}/vmt"		
	
}
		


***************************************************************************************************************
/*                       2 - Save Project-wide Macros (Social Costs, Discount Rate, VSL).                    */
***************************************************************************************************************	

*-----------------------------------------------------------------------
* 2a - Import Default Assumptions Spreadsheet and Save Toggles as Globals.
*-----------------------------------------------------------------------
import excel "${default_assumptions}", clear first sheet("SELECTIONS")
qui ds
foreach assumption in `r(varlist)' {
	
	global `assumption' = `assumption'
	
}

if ${scc} == 193{
	global discount_rate = 0.02
}
else if ${scc} == 76{
	global discount_rate = 0.025
}
else if ${scc} == 337{
	global discount_rate = 0.015
}
else if ${scc} == 1367{
	global discount_rate = 0.02
}
*-----------------------------------------------------------------------
* 2b - Social Cost of Carbon, Methane, and Nitrous Oxide.
*-----------------------------------------------------------------------	
import excel "${default_assumptions}", first clear sheet("${scc}")
qui sum sc_CO2 if year == 2020
assert round(r(mean), 1) == ${scc}
			
qui levelsof year, local(years)
foreach y in `years'{

	qui ds sc*
	foreach var in `r(varlist)' {
	
		qui sum `var' if year == `y'
		global `var'_`y' = r(mean) // All expressed in 2020 dollars. 
		
		qui sum sc_dollar_year
		global sc_dollar_year = r(mean)
		assert ${sc_dollar_year} == r(mean)
	
	}	
	
}

global dr_rounded = round(($discount_rate * 100), 0.01)
global dr_ind_name "dr${dr_rounded}"
di in red "Discount Rate is ${dr_rounded}%"
global scc_ind_name = "scc${scc}"
di in red "Social Cost of Carbon is $${scc}"
di in red "Grid Type is ${grid_model}"
sleep 2000
global scc_import_check = ${scc}
*-----------------------------------------------------------------------
* 2c - Social Cost of Local Pollutants.
*-----------------------------------------------------------------------	
local md_types unweighted weighted
foreach type of local md_types {

	qui import excel "${default_assumptions}", first clear sheet("${MD_toggle}_`type'")

	qui levelsof(year), local(year_loop)
	foreach y of local year_loop {
	
		qui ds md_*
		foreach var in `r(varlist)' {
		
			qui sum `var' if year == `y'
			global `var'_`y'_`type' = r(mean) // AP3 expressed in 2006 dollars.
			
			qui sum dollar_year 
			global md_dollar_year = r(mean)
			qui assert ${md_dollar_year} == r(mean)
		
		}
	
	}

}

global md_import_check = round(${md_NOx_2020_unweighted} * (${cpi_2020}/${cpi_${md_dollar_year}}), 1)

***************************************************************************************************************
/*              3 - Save Macros That Require Calculations and Vary with Project-wide Assumptions.            */
***************************************************************************************************************
	
*-----------------------------------------------------------------------
* 3a - Electricity and Natural Gas Externalities.
*-----------------------------------------------------------------------
local object_of_interest = "Electricity and Natural Gas Externalities"

if "${rerun_macros}" == "yes" {
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${github}/calculations/gas_electricity_externalities"
}

*If we need to switch grids, override the US grid with the new grid*
if "${change_grid}" != "" {
	forvalues y = 2004(1)2021 {
		foreach var in "wind" "solar" "portfolio" "uniform" {
			global global_`var'_US_`y' = ${global_`var'_${change_grid}_`y'}
			global local_`var'_US_`y' =  ${local_`var'_${change_grid}_`y'} 
		}
	}
}

global renewables_2020 = 0.1952 // EPA eGRID renewables % (including Hydro)

if "${renewables_loop}" == "yes" {
	forvalues y = 2004(1)2021 {
		foreach var in "wind" "solar" "portfolio" "uniform" {
			global global_`var'_US_`y' = (${global_`var'_US_`y'} * (1 - ${renewables_percent})) / (1 - ${renewables_2020}) 
			global local_`var'_US_`y' =  (${local_`var'_US_`y'} * (1 - ${renewables_percent})) / (1 - ${renewables_2020}) 
		}
	}
}

if "${last_run_scc_save}" == "" | "${last_run_md_save}" == "" {
	di in red "Rerunning `object_of_interest' because Macros Undefined."
	qui do "${github}/calculations/gas_electricity_externalities"
}

if ("${last_run_scc_save}" != "${scc}") | ("${last_run_md_save}" != "${md_import_check}") {
	di in red "Rerunning `object_of_interest' because Project-wide Macros Have Changed."
	qui do "${github}/calculations/gas_electricity_externalities"
}

*-----------------------------------------------------------------------
* 3b - Gasoline Vehicle Externalities.
*-----------------------------------------------------------------------
local object_of_interest = "Gasoline Vehicle Externalities"
	
if "${rerun_macros}" == "yes" {
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/gas_vehicle_externalities"
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta") != 1 {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Data Not Found."
	qui do "${calculation_files}/gas_vehicle_externalities"
}

if "${CO2_per_gallon}" == "" {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Macros Not Found."
	qui do "${calculation_files}/gas_vehicle_externalities"			
}

use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", clear

levelsof(year), local(year_loop)
foreach y of local year_loop {
		
	preserve

		qui keep if year == `y'
		
		qui sum wtp_total if year == `y'
		global gas_ldv_ext_`y' = r(mean)
		
		qui sum wtp_local if year == `y'
		global gas_ldv_ext_local_`y' = r(mean)
			
		local wtp_local_no_vmt_ext = wtp_local - wtp_accidents - wtp_congestion - wtp_PM25_TBW
		global gas_ldv_ext_local_no_vmt_`y' = `wtp_local_no_vmt_ext'
			
		qui sum wtp_global if year == `y'
		global gas_ldv_ext_global_`y' = r(mean)
		
		assert round(${gas_ldv_ext_`y'}, 0.001) == round(${gas_ldv_ext_local_`y'} + ${gas_ldv_ext_global_`y'}, 0.001)
		
		qui sum mpg if year == `y'
		global gas_ldv_avg_mpg_`y' = r(mean)
		
		qui sum CO2_total if year == `y'
		global gas_ldv_CO2_abated_`y' = r(mean)
			
	restore		

}

*-----------------------------------------------------------------------
* 3c - Diesel Vehicle Externalities.
*-----------------------------------------------------------------------
local object_of_interest = "Diesel Externalities"

if "${rerun_macros}" == "yes" {
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/diesel_vehicle_externalities"
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Diesel Externalities/diesel_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta") != 1 {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Data Not Found."
	qui do "${calculation_files}/diesel_vehicle_externalities"
}

use "${user_specific_assumptions}/files_v${user_name}/Diesel Externalities/diesel_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", clear

qui levelsof(year), local(year_loop)
foreach y of local year_loop {
		
	qui sum wtp_total if year == `y'
	global diesel_ext_`y' = r(mean)
		
	qui sum wtp_local if year == `y'
	global diesel_ext_local_`y' = r(mean)
		
	qui sum wtp_global if year == `y'
	global diesel_ext_global_`y' = r(mean)		
		
	qui sum CO2_total if year == `y'
	global diesel_CO2_abated_`y' = r(mean)
		
}
	
		
***************************************************************************************************************
/* 4 -  Run Externality Calculations that Depend on Earlier Calculations (EVs, Hybrids, Vehicle Retirement). */
***************************************************************************************************************

*-----------------------------------------------------------------------
* 4a - Lifetime Vehicle Damages. 
*-----------------------------------------------------------------------
local object_of_interest = "Benefits from Not Driving Gasoline-powered Vehicle"
	
if "${rerun_macros}" == "yes" {
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/lifetime_vehicle_externalities"
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta") != 1 {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Data Not Found."
	qui do "${calculation_files}/lifetime_vehicle_externalities"
}

if "${vehicle_car_lifetime}" == "" {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Data Not Found."
	qui do "${calculation_files}/lifetime_vehicle_externalities"
}

* ${hev_cf} in the file name tells you with respect to which counterfactual the hybrid rebound is calculated
use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", clear

	
local cf_types new_avg new_car clean_car muehl hybrid	

levelsof(year), local(year_loop)
foreach y of local year_loop {
	foreach c of local cf_types{
		
		if "`c'" == "${bev_cf}" {
			
			local veh_lifespan_type = substr("`c'", strpos("`c'", "_") + 1, .)

			
			qui sum `c'_local if year == `y'
			global `c'_cf_damages_loc_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}

			qui sum `c'_global if year == `y' 
			global `c'_cf_damages_glob_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}

			qui sum `c'_CO2 if year == `y'
			global `c'_cf_carbon_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}

			qui sum `c'_taxes if year == `y'
			global `c'_cf_gas_fisc_ext_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}
			
			qui sum `c'_savings if year == `y'
			global `c'_cf_gas_savings_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}

			qui sum `c'_profits if year == `y'
			global `c'_wtp_prod_s_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}

			qui sum `c'_gallons if year == `y'
			global `c'_gal_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}
			
			qui sum `c'_local_driving if year == `y'
			global `c'_driving_`y' = r(mean) * ${EV_VMT_`veh_lifespan_type'_adjustment}
			
			qui sum `c'_mpg if year == `y'
			global `c'_cf_mpg_`y' = r(mean)
			
		}
		if "`c'" != "${bev_cf}" {
			
			qui sum `c'_local if year == `y' // for hybrids, includes rebound effect
			global `c'_cf_damages_loc_`y' = r(mean) // for hybrids, includes rebound effect

			qui sum `c'_global if year == `y' // for hybrids, includes rebound effect
			global `c'_cf_damages_glob_`y' = r(mean) // for hybrids, includes rebound effect

			qui sum `c'_CO2 if year == `y'
			global `c'_cf_carbon_`y' = r(mean)

			qui sum `c'_taxes if year == `y'
			global `c'_cf_gas_fisc_ext_`y' = r(mean)
			
			qui sum `c'_savings if year == `y'
			global `c'_cf_gas_savings_`y' = r(mean)

			qui sum `c'_profits if year == `y'
			global `c'_wtp_prod_s_`y' = r(mean)

			qui sum `c'_gallons if year == `y'
			global `c'_gal_`y' = r(mean)
			
			qui sum `c'_local_driving if year == `y'
			global `c'_driving_`y' = r(mean)
			
			qui sum `c'_mpg if year == `y'
			global `c'_cf_mpg_`y' = r(mean)
			
		}

		if "`c'" == "hybrid"{
			qui sum hybrid_rbd_local if year == `y'
			global yes_hev_rbd_loc_`y' = r(mean)

			qui sum hybrid_rbd_global if year == `y'
			global yes_hev_rbd_glob_`y' = r(mean)

			qui sum hybrid_rbd_CO2 if year == `y' // just the amount of carbon from the rebound effect, only relevant for hybrids
			global hybrid_rbd_CO2_`y' = r(mean)
		}

	}
	
}

*-----------------------------------------------------------------------
* 4b - Electric Vehicle Charging Damages. 
*-----------------------------------------------------------------------
local object_of_interest = "Damages from Charging Electric Vehicles"

if "${rerun_macros}" == "yes" {
	di in red "Asked to Rerun `object_of_interest'"
	qui do "${calculation_files}/ev_externalities"
}

if fileexists("${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/EV Charging/ev_charging_${grid_model}_${replacement}_${scc_ind_name}_${dr_ind_name}.dta") != 1 {
	di in red "Rerunning `object_of_interest' for SCC of $${scc} and Discount Rate of ${dr_rounded}% because Data Not Found."
	qui do "${calculation_files}/ev_externalities"
}
	
use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/EV Charging/ev_charging_${grid_model}_${replacement}_${scc_ind_name}_${dr_ind_name}.dta", clear
keep year grid_ext_${ev_VMT_assumption}* grid_charging_${ev_VMT_assumption}*

levelsof(year), local(year_loop)
foreach y of local year_loop {
		
	// Charging Externalities INCLUDING Rebound Effect.
	qui sum grid_ext_${ev_VMT_assumption}_local if year == `y' // includes rebound effect
	global yes_ev_damages_local_`y' = r(mean)
		
	qui sum grid_ext_${ev_VMT_assumption}_global if year == `y' // includes rebound effect
	global yes_ev_damages_global_`y' = r(mean)
		
	qui sum grid_ext_${ev_VMT_assumption}_CO2 if year == `y'
	global yes_ev_carbon_content_`y' = r(mean)

	qui sum grid_ext_${ev_VMT_assumption}_rbd_CO2 if year == `y' // just the amount of carbon from the rebound effect
	global yes_ev_rbd_CO2_`y' = r(mean)					
		
	// Charging Externalities NOT INCLUDING Rebound Effect.
	qui sum grid_ext_${ev_VMT_assumption}_local_no_r if year == `y'
	global yes_ev_damages_local_no_r_`y' = r(mean) // does NOT include rebound effect

	qui sum grid_ext_${ev_VMT_assumption}_global_no_r if year == `y'
	global yes_ev_damages_global_no_r_`y' = r(mean) // does NOT include rebound effect

		
	// Charging Externalities JUST Rebound Effect.
	qui sum grid_ext_${ev_VMT_assumption}_rbd_total if year == `y' // both global and local pollutants
	global yes_ev_rbd_`y' = r(mean)

	qui sum grid_ext_${ev_VMT_assumption}_rbd_local if year == `y'
	global yes_ev_rbd_l_`y' = r(mean)

	qui sum grid_ext_${ev_VMT_assumption}_rbd_global if year == `y'
	global yes_ev_rbd_g_`y' = r(mean)
	
	// Charging Externalities for Utilities.
	qui sum grid_charging_${ev_VMT_assumption}_revenue if year == `y'
	global yes_ev_utility_taxes_`y' = r(mean)
	
	qui sum grid_charging_${ev_VMT_assumption}_profits if year == `y'
	global yes_ev_utility_profits_`y' = r(mean)	
	
	qui sum grid_charging_${ev_VMT_assumption}_savings if year == `y'
	global yes_ev_savings_`y' = r(mean)
	
	if inlist(`y', 2021, 2022) { // Convert these globals to nominal to match vehicle externalities. Grid files output years past 2020 all in 2020 dollars.
	
		global yes_ev_damages_local_`y' = ${yes_ev_damages_local_`y'} * (${cpi_`y'} / ${cpi_2020})
		global yes_ev_damages_global_`y' = ${yes_ev_damages_global_`y'} * (${cpi_`y'} / ${cpi_2020})
		
		global yes_ev_damages_local_no_r_`y' = ${yes_ev_damages_local_no_r_`y'} * (${cpi_`y'} / ${cpi_2020})
		global yes_ev_damages_global_no_r_`y' = ${yes_ev_damages_global_no_r_`y'} * (${cpi_`y'} / ${cpi_2020})			
	
	}	
	
}

global gasoline_effective_corp_tax = 0.21

*-----------------------------------------------------------------------
* 4c - Save Timepaths (if Toggled). 
*-----------------------------------------------------------------------
if "${rerun_timepaths}" == "yes" {
	
	use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/EV Charging/ev_charging_${grid_model}_${replacement}_${scc_ind_name}_${dr_ind_name}.dta", clear
	merge 1:1 year using "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", nogen noreport keep(3)
	drop hybrid* muehl*
	keep year grid_ext_car_local* grid_ext_car_global* grid_ext_avg_local* grid_ext_avg_global* *_global *_local 
	drop *_no_r *rbd*
			
	// Vehicle Externalities from 2011 through 2023 in Nominal Dollars. Converting to 2020 dollars.
	ds new_car* new_avg* clean_car*
	foreach var in `r(varlist)' {
		
		levelsof(year), local(y_loop)
		foreach y of local y_loop {
			
			replace `var' = `var' * (${cpi_2020} / ${cpi_`y'}) if year == `y'
			
		}
		
	}
	
	// Accounting for damages from battery production.
	local ev_manufacturing_emissions = (59.5 / 1000) // Initially in kilograms per KWh, going to tons per KWh. 59.5 from Winjobi et al. (2022)
	gen CO2_battery_production = .
	
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		// PULL IN BATTERY CAPACITY
		preserve
			use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
			
			if `y' <= 2020 {
				
				qui sum avg_batt_cap if year == `y'
				local battery_cap = r(mean)
				
			}
			if `y' > 2020 {
				
				qui sum avg_batt_cap if year == 2020
				local battery_cap = r(mean)
				
			}
		restore

		replace CO2_battery_production = (`ev_manufacturing_emissions' * `battery_cap' * ${sc_CO2_`y'}) if year == `y' // SCC already in 2020 dollars.

	}
	
	// Grid Values before 2020 in Nominal Dollars; All after 2020 in 2020 dollars.
	ds grid*
	foreach var in `r(varlist)' {
		
		foreach y of local year_loop {
			
			if `y' < 2020 {
				
				replace `var' = `var' * (${cpi_2020} / ${cpi_`y'}) if year == `y' // Inflate to 2020 dollars if earlier than 2020.
				
			}
			
			if `y' >= 2020 {
				
				continue // Years 2020 onward already expressed in 2020 dollars.
				
			}
			
		}
		
	}
	
	
	// BENEFITS WHEN USING EVs WITH CAR VMT
	gen benefits_global_clean_car_cf = (clean_car_global * ${EV_VMT_car_adjustment}) - (grid_ext_car_global + CO2_battery_production) // Grid damages from EV already VMT-adjusted.
	gen benefits_local_clean_car_cf = (clean_car_local * ${EV_VMT_car_adjustment}) - grid_ext_car_local // Grid damages from EV already VMT-adjusted.
	
	gen benefits_global_new_car_cf = (new_car_global * ${EV_VMT_car_adjustment}) - (grid_ext_car_global + CO2_battery_production)
	gen benefits_local_new_car_cf = (new_car_local * ${EV_VMT_car_adjustment}) - grid_ext_car_local
	
	// BENEFITS WHEN USING EVs WITH AVG VMT
	gen benefits_global_new_avg_cf = (new_avg_global * ${EV_VMT_avg_adjustment}) - (grid_ext_avg_global + CO2_battery_production) // Assume same battery for trucks and cars. 
	gen benefits_local_new_avg_cf = (new_avg_local * ${EV_VMT_avg_adjustment}) - grid_ext_avg_local

	keep year benefits*
	
	di in red "Resaving EV Timepaths."
	
	local alternative_spec = ""
	
	if "${renewables_loop}" == "yes" {
		local alternative_spec = "_${renewables_percent}"
	}
	save "${assumptions}/timepaths/ev_externalities_time_path_${scc}_age${vehicle_car_lifetime}_vmt${EV_VMT_car_adjustment_ind}_grid${ev_grid}`alternative_spec'.dta", replace
		
}

*-----------------------------------------------------------------------
* 5 - Save Wind & Solar Timepaths 
*-----------------------------------------------------------------------

global State "US"

if "${rerun_timepaths}" == "yes" | "${rerun_solar_wind_timepaths}" == "yes" {
	
	qui do "${calculation_files}/solar_enviro_ext"
	qui do "${calculation_files}/wind_enviro_ext"
}



di in red "Setting globals to no because macros has finished running"
global rerun_timepaths "no"
global rerun_macros "no"