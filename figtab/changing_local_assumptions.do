/***************************************************************************
 *        Changing Category-Specific Assumptions for Referee Figure        *
 ***************************************************************************
 
    This file first generates all the relevant datasets and stores them in 
	4_results. Then it generates the MVPF plot.
	
****************************************************************************/

*--------------------
* 1 - Solar
*--------------------

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
		"solar_output_increase_193" // nrun
		
global solar_output_change = "no"
global output_scalar = 1


*--------------------
* 2 - EVs
*--------------------
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
