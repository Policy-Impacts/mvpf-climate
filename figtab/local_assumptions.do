** Wind

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

** Weatherization

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

global marginal_valuation_change = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"retrofit_res ihwap_nb wisc_rf wap hancevic_rf" /// programs to run
		0 /// reps
		"weather_current_marginal_chng_193" // nrun 
		
		global marginal_valuation_change = "no"

** Hybrid Vehicles:

* change counter factual car to average new car
	
global car_change = "yes"		
		
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
	* wind solar and evs are annoying	
		* 3a: there isn't an ado file, go into each of the policy to change lifeitme assumptions
		* 4a and 4b are easy, 4a is in spreadsheet, 4b is similar to weatherization valuation
		* 6c is also easy
		
* change lifetime of wind turbines
* capacity reduction

* change manufacturing emissions


** solar

* change capacity factor
* change lifetime
* change installation cost

** Appliances, maybe lifeitme assumptions? double all of them

** Vehicle Retirement
* vmt rebound
* marginal valuation, marginal ppl don't value this subsidy, change this assumptions
* lifetime of new car



** Hybrid Vehicles:
* change counter factual car to just new car
* lifetime of new car
* rebound (change in excel, driving _parameters)


** Weatherization
* change percent of ppl who are marginal (not pulled from a paper)
* how much ppl who are marginal value the policy (currently 50)
* lifetime of weatherization



** EV
* vehicle lifetime of new car
* change counter factual car to just new car
* currently driving 60 percent of the national average, change in metafile

* 1a, 1b, 6a, 5a