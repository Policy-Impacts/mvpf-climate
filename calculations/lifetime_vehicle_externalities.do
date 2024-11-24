*************************************************************
/* Purpose: Calculate environmental externality over vehicle lifetime. */
*************************************************************

* Note: the values output from this .do file should be used with the "current" mode.

global ext_min_year = 2000
global ext_max_year = ${ev_simulation_max_year}

**********************************
/* 0. Define and Set Toggles. */
**********************************
local discount = ${discount_rate}

local list_of_cf_vehicles						new_avg new_car
local components_to_calculate					total global local CO2 profits gallons local_driving taxes savings mpg

*************************************************
/* 1. Pulling Parameters. */
*************************************************	
/* All contained in ev_externalities.do. See macros.do for more. Only need vehicle lifetime. */
import excel "${policy_assumptions}", first clear sheet("evs")
levelsof Parameter, local(levels)
foreach val of local levels {

	qui sum Estimate if Parameter == "`val'"
	global `val' = `r(mean)'

}

clear
*************************************************
/* 2. Calculate Several Counterfactual Vehicles. */
*************************************************		
foreach cf of local list_of_cf_vehicles {
	
	*************************************************
	/* 2a. Forecast Fuel Economy. */
	*************************************************
	preserve
	
		if substr("`cf'", 1, 3) == "new" {
			
			import excel "${policy_assumptions}", first clear sheet("fuel_economy_1975_2022")
			gen ModelYear_str = strlen(ModelYear)
			split ModelYear, parse()
			replace ModelYear = ModelYear2 if ModelYear_str>4
			destring ModelYear, replace
			rename ModelYear model_year
			rename RealWorldMPG mpg
			
			qui sum model_year
			local model_year_max = r(max)			
			
			if "`cf'" == "new_avg" {
		
				keep if substr(VehicleType, 1, 3) == "All"
				keep if RegulatoryClass != "All"
				qui replace RegulatoryClass = strlower(RegulatoryClass)
						
				qui sum model_year
				keep if model_year == r(max) - 1 // Production shares unavailable for preliminary data. 
				destring ProductionShare, replace
								
				levelsof(RegulatoryClass), local(vehicle_loop)
				foreach v of local vehicle_loop {
						
					qui sum ProductionShare if RegulatoryClass == "`v'"
					local `v'_share = r(mean)
							
				}
				assert round(`car_share' + `truck_share', 0.0001) == 1

				import excel "${policy_assumptions}", first clear sheet("fuel_economy_forecast")
					gen production_share = .

				levelsof(vehicle_type), local(vehicle_loop)
				foreach v of local vehicle_loop {
								
					** Import production shares to weight across vehicle classes.
					replace production_share = ``v'_share' if vehicle_type == "`v'"
						
				}
				collapse (mean) mpg [aw=production_share], by(model_year)
			
				append using "${assumptions_model_year}/fuel_economy_final.dta", gen(orig)
				gsort -orig model_year
				
				*Compute percent change in mpg post 2022
				gen index = _n
				gen annual_change = (mpg - mpg[index - 1])/mpg[index - 1]
				
				*Re-index data after dropping overlap year
				drop if model_year == 2022 & orig == 0
				replace index = _n
				
				*Use the predicted percent changes to forecast mpg
				replace mpg = mpg[index - 1] * (1 + annual_change) if model_year > 2022
				drop orig index
				
				collapse (mean) mpg, by(model_year)
				bysort model_year : gen obs_check = _N
				assert obs_check == 1
				drop obs_check

				tempfile all_ldv_forecast_mpg		
				save "`all_ldv_forecast_mpg'", replace
					
			}
			
			if "`cf'" == "new_car" {
					
				keep if substr(VehicleType, 1, 7) == "All Car"
				keep if RegulatoryClass != "All"
				replace RegulatoryClass = strlower(RegulatoryClass)
			
				keep model_year mpg
				tempfile car_only_mpg
				save "`car_only_mpg'", replace
					
				import excel "${policy_assumptions}", first clear sheet("fuel_economy_forecast")
				keep if vehicle_type == "car"
				drop vehicle_type
					
				append using "`car_only_mpg'", gen(orig)
				gsort -orig model_year
				
				*Compute percent change in mpg post 2022
				gen index = _n
				gen annual_change = (mpg - mpg[index - 1])/mpg[index - 1]
				
				*Re-index data after dropping overlap year
				drop if model_year == 2022 & orig == 0
				replace index = _n
				
				*Use the predicted percent changes to forecast mpg
				replace mpg = mpg[index - 1] * (1 + annual_change) if model_year > 2022
				drop orig index
				
				collapse (mean) mpg, by(model_year)
				bysort model_year : gen obs_check = _N
				assert obs_check == 1
				drop obs_check
							
				tempfile car_only_forecast_mpg		
				save "`car_only_forecast_mpg'", replace
					
			}
		
		}
		
	restore	
	
	*******************************************************************************
	/* 2b. Calculate Per-Gallon Externality for Each Counterfactual Vehicle. */
	*******************************************************************************
	forval run_year = $ext_min_year (1) $ext_max_year {
		
		// Start with same dataset for both. No further changes needed for fleet average vehicle.
		use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear
			drop if year > 2020 // Forecasting beyond 2020 values in time paths.
		
		qui sum year
		if `run_year' > r(max) {
			
			qui sum year
				keep if year == r(max)
				replace year = `run_year'
			
			
		}
		
		qui sum year
		if `run_year' <= r(max) {
			
			keep if year == `run_year' // All in nominal dollars.
			
		}
										
		if substr("`cf'", 1, 3) == "new" {
 
			*******************************************************************************
			/* 2b.i. Save Upstream Externalities and Accidents and Congestion for Later.. */
			******************************************************************************* 			
			keep year *upstream* *ethanol*
			drop wtp_upstream_CO wtp_upstream_VOC
			
			if `run_year' > 2020 {
				
				ds wtp* global* local*
				foreach var in `r(varlist)' {
					
					replace `var' = `var' * (${cpi_`run_year'} / ${cpi_2020}) 
					// If year past 2020, using 2020 values, which are 2020 dollars. Convert to nominal dollars.
					
					if inlist("`var'", "wtp_upstream_CO2", "global_VOC_upstream", "global_CO_upstream") {
						
						replace `var' = `var' * (${sc_CO2_`run_year'} / ${sc_CO2_2020}) // Max year we have in upstream emission WTP dataset.
						
					}
					
					if inlist("`var'", "wtp_upstream_CH4") {
						
						replace `var' = `var' * (${sc_CH4_`run_year'} / ${sc_CH4_2020}) // Max year we have in upstream emission WTP dataset.
						
					}
					
					if inlist("`var'", "wtp_upstream_N2O") {
						
						replace `var' = `var' * (${sc_N2O_`run_year'} / ${sc_N2O_2020}) // Max year we have in upstream emission WTP dataset.
						
					}
					
				}
				
			}
									
			tempfile upstream_save
				save "`upstream_save'", replace
				
			
			*******************************************************************************
			/* 2b.ii. Save Sulfur Emission Rate. */
			******************************************************************************* 
			import excel "${policy_assumptions}", first clear sheet("sulfur_content_gas")
			
			qui sum year
			if `run_year' > r(max) {
				
				qui sum year
					keep if year == r(max)
					local SO2_gal = sulfur_content_ppm
				
			}
			
			qui sum year 
			if `run_year' <= r(max) {
				
				keep if year == `run_year'
					local SO2_gal = sulfur_content_ppm
				
			}
			
			*******************************************************************************
			/* 2b.iii. Calculate Per-Gallon Externality from CO, HC, and NOx. */
			******************************************************************************* 					
			use "${assumptions_model_year}/combined_Jacobsen_replicated", clear 
					
			if `run_year' > 2020 {
				
				insobs 1
				replace model_year = `run_year' if model_year == .
				
				qui ds emissions*
				foreach var in `r(varlist)' {
					
					qui sum `var' if model_year == 2020 // Max year.
					qui replace `var' = r(mean) if model_year == `run_year'
					
				}
			
			}
			keep if model_year == `run_year'
			
			*******************************************************************************
			/* 2b.iv. Calculate Per-Gallon Externality from CH4, N2O, and PM2.5. */
			******************************************************************************* 
			if "`cf'" == "new_avg" {
				merge 1:1 model_year using "`all_ldv_forecast_mpg'", nogen noreport // Merge with forecasted MPG for new average vehicle.
			}
			if "`cf'" == "new_car" {
				merge 1:1 model_year using "`car_only_forecast_mpg'", nogen noreport // Merge with forecasted MPG for new average car.
			}
									
			merge 1:1 model_year using "${assumptions_model_year}/GREET_emissions_final", nogen noreport // Emission rates for CH4, N2O, and PM2.5
				order model_year mpg				
					gen CO2_gal = ${CO2_per_gallon}
					gen SO2_gal = `SO2_gal' * ${sulfur_ppm_conversion}		
					
			// 	Handling Simulated Years w/o Reported Emission Rates.
			if `run_year' > 2020 {
				
				qui ds PM25* CH4 N2O
				foreach var in `r(varlist)' {
					
					qui sum `var' if model_year == 2020 // Max year we are using. Assume vehicles get no cleaner past 2020.
					qui replace `var' = r(mean) if model_year == `run_year'
					
				}
				
			}
														
			*******************************************************************************
			/* 2b.v. Unit Conversions and Standardizing Naming. */
			******************************************************************************* 
			
			// Renaming Variables.
			qui ds emissions*
			foreach var in `r(varlist)' {
				
				local newname = substr("`var'", 15, .)
				qui rename `var' `newname'
				
			}
						
			// Converting from g/mi to g/gallon. 
			qui ds *_gal *year mpg, not
			foreach var in `r(varlist)' {
				
				qui gen `var'_gal = `var' * mpg
				drop `var'
				
			}
			qui rename HC_gal VOC_gal
			
			keep if model_year == `run_year'
			
			// Converting from g/gallon to tons/gallon. 
			qui ds mpg *_gal
			foreach var in `r(varlist)' {
				
				qui replace `var' = `var'/1000000 if `var' != mpg
				local `var' = r(mean)
				
			}	
								
			*************************************************
			/* 2b.vi. Import Social Costs and Value Damages. */
			*************************************************	
			local ghg CO2 CH4 N2O
			foreach g of local ghg {
				
				local social_cost_`g' = ${sc_`g'_`run_year'} * (${cpi_`run_year'} / ${cpi_${sc_dollar_year}})
					
			}	

			local md_w SO2 PM25 NOx VOC CO
			foreach p of local md_w {
				
				local social_cost_`p' = ${md_`p'_`run_year'_weighted} * (${cpi_`run_year'} / ${cpi_${md_dollar_year}})
				
			}


			local md_u SO2 PM25 NOx VOC NH3 CO
			foreach p of local md_u  {
				
				local social_cost_`p'_uw = ${md_`p'_`run_year'_unweighted} * (${cpi_`run_year'} / ${cpi_${md_dollar_year}})
				
			}
			
			* Pollution Externalities: Social Cost * Emissions per Gallon
			qui foreach val of global pollutants_list {
				
				if "`val'" == "VOC"| "`val'" == "CO" | "`val'" == "PM25_TBW" | "`val'" == "PM25_exhaust" {
					if "`val'" == "VOC" | "`val'" == "CO" {
						
						gen local_`val' = `val'_gal * `social_cost_`val''
						gen global_`val' = `val'_gal * (${`val'_gwp}*`social_cost_CO2')
						gen wtp_`val' = local_`val' + global_`val'		
							
					}
					
					if "`val'" == "PM25_TBW" | "`val'" == "PM25_exhaust" {
						
						local check_PM25 = substr("`val'", 1, 4)
						gen wtp_`val' = `val'_gal * `social_cost_`check_PM25''
						
					}
					
				}
	
	
				else {
					
					gen wtp_`val' = `val'_gal * `social_cost_`val''
					
				}
				
				drop `val'_gal
	
			} 
									
			********************************************************************************************
			/* 2b.vii. Collect Results and Bring in Per-Mile Upstream and Accidents / Congestion WTP. */
			********************************************************************************************
			rename model_year year
				merge 1:1 year using "`upstream_save'", nogen noreport assert(3)	
									
		}
									
	*******************************************************************************
	**# /* 3. Account for Changing Social Costs / Vehicle Decay over Vehicle Lifetime. */
	*******************************************************************************			
	// Handle changes over vehicle lifetime the same for all counterfactuals, with exception of VMT.
	cap drop wtp_upstream_VOC wtp_upstream_CO *accidents *congestion // Need to keep local and global damages split.
	qui ds
		local numvars : word count `r(varlist)'
			assert `numvars' == 27
				
	// Adjust for Ethanol
	preserve

		// Ethanol Emission Parameters.
		import excel "${policy_assumptions}", first clear sheet("ethanol_assumptions")
		
		levelsof(parameter), local(p_loop)
		foreach p of local p_loop {
			
			qui sum value if parameter == "`p'"
				global `p' = r(mean)
			
		}

	restore
		
		****************************************************
		/* Adjust Components Proportional to Gas Usage / Ethanol Share.  */
		****************************************************
		ds *upstream* wtp_CO2 wtp_CH4 wtp_N2O
		foreach var in `r(varlist)' {
			
			replace `var' = `var' * (1 - share_ethanol)
			// NOTE: SO2 reported ppm already reflects sulfur content.
			// NOTE: EPA fuel economy accounts for mileage penalty from ethanol. 
			// NOTE: Lifecycle analysis of ethanol includes CH4 and N2O from burning methane, so scaling down.
		
		}
		
		assert round(local_VOC + global_VOC, 0.0001) == round(wtp_VOC, 0.0001)
		assert round(local_CO + global_CO, 0.0001) == round(wtp_CO, 0.0001)
		
		
		****************************************************
		/* Adjust Local Pollution due to Ethanol using % Change Estimates.  */
		****************************************************
		local ethanol_local_adj 	NOx CO VOC
		foreach p of local ethanol_local_adj {
			
			if "`p'" == "NOx" {
				replace wtp_`p' = wtp_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
			}
			if inlist("`p'", "CO", "VOC") {
				replace local_`p' = local_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
				replace global_`p' = global_`p' * ((1 + (${`p'_change_e10}*(share_ethanol/0.098))))
			}
			
			// Assuming linear relationship b/w ethanol share and emission rate for low levels of ethanol. Paper tests percent decline in emissions for fuel w/ 9.8% ethanol.
			// Leaving PM2.5 unadjusted.

		}

		replace wtp_CO = local_CO + global_CO
		replace wtp_VOC = local_VOC + global_VOC
		
		****************************************************
		/* Account for Upstream Ethanol Emissions.  */
		****************************************************	
		if `run_year' > 2020 {
			
			global upstream_CO2_intensity_`run_year' = ${upstream_CO2_intensity_2020} // Max year in data.
			
		}
		
		local upstream_CO2_ethanol = (((${upstream_CO2_intensity_`run_year'} + ${luc_CO2_intensity}) * ${mj_per_gal_ethanol})/1000000) * (${sc_CO2_`run_year'} * (${cpi_`run_year'}/${cpi_${sc_dollar_year}}))
		// Grams per MJ, multiplied by MJ per/gallon of ethanol, converted to tons, multiplied by SCC.
		
		replace wtp_upstream_CO2 = wtp_upstream_CO2 + (`upstream_CO2_ethanol' * share_ethanol)
		// Already scaled down petroleum upstream emissions by share petroleum; now adding upstream ethanol emissions.
						
	drop wtp_CO wtp_VOC share_ethanol
		
		
	// WANT TO LEAVE ALL PER-MILE EXTERNALITIES IN $/MI
	gen wtp_accidents = (${accidents_per_mi} * (${cpi_`run_year'}/${cpi_2020}))
	gen wtp_congestion = (${congestion_per_mi} * (${cpi_`run_year'}/${cpi_2020}))	
	replace wtp_PM25_TBW = wtp_PM25_TBW / mpg
	
	// Save externalities associated with new vehicle for given year before adjustments. Used in vehicle retirement. 
	if inlist(year, 2009, 2020) & "`cf'" != "fleet_avg" {
		
		save "${user_specific_assumptions}/files_v${user_name}/New Vehicle Externalities/externalities_`run_year'_`cf'.dta", replace
		
	}
			
		*******************************************************************************
		/* 3a. Everything Expressed in Nominal Dollars; Convert to SCC Dollar Year. */
		*******************************************************************************		
		ds year mpg, not
		foreach var in `r(varlist)' {
			
			qui replace `var' = `var' * (${cpi_${sc_dollar_year}} / ${cpi_`run_year'}) // All in 2020 dollars (${sc_dollar_year}).
			
		}
			
		*******************************************************************************
		/* 3b. Import VMT (Varies with Counterfactual). */
		*******************************************************************************	
		gen age = 1
			local age_lower_bound = age + 1
		
		if "`cf'" == "fleet_avg" {
			
			preserve
				use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", clear
				collapse (mean) age [aw=age_share]
					local fleet_avg_age = round(age, 1)
			restore
			
			replace age = `fleet_avg_age'
				local age_lower_bound = age + 1
					
		}
		
		order year age
		local veh_lifespan_type = substr("`cf'", strpos("`cf'", "_") + 1, .)
			
			local age_upper_bound = (age + ${vehicle_`veh_lifespan_type'_lifetime}) - 1
					
		qui forval a = `age_lower_bound'(1)`age_upper_bound' {
				
			insobs 1, after(1)	
			qui replace age = `a' if age == .
			sort age
			
			if "`cf'" != "fleet_avg" {
				assert age[`a'] > age[`a' - 1]
				qui replace year = (year[1] + `a') - 1 if age == `a'
			}
			
			if "`cf'" == "fleet_avg" {
				qui replace year = (year[1] + (`a' - `fleet_avg_age')) if age == `a'
			}
				
		}
		assert _N == ${vehicle_`veh_lifespan_type'_lifetime}	
		qui replace mpg = mpg[1] // Assuming no decay in fuel-economy of vehicle.
		
		qui sum year
			assert r(max) == `run_year' + ${vehicle_`veh_lifespan_type'_lifetime} - 1
			assert year == year[1] + age - age[1] 
				
		if substr("`cf'", -3, 3) == "avg" {
			
			local vehicle_loop_name = substr("`cf'", -3, 3)
			merge 1:1 age using "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_`vehicle_loop_name'.dta", keep(3) nogen noreport
			drop age_share
			rename fleet_avg_vmt vmt
			order year age vmt
			
		}
		
		if substr("`cf'", -3, 3) == "car" {
		
			local vehicle_loop_name = substr("`cf'", -3, 3) 
			merge 1:1 age using "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_`vehicle_loop_name'.dta", keep(3) nogen noreport
			drop age_share
			rename vmt_avg_car vmt
			order year age vmt

		}
		
		*******************************************************************************
		/* 3c. Deal with Static Externalities. */
		*******************************************************************************		
		local no_adj_ext		SO2 accidents congestion PM25 NH3
		qui foreach p of local no_adj_ext {
			
			if inlist("`p'", "SO2") {
				
				replace wtp_`p' = wtp_`p'[1]
				replace wtp_upstream_`p' = wtp_upstream_`p'[1]
				
			}
			
			if inlist("`p'", "accidents", "congestion") {
				
				replace wtp_`p' = wtp_`p'[1]
				
			}
			
			if inlist("`p'", "NH3") {
				
				replace wtp_upstream_`p' = wtp_upstream_`p'[1]
				
			}
			
			if inlist("`p'", "PM25") {
				
				replace wtp_`p'_exhaust = wtp_`p'_exhaust[1]
				replace wtp_`p'_TBW = wtp_`p'_TBW[1]
				replace wtp_upstream_`p' = wtp_upstream_`p'[1]
				
			}
			
		}
		
		
		***********************************************
		/* 3d. Deal with Time-varying Externalities. */
		***********************************************		
		local adj_ext			CO2 N2O CH4 NOx CO VOC
		
		qui foreach p of local adj_ext {
			
			if inlist("`p'", "CO2", "CH4", "N2O") { // Social costs rising over time; All expressed in 2020 dollars already.
				
				levelsof(year), local(y_loop)
				foreach y of local y_loop {
					
					qui sum year 
					assert `run_year' == r(min)
					
					replace wtp_`p' = wtp_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`run_year'}) if year == `y'
					replace wtp_upstream_`p' = wtp_upstream_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`run_year'}) if year == `y'
						
				}
			
			}
				
			if "`p'" == "NOx" { // Vehicle decaying, damages constant; NOT decaying 1st year.
				
				foreach y of local y_loop {
					
					replace wtp_`p' = wtp_`p'[1] * ((1 + ${`p'_decay})^(`y' - `run_year')) if year == `y' & age <= ${decay_age_cutoff}
					replace wtp_`p' = wtp_`p'[1] * ((1 + ${`p'_decay})^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
						assert `y' - `run_year' == age - 1 if year == `y' & "`cf'" != "fleet_avg"
					
					
					replace wtp_upstream_`p' = wtp_upstream_`p'[1]
					
				}	
				
			}
		
		
			if "`p'" == "VOC" | "`p'" == "CO" {
							
				replace local_`p'_upstream = local_`p'_upstream[1] // No changes to local upstream damages over time.

				foreach y of local y_loop {
					
					if "`p'" == "VOC" {
						local decay = ${HC_decay} // Only doing this step b/c decay factor is named HC_decay, not VOC_decay.
					}
					if "`p'" == "CO" {
						local decay = ${CO_decay}
					}					
					
					replace global_`p'_upstream = global_`p'_upstream[1] * (${sc_CO2_`y'}/${sc_CO2_`run_year'}) if year == `y' 
					// Same approach as upstream CO2 adjustment. GWP already applied in earlier calculations. Scale by annual change in SCC; constant GWP.
					
					replace global_`p' = global_`p'[1] * ((1 + `decay')^(`y' - `run_year')) * (${sc_CO2_`y'}/${sc_CO2_`run_year'}) if year == `y' & age <= ${decay_age_cutoff}
					replace global_`p' = global_`p'[1] * ((1 + `decay')^(${decay_age_cutoff} - 1)) * (${sc_CO2_`y'}/${sc_CO2_`run_year'}) if year == `y' & age > ${decay_age_cutoff}
						assert `y' - `run_year' == age - 1 if year == `y' & "`cf'" != "fleet_avg"
					// VOC decay = HC decay rate. Rising social costs and emission rate.
					
					replace local_`p' = local_`p'[1] * ((1 + `decay')^(`y' - `run_year')) if year == `y' & age <= ${decay_age_cutoff}
					replace local_`p' = local_`p'[1] * ((1 + `decay')^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
						assert `y' - `run_year' == age - 1 if year == `y' & "`cf'" != "fleet_avg"
					// No change in VOC's and CO's marginal damages (local). Rising emission rate due to vehicle decay. 
					
				}
				
			}
			
		}
					
		*******************************************************************************
		/*       3e. Sum Damages to Calculate Total Local / Global Externality.      */
		*******************************************************************************					
		** First, check that no observations are empty
		qui ds
		foreach var in `r(varlist)' {
			
			qui levelsof(year), local(year_loop)
			foreach y of local year_loop {
				
				qui sum `var' if year == `y'
				assert `var' != .
				
			}
			
		}
		
		** Next, Sum to Construct Global / Local Externalities, NOT INCLUDING PER-MILE EXTERNALITIES.
		gen wtp_local = 0
		qui foreach val of global damages_local {
						
			if "`val'" == "NOx" | "`val'" == "SO2" {
					
				replace wtp_local = wtp_local + wtp_`val' + wtp_upstream_`val'
					
			}
				
			if "`val'" == "PM25" {
					
				replace wtp_local =	wtp_local + wtp_upstream_`val' + wtp_`val'_exhaust // Don't include wtp_`val'_TBW here. 
					
			}
				
			if "`val'" == "NH3" {
					
				replace wtp_local =	wtp_local + wtp_upstream_`val' 
					
			}
				
			if "`val'" == "local_VOC"| "`val'" == "local_CO" {
					
				replace wtp_local =	wtp_local + `val' + `val'_upstream
					
			}

			if "`val'" == "accidents" | "`val'" == "congestion" {
					
				replace wtp_local = wtp_local // Don't include wtp_`val' here.
					
			}	
		}

		gen wtp_global = 0 
		qui foreach val of global damages_global {
				
			if !inlist("`val'", "global_VOC", "global_CO") {
					
				replace wtp_global = wtp_global + wtp_`val' + wtp_upstream_`val'
					
			}
			else {
					
				replace wtp_global = wtp_global + `val' + `val'_upstream
					
			}
			
		}

		gen wtp_total = wtp_local + wtp_global
		gen wtp_local_driving = wtp_accidents + wtp_congestion + wtp_PM25_TBW	// Measured in $/mi. 
		
		*******************************************************************************
		/*         3f. Calculate Damages over Vehicle Lifetime and Discount.         */
		*******************************************************************************		
		keep year age vmt mpg wtp_total wtp_local* wtp_global
		gen gallons_used = vmt / mpg
		
		local components_to_calculate total global local CO2 profits gallons local_driving taxes savings mpg
		foreach c of local components_to_calculate {
			
			if "`c'" == "mpg" {
				
				continue
				
			}
			
			if "`c'" != "mpg" {
				
				gen `c' = .
						
			}
						
		}
		** run_year = actual year, y is for calculating the car age
		** list_of_cf_vehicles new_car new_avg fleet_avg 
		foreach c of local components_to_calculate {
		
			qui levelsof(year), local(year_loop)
			foreach y of local year_loop {
				
				if inlist("`c'", "total", "global", "local") {

					replace `c' = (gallons_used * wtp_`c') / ((1 + `discount')^(`y' - `run_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
          
					sum `c' if year == `y'
					  local age = `y' - `run_year'
					if `age' == 1 & "`c'" == "global" & "`cf'" == "new_car"{
						global new_car_first_damages_g_`run_year' = `r(mean)' // convert this to hybrid and hybrid counterfactual down below
					}
					
				}

				if inlist("`c'", "local_driving") {
					
					replace `c' = (vmt * wtp_`c') / ((1 + `discount')^(`y' - `run_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
					
				}

				if inlist("`c'", "profits") {
					
					replace `c' = (gallons_used * ${nominal_gas_markup_`run_year'}) / ((1 + `discount')^(`y' - `run_year')) if year == `y' // NOMINAL DOLLARS.
					
				}
				
				if inlist("`c'", "taxes") {
					
					replace `c' = (gallons_used * ${nominal_gas_tax_`run_year'}) / ((1 + `discount')^(`y' - `run_year')) if year == `y' // NOMINAL DOLLARS.
					
				}
				
				if inlist("`c'", "savings") {
					
					replace `c' = (gallons_used * ${nominal_gas_price_`run_year'}) / ((1 + `discount')^(`y' - `run_year')) if year == `y' // NOMINAL DOLLARS.
					
				}
				
				if inlist("`c'", "CO2") {
					
					replace `c' = (gallons_used * (wtp_global / ${sc_CO2_`y'})) if year == `y' // Not discounting CO2 (b/c in tons).
					
				}	
				
				if inlist("`c'", "gallons") {
					
					replace `c' = gallons_used if year == `y' // Not discounting gallons.
					
				}					
				
				if inlist("`c'", "mpg") {
					
					continue
					
				}
				
			}
			
		}
		
		foreach c of local components_to_calculate {
		
			if "`c'" != "mpg" {
				
				egen total_`c' = total(`c')
				drop `c'
				global `cf'_`c'_`run_year' = total_`c'
					
			}

			if "`c'" == "mpg" {
				
				global `cf'_`c'_`run_year' = mpg
				
			}
			
		}
		
	}
}

*******************************************************************************
/*                             4. Compile Results.                           */
*******************************************************************************	
clear
forval y = $ext_min_year (1) $ext_max_year {
	
	insobs 1
		cap gen year = .
			replace year = `y' if year == .
	
}

foreach cf of local list_of_cf_vehicles {
	
	foreach c of local components_to_calculate {
		
		qui forval y = $ext_min_year (1) $ext_max_year {
			
			cap gen `cf'_`c' = .
			replace `cf'_`c' = ${`cf'_`c'_`y'} if year == `y'
			
		}
				
	}
	
}

	*******************************************************************************
	/*        4a. Inflation Adjust from SCC Dollar Year to Year Evaluated.       */
	*******************************************************************************	
	// Only externalities need to be converted to nominal dollar years. 
	qui ds *total *global *local *local_driving // Only four components inflation adjusted.
	foreach var in `r(varlist)' {
		
		forval y = $ext_min_year (1) $ext_max_year {

			qui replace `var' = `var' * (${cpi_`y'} / ${cpi_${sc_dollar_year}}) if year == `y'
		
		} 
		
	}

*******************************************************************************
/*                 5. Calculate Holland et al. CF (for EVs).                 */
*******************************************************************************	
preserve 

	import excel "${policy_assumptions}", clear first sheet("driving_parameters")
	qui sum estimate if parameter == "ev_clean_cf_scale"
	global ev_clean_cf_scale = r(mean) // Tells us the CF EV is X times more fuel-efficient than the average car.

restore 

foreach c of local components_to_calculate {
	
	gen clean_car_`c' = .
	
	forval y = $ext_min_year (1) $ext_max_year {
	
		if !inlist("`c'", "mpg", "local_driving") {
			
			qui replace clean_car_`c' = (new_car_`c' / ${ev_clean_cf_scale}) if year == `y'
			
		}
	
		if "`c'" == "mpg" {
			
			qui replace clean_car_`c' = new_car_`c' * ${ev_clean_cf_scale} if year == `y'

			
		}
		
		if "`c'" == "local_driving" {
			
			qui replace clean_car_`c' = new_car_`c' if year == `y'
			
		}
	
	}
		
}


*******************************************************************************
/*                           6. Calculate Hybrids.                           */
*******************************************************************************	
preserve	

	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		use "${assumptions}/evs/processed/hev_data", clear
		
		qui sum mpg if year == `y'
		local hybrid_mpg_`y' = r(mean)
		qui sum mpg_cf if year == `y'
		local muehl_mpg_`y' = r(mean)
			
	}	
	
restore

foreach h in hybrid muehl {
	*local components_to_calculate total global local CO2 profits gallons local_driving taxes savings mpg
	foreach c of local components_to_calculate {
		
		gen `h'_`c' = .
		
		forval y = $ext_min_year (1) $ext_max_year {
		
			if !inlist("`c'", "mpg", "local_driving") {
				
				qui replace `h'_`c' = new_car_`c' * (new_car_mpg / ``h'_mpg_`y'') if year == `y' & `y' <= 2020
				
			}
			
			if "`c'" == "mpg" {
				
				qui replace `h'_`c' = ``h'_mpg_`y'' if year == `y' & `y' <= 2020
				
			}
      
			if "`c'" == "local_driving" {
				
				qui replace `h'_`c' = new_car_`c' if year == `y'
				
			}			
      
			if "`c'" == "global"{

				sum new_car_mpg if year == `y'
			  	global `h'_first_damages_g_`y' = ${new_car_first_damages_g_`y'} * (`r(mean)' / ``h'_mpg_`y'') // for Latex

			}
      
		}
			
	}	
	
}

*******************************************************************************
/*               6a. Calculate VMT Rebound for Hybrid Vehicles.              */
*******************************************************************************	
gen pct_change_cost_driving = .
gen rebound = .

forval y = $ext_min_year (1) $ext_max_year {

	replace pct_change_cost_driving = ((${nominal_gas_price_`y'} / hybrid_mpg) - (${nominal_gas_price_`y'} / ${hev_cf}_mpg)) / (${nominal_gas_price_`y'} / ${hev_cf}_mpg) if year == `y'
	assert pct_change_cost_driving <= 0 if pct_change_cost_driving != . // Higher MPG lowers the cost of driving for a given price of gasoline.
		
	replace rebound = ${vmt_rebound_elasticity} * pct_change_cost_driving if year == `y'
	assert rebound >= 0 if rebound != . // Cost of driving falls as MPG increases, meaning VMT increases. 
		
}


foreach c of local components_to_calculate {

	if "`c'" == "mpg" {
		
		continue
		
	}
	
	if "`c'" != "mpg" {
		
		rename hybrid_`c' hybrid_`c'_no_r
		gen hybrid_`c' = . 
		
	}
	
	replace hybrid_`c' = hybrid_`c'_no_r * (1 + rebound)
	gen hybrid_rbd_`c' = hybrid_`c'_no_r * rebound 
	

}
drop pct_change_cost_driving rebound


// ADDING IN REBOUND IN DRIVING DAMAGES TO HYBRIDS.
replace hybrid_local = hybrid_local + hybrid_rbd_local_driving 
replace hybrid_rbd_local = hybrid_rbd_local + hybrid_rbd_local_driving

*******************************************************************************
/*                7. Save Results.                */
*******************************************************************************	
save "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", replace