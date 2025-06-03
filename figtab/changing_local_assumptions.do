/***************************************************************************
 *        Changing Category-Specific Assumptions for Referee Figure        *
 ***************************************************************************
 
    This file first generates all the relevant datasets and stores them in 
	4_results. Then it generates the MVPF plot.
	
****************************************************************************/

*-------------------------------------------------------------------------------
* 1 - Solar 4
*-------------------------------------------------------------------------------

*Lowering Lifetime by 5 years
global lifetime_change = "yes"
global lifetime_scalar = 0.8	
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"ct_solar ne_solar pless_tpo pless_ho hughes_csi" /// programs to run
		0 /// reps
		"solar_lifetime_reduce_193" // nrun
		
global lifetime_change = "no"
global lifetime_scalar = 1


*Increasing Lifetime by 5 years
global lifetime_change = "yes"
global lifetime_scalar = 1.2	
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"ct_solar ne_solar pless_tpo pless_ho hughes_csi" /// programs to run
		0 /// reps
		"solar_lifetime_increase_193" // nrun
		
global lifetime_change = "no"
global lifetime_scalar = 1

*Increasing Output of Solar Panels by 25%
global solar_output_change = "yes"
global output_scalar = 1.25	
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"ct_solar ne_solar pless_tpo pless_ho hughes_csi" /// programs to run
		0 /// reps
		"solar_output_increase_193" // nrun
		
global solar_output_change = "no"
global output_scalar = 1

*Decreasing Output of Solar Panels by 25%
global solar_output_change = "yes"
global output_scalar = 0.75
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"ct_solar ne_solar pless_tpo pless_ho hughes_csi" /// programs to run
		0 /// reps
		"solar_output_decrease_193" // nrun
		
global solar_output_change = "no"
global output_scalar = 1


*-------------------------------------------------------------------------------
*                           2 - EVs 3
*-------------------------------------------------------------------------------
*Change VMT Rebound to 1 (People drive EVs as much as national average)
global VMT_change_robustness = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"federal_ev muehl_efmp bev_state" /// programs to run
		0 /// reps
		"ev_VMT_rebound_one_193" // nrun
		
global VMT_change_robustness = "no"

* Change from clean car to new car
global car_change_ev = "yes"		// changed in metafile and rerun macros
		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"federal_ev muehl_efmp bev_state" /// programs to run
		0 /// reps
global car_change_ev = "no"	

*Change vehicle lifetime from 17 to 15 years
global vehicle_lifetime_change = "yes"
global new_vehicle_lifetime = 15

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"federal_ev muehl_efmp bev_state" /// programs to run
		0 /// reps
		"ev_vehicle_lifetime_15" // nrun
global vehicle_lifetime_change = "no"

		
*Change vehicle lifetime from 17 to 20 years
global vehicle_lifetime_change = "yes"
global new_vehicle_lifetime = 20

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"federal_ev muehl_efmp bev_state" /// programs to run
		0 /// reps
		"ev_vehicle_lifetime_20" // nrun
		
global vehicle_lifetime_change = "no"
global new_vehicle_lifetime = 17


*-------------------------------------------------------------------------------
*                            Wind 8
*-------------------------------------------------------------------------------

* use constant semi elasticity
global constant_semie = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc" /// programs to run
		0 /// reps
		"wind_current_semie_193" // nrun 
		
		global constant_semie = "no"

*Scale LCOE by 50%
global lcoe_scaling = "yes"
global scalar = 0.5

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc" /// programs to run
		0 /// reps
		"wind_current_lcoe_05_193" // nrun 
		
global lcoe_scaling = "no"
global scalar = 1

*Scale LCOE by 200%
global lcoe_scaling = "yes"
global scalar = 2	

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc" /// programs to run
		0 /// reps
		"wind_current_lcoe_2_193" // nrun 

global lcoe_scaling = "no"
global scalar = 1

// Increase and decrease manufacturing emisisons 

global wind_emissions_change = "yes"
global emissions_scalar = 2

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc" /// programs to run
		0 /// reps
		"wind_current_emissions_double_193" // nrun 
		
global wind_emissions_change = "no"
global emissions_scalar = 1

global wind_emissions_change = "yes"
global emissions_scalar = 0.5

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc" /// programs to run
		0 /// reps
		"wind_current_emissions_half_193" // nrun 
		
global wind_emissions_change = "no"
global emissions_scalar = 1

// Change Lifetime of wind turbines (decrease by 5)

global wind_lifetime_change = "yes"
global lifetime_scalar = 0.8	
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc"  /// programs to run
		0 /// reps
		"wind_current_lifetime_reduce_193" // nrun
		
global wind_lifetime_change = "no"
global lifetime_scalar = 1

// Change Lifetime of wind turbines (increase by 5)

global wind_lifetime_change = "yes"
global lifetime_scalar = 1.2	
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc"  /// programs to run
		0 /// reps
		"wind_current_lifetime_increase_193" // nrun
		
global wind_lifetime_change = "no"
global lifetime_scalar = 1	

// Remove the Kay & Ricks capacity factor reduction	

global no_cap_reduction = "yes"
	
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hitaj_ptc metcalf_ptc shirmali_ptc"  /// programs to run
		0 /// reps
		"wind_current_no_cap_factor_193" // nrun
		
global no_cap_reduction = "no"


*-------------------------------------------------------------------------------
*                            Weatherization 3
*-------------------------------------------------------------------------------

* increase percent of people who are marginal
global marginal_change = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"retrofit_res ihwap_nb wisc_rf wap hancevic_rf" /// programs to run
		0 /// reps
		"weather_current_marginal_per_193" // nrun 

		global marginal_change = "no"

* decrease marginal valuation (currently 50%): create global that takes yes or no, 

global weather_mar_valuation_change = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"retrofit_res ihwap_nb wisc_rf wap hancevic_rf" /// programs to run
		0 /// reps
		"weather_current_marginal_chng_193" // nrun 
		
		global weather_mar_valuation_change = "no"
		
	// increase & decrease lifetime of weatherization (currently 20, decrease to 10)

	global decre_weather_lifespan= "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"retrofit_res ihwap_nb wisc_rf wap hancevic_rf" /// programs to run
		0 /// reps
		"weather_current_decr_lifespan_193" // nrun 
		
		global decre_weather_lifespan = "no"

*-------------------------------------------------------------------------------
*                            Hybrid Vehicles 3
*-------------------------------------------------------------------------------

* change counter factual car to average new car
	
global car_change = "yes"		// changed in metafile
		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hev_usa_s hev_usa_i hybrid_cr" /// programs to run
		0 /// reps
		"hybrid_current_new_car_193" // nrun 		
		
global car_change = "no"	

// Change Lifetime of New Car 15 and 20

global vehicle_lifetime_change = "yes"		// changed in macros, same as EVs
global new_vehicle_lifetime = 20

		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hev_usa_s hev_usa_i hybrid_cr" /// programs to run
		0 /// reps
		"hybrid_current_lifetime_incr_193" // nrun 		
		
global vehicle_lifetime_change = "no"

global vehicle_lifetime_change = "yes"	
global new_vehicle_lifetime = 15
	
		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hev_usa_s hev_usa_i hybrid_cr" /// programs to run
		0 /// reps
		"hybrid_current_lifetime_decr_193" // nrun 		
		
global vehicle_lifetime_change = "no"
global new_vehicle_lifetime = 17


*-------------------------------------------------------------------------------
*                            Appliances 2
*-------------------------------------------------------------------------------
* increase lifetime assumptions

global incr_appliance_lifetimes = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"rebate_es cw_datta c4a_fridge fridge_datta esa_fridge dw_datta c4a_dw c4a_cw" /// programs to run
		0 /// reps
		"appliance_current_lifetime_25_193" // nrun 
		
global incr_appliance_lifetimes = "no"

* decrease lifetime assumptions

global decr_appliance_lifetimes = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"rebate_es cw_datta c4a_fridge fridge_datta esa_fridge dw_datta c4a_dw c4a_cw" /// programs to run
		0 /// reps
		"appliance_current_lifetime_5_193" // nrun 
		
global decr_appliance_lifetimes = "no"
		
*-------------------------------------------------------------------------------
*                            Vehicle Retirement 3
*-------------------------------------------------------------------------------
// decrease VMT rebound
global change_vmt_rebound = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"c4c_texas c4c_federal baaqmd" /// programs to run
		0 /// reps
		"vehicle_ret_current_no_rb_193" // nrun 
		
global change_vmt_rebound = "no"

// increase marginal valuation

global vehicle_mar_val_chng = "yes" // 

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"c4c_texas c4c_federal baaqmd" /// programs to run
		0 /// reps
		"vehicle_ret_current_marginal_chng_193" // nrun 

global vehicle_mar_val_chng = "no" 

// Increase lifetime of new car	, change from 14 to 20

global vehicle_age_incr = "yes" // changed ado and policy file for baaqmd

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"c4c_texas c4c_federal baaqmd" /// programs to run
		0 /// reps
		"vehicle_ret_current_age_incr_193" // nrun 

global vehicle_age_incr = "no" 

