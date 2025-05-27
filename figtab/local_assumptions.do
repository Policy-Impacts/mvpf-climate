*-------------------------------------------------------------------------------
*                            Wind
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

*-------------------------------------------------------------------------------
*                            Weatherization
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
*                            Hybrid Vehicles
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

global hybrid_lifetime_incr = "yes"		// changed in policy dofiles
		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hev_usa_s hev_usa_i hybrid_cr" /// programs to run
		0 /// reps
		"hybrid_current_lifetime_incr_193" // nrun 		
		
global hybrid_lifetime_incr = "no"

global hybrid_lifetime_decr = "yes"		// changed in policy dofiles
		
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"hev_usa_s hev_usa_i hybrid_cr" /// programs to run
		0 /// reps
		"hybrid_current_lifetime_decr_193" // nrun 		
		
global hybrid_lifetime_decr = "no"

*-------------------------------------------------------------------------------
*                            Appliances
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
		"appliance_current_lifetime_18_193" // nrun 
		
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
		"appliance_current_lifetime_13_193" // nrun 
		
global decr_appliance_lifetimes = "no"
		
*-------------------------------------------------------------------------------
*                            Vehicle Retirement
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

global vehicle_mar_val_chng = "yes" // need to check this one, made edit in ado file and policy file for baaqmd

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

global vehicle_age_incr = "yes" // need to check this one, made edit in ado file and policy file for baaqmd (should it be global or local var?)

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





