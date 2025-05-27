*************************************************************
/* Purpose: Calculate MVPF for (Some) Vehicle Retirement Policies	*/
*************************************************************

* Note: This .ado file streamlines the process of MVPFing a vehicle retirement policy that increases the fuel economy of the purchased vehicle. In MVPFing these policies, we assume away benefits from short accelerations in time of vehicle purchase but account for lifetime benefits from inducing the consumption of more fuel-efficienct vehicles. As of 6/25/2024, two policies fit this description: c4c_texas and c4c_federal.


cap prog drop run_vehicle_retirement
prog def run_vehicle_retirement, rclass

syntax anything, mpg_improvement(real) 

local dollar_year = `anything'
local improved_fuel_economy = `mpg_improvement'
local discount = ${discount_rate}

global c4c_interest_rate				0.03
global retirement_cf					new_avg

		
****************************************************
/* 1. Pull Assumptions and Calculate Rbd.  */
****************************************************	
preserve

	import excel "${policy_assumptions}", first clear sheet("car_rebate")
	levelsof(Parameter), local(p_loop)
	foreach p of local p_loop {
		
		qui sum Estimate if Parameter == "`p'"
			local `p' = r(mean)
		
	}

restore
	
if "${vehicle_mar_val_chng}" == "yes" {
	
		local marg_valuation = 0.5
		
}

if "${vehicle_age_incr}" == "yes" {
	
		local avg_c4c_scrap_age = 20
		
}
****************************************************
/* 2. Calculate Rbd Effect.  */
****************************************************		
preserve 

	use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", clear		
		keep year ${retirement_cf}* 
		drop *_total 
		
	// Calculating percent improvement in MPG using fuel economy the year the policy went into effect, then holding this percent improvement fixed.		
	qui sum ${retirement_cf}_mpg if year == ${policy_year}

	local mpg_baseline = r(mean)
	local pct_improvement_mpg = `mpg_improvement' / `mpg_baseline'
	
	keep if year == `dollar_year'	
		local mpg_old = ${retirement_cf}_mpg
		local mpg_new = ${retirement_cf}_mpg * (1 + `pct_improvement_mpg')
		
		if `dollar_year' == ${policy_year} {
			assert `mpg_old' == `mpg_baseline'
// 			assert round(`mpg_old' + `mpg_improvement', 0.01) == round(`mpg_new', 0.01)
		}
	
	local rebound_elasticity = ${vmt_rebound_elasticity} // dVMT/dFuelEcost < 0. Drive more as cost of driving a mile falls.
	local pct_change_cost_driving = (((${nominal_gas_price_`dollar_year'} / `mpg_new') - (${nominal_gas_price_`dollar_year'} / `mpg_old')) / (${nominal_gas_price_`dollar_year'} / `mpg_old')) * 100

	di in red "Asserting Cost of Driving Falls due to the Higher MPG"
	assert `pct_change_cost_driving' <= 0 // Higher MPG lowers the cost of driving for a given price of gasoline.

	di in red "Asserting VMT Increases with Higher Fuel-Economy Vehicle."
	local rebound = (`pct_change_cost_driving' * `rebound_elasticity')/100 
	assert `rebound' >= 0 // VMT increases when you purchase a more fuel efficient vehicle.
					
	if "${rebound}" == "no" {
		
		local rebound = 0
		
	}	
	
restore 

****************************************************
/* 3. Account for Acceleration Benefits.  */
****************************************************	
preserve

	****************************************************
	/* 3a. Estimate Older, Retired Vehicle Damages.  */
	****************************************************
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear
	keep if year == `dollar_year'
	
	*******************************************************************************
	/* Save Upstream Externalities for Later. */
	******************************************************************************* 
	// Want upstream damages for year we are analyzing; emission rates from year vehicle was released.
	keep year *upstream* *ethanol*
	tempfile upstream_save
	save "`upstream_save'", replace
							
	*******************************************************************************
	/* Calculate Per-Gallon Externality from Sulfur. */
	******************************************************************************* 
	import excel "${policy_assumptions}", first clear sheet("sulfur_content_gas")
	keep if year == `dollar_year'
	local SO2_gal = sulfur_content_ppm

	*******************************************************************************
	/* Calculate Per-Gallon Externality from CO, HC, and NOx. */
	******************************************************************************* 					
	use "${assumptions_model_year}/combined_Jacobsen_replicated", clear 
	qui sum model_year
	local my_min = r(min)
	local my_max = r(max)
	
	forval my = `my_min'(1)`my_max' {
		
		qui sum model_year if model_year == `my'
		if r(mean) == . {
			assert !missing(model_year)
			insobs 1
			replace model_year = `my' if model_year == .
		}
		sort model_year
		
	}
	
	// Missing emission rates for select years, consistent with Jacobsen et al. 2023.
	ds emissions_new*
	foreach var in `r(varlist)' {
		
		ipolate `var' model_year, generate(`var'_fixed) 
		replace `var' = `var'_fixed if `var' == .
		drop `var'_fixed
		
	}
	keep if model_year == (`dollar_year' - `avg_c4c_scrap_age') + 1
	
	*******************************************************************************
	/* Calculate Per-Gallon Externality from CH4, N2O, and PM2.5. */
	******************************************************************************* 				
	merge 1:1 model_year using "${assumptions_model_year}/fuel_economy_final.dta", nogen noreport 
	
	merge 1:1 model_year using "${assumptions_model_year}/GREET_emissions_final", nogen noreport // Emission rates for CH4, N2O, and PM2.5
	order model_year mpg
	gen CO2_gal = ${CO2_per_gallon}
	gen SO2_gal = `SO2_gal' * ${sulfur_ppm_conversion}
			
	qui sum model_year if PM25_exhaust != .
	local earliest_year = r(min)
		
	if (`dollar_year' - `avg_c4c_scrap_age') + 1 < `earliest_year' {
		
		ds PM25* CH4 N2O
		foreach var in `r(varlist)' {
			
			qui sum `var' if model_year == `earliest_year'
			replace `var' = r(mean) if model_year == (`dollar_year' - `avg_c4c_scrap_age') + 1
			
		}
		
	}

	*******************************************************************************
	/* Unit Conversions and Standardizing Naming. */
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
	keep if model_year == (`dollar_year' - `avg_c4c_scrap_age') + 1
	
	// Converting from g/gallon to tons/gallon. 
	qui ds mpg *_gal
	foreach var in `r(varlist)' {
		
		qui replace `var' = `var'/1000000 if `var' != mpg
		local `var' = r(mean)
		
	}	
	
	*************************************************
	/* Account for Vehicle Decay (Until Age 19). */
	*************************************************	
	gen age = `avg_c4c_scrap_age'
	gen decay_ind = age - 1
	replace decay_ind = ${decay_age_cutoff} if age > ${decay_age_cutoff}

	replace CO_gal = CO_gal * (1 + ${CO_decay})^(decay_ind)		
	replace NOx_gal = NOx_gal * (1 + ${NOx_decay})^(decay_ind)		
	replace VOC_gal = VOC_gal * (1 + ${HC_decay})^(decay_ind)	
	
	drop decay_ind
	
	*************************************************
	/* Import Social Costs and Value Damages. */
	*************************************************	
	local ghg CO2 CH4 N2O
	foreach g of local ghg {
		
		local social_cost_`g' = ${sc_`g'_`dollar_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
			
	}	

	local md_w SO2 PM25 NOx VOC CO
	foreach p of local md_w {
		
		local social_cost_`p' = ${md_`p'_`dollar_year'_weighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
		
	}


	local md_u SO2 PM25 NOx VOC NH3 CO
	foreach p of local md_u  {
		
		local social_cost_`p'_uw = ${md_`p'_`dollar_year'_unweighted} * (${cpi_`dollar_year'} / ${cpi_${md_dollar_year}})
		
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
	/* Collect Results and Bring in Per-Mile Upstream. */
	********************************************************************************************
	assert model_year == (`dollar_year' - `avg_c4c_scrap_age') + 1
	gen year = `dollar_year'
	order year model_year
	merge 1:1 year using "`upstream_save'", nogen noreport assert(3)
	cap drop wtp_upstream_CO
	cap drop wtp_upstream_VOC

	********************************************************************************************
	/* Adjust for Ethanol Composition. */
	********************************************************************************************
	cap drop wtp_upstream_VOC wtp_upstream_CO *accidents *congestion // Need to keep local and global damages split.
	qui ds
	local numvars : word count `r(varlist)'
	cap drop model_year
	
	/* Adjust Components Proportional to Gas Usage.  */
	ds *upstream* wtp_CO2 wtp_CH4 wtp_N2O
	foreach var in `r(varlist)' {
		
		replace `var' = `var' * (1 - share_ethanol)
		// NOTE: SO2 reported ppm already reflects sulfur content.
		// NOTE: EPA fuel economy accounts for mileage penalty from ethanol. 
		// NOTE: Lifecycle analysis of ethanol includes CH4 and N2O from burning methane, so scaling down.
	
	}
	
	/* Adjust Local Pollution using % Change Estimates.  */
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
	
	/* Account for Upstream Ethanol Emissions.  */
	local upstream_CO2_ethanol = (((${upstream_CO2_intensity_`dollar_year'} + ${luc_CO2_intensity}) * ${mj_per_gal_ethanol})/1000000) * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}}))
	// Grams per MJ, multiplied by MJ per/gallon of ethanol, converted to tons, multiplied by SCC.
	
	replace wtp_upstream_CO2 = wtp_upstream_CO2 + (`upstream_CO2_ethanol' * share_ethanol)
	// Already scaled down petroleum upstream emissions by share petroleum; now adding upstream ethanol emissions.
	
	drop wtp_CO wtp_VOC share_ethanol

	****************************************************
	/* 3b. Combine with Data on New Vehicle.  */
	****************************************************
	append using "${user_specific_assumptions}/files_v${user_name}/New Vehicle Externalities/externalities_`dollar_year'_${retirement_cf}"
		drop wtp_accidents wtp_congestion
		// assert wtp_CO2[1] == wtp_CO2[2] & wtp_upstream_CO2[1] == wtp_upstream_CO2[2] & wtp_SO2[1] == wtp_SO2[2] 
		// Spot checking externalities that should not change.
		assert year[1] == year[2]
		
	replace age = 1 if age == . & _n == 2

	// Adjust MPG to reflect fuel economy improvement. MPG feeds into gallons used below.
	qui sum mpg if age == 1
		local unadj_new_mpg = r(mean)
	// 		assert round(`unadj_new_mpg', 0.001) == round(`mpg_old', 0.001)
	replace mpg = mpg * (1 + `pct_improvement_mpg') if age == 1

	// 		assert round(mpg, 0.00001) == round(`mpg_new', 0.00001) if age == 1

	****************************************************
	/* 3c. Import VMT Data and Account for VMT Rbd.  */
	****************************************************
	local cf = "${retirement_cf}"
				
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

	qui sum vmt if age == `avg_c4c_scrap_age'
	replace vmt = r(mean) 
		
	replace vmt = (${months_accelerated} / 12) * vmt // Scale VMT by months accelerated, assuming VMT uniformly distributed throughout year.

	// Add Rebound. Rbd relative to old car traveled during accelerated period.
	local acceleration_rbd = ///
		(((${nominal_gas_price_`dollar_year'} / mpg[1]) - (${nominal_gas_price_`dollar_year'} / mpg[2])) / ((${nominal_gas_price_`dollar_year'} / mpg[2]))) * `rebound_elasticity'

	gen rebound_vmt = 0
	replace rebound_vmt = (vmt * (1 + `acceleration_rbd')) - vmt if age != `avg_c4c_scrap_age'
	replace vmt = vmt * (1 + `acceleration_rbd') if age != `avg_c4c_scrap_age'
	order year age vmt rebound_vmt
								
	****************************************************
	/* 3d. Total Externalities.  */
	****************************************************
	replace wtp_PM25_TBW = wtp_PM25_TBW / mpg if age == `avg_c4c_scrap_age' // Value from lifetime_vehicle_externalities in per-mile terms already.

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

	gen wtp_accidents = (${accidents_per_mi} * (${cpi_`dollar_year'}/${cpi_2020}))
	gen wtp_congestion = (${congestion_per_mi} * (${cpi_`dollar_year'}/${cpi_2020}))

	gen wtp_total = wtp_local + wtp_global
	gen wtp_local_driving = wtp_PM25_TBW + wtp_accidents + wtp_congestion // Have to account for PM2.5 from tires and brakes, since emission rate differs and b/c of rebound.
		
	tempfile replacement_vehicle_damages
		save "`replacement_vehicle_damages'", replace

	keep wtp_local* wtp_global wtp_total year age *vmt* mpg

	****************************************************
	/* 3e. Calculate Total Components over Acceleration Period.  */
	****************************************************	
	gen gallons_used = vmt / mpg
	gen gallons_used_rbd = rebound_vmt / mpg
		
	local components_to_calculate total global local CO2 profits gallons local_driving taxes savings mpg
	foreach c of local components_to_calculate {
		
		if "`c'" == "mpg" {
			
			continue
			
		}
		
		if "`c'" != "mpg" {
			
			gen `c' = .
			gen `c'_rbd = .
					
		}
					
	}

	foreach c of local components_to_calculate {
				
		if inlist("`c'", "total", "global", "local") {

			replace `c' = (gallons_used * wtp_`c')
			replace `c'_rbd = (gallons_used_rbd * wtp_`c')
			
		}

		if inlist("`c'", "local_driving") {
			
			replace `c' = (vmt * wtp_`c')
			replace `c'_rbd = (rebound_vmt * wtp_`c')
			
	// 			assert round(local_driving, 0.001) == round(vmt[2] * wtp_local_driving + rebound_vmt * wtp_local_driving, 0.001)
			
		}

		if inlist("`c'", "profits") {
			
			replace `c' = (gallons_used * ${nominal_gas_markup_`dollar_year'})
			replace `c'_rbd = (gallons_used_rbd * ${nominal_gas_markup_`dollar_year'})

			
		}
		
		if inlist("`c'", "taxes") {
			
			replace `c' = (gallons_used * ${nominal_gas_tax_`dollar_year'})
			replace `c'_rbd = (gallons_used_rbd * ${nominal_gas_tax_`dollar_year'})
			
		}
		
		if inlist("`c'", "savings") {
			
			replace `c' = (gallons_used * ${nominal_gas_price_`dollar_year'})
			replace `c'_rbd = (gallons_used_rbd * ${nominal_gas_price_`dollar_year'})
			
		}
		
		if inlist("`c'", "CO2") {
			
			replace `c' = (gallons_used * (wtp_global / (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}}))))
			replace `c'_rbd = (gallons_used_rbd * (wtp_global / (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}}))))
			
		}	
		
		if inlist("`c'", "gallons") {
			
			replace `c' = gallons_used
			replace `c'_rbd = gallons_used_rbd
			
		}					
		
		if inlist("`c'", "mpg") {
			
			continue
			
		}
		
	}	

	ds *rbd* *rebound*
	foreach var in `r(varlist)' {
		
		assert `var' == 0 if age == `avg_c4c_scrap_age'

	}
		
	****************************************************
	/* 3f. Find Net Change in Componnets over Acceleration Period.  */
	****************************************************
	foreach c of local components_to_calculate {
		
		replace `c' = `c' * -1 if age == 1
		
		if "`c'" != "mpg" {
			
			local acceleration_`c'_rbd = `c'_rbd
			
		}
		
	}

	collapse (sum) total global local CO2 profits gallons local_driving taxes savings (mean) mpg

	foreach c of local components_to_calculate {
		
		local acceleration_`c' = `c'
		
	}
	drop mpg

	****************************************************
	/* 4. Account for Lifetime Benefits.  */
	****************************************************
	use "`replacement_vehicle_damages'", clear
	keep if age != `avg_c4c_scrap_age'
	drop wtp_local* wtp_global wtp_total *vmt*

	replace mpg = `unadj_new_mpg' // Going back to baseline new MPG before C4C induced improvement. To begin, we new average vehicle starting in dollar year + 1 w/o fuel economy improvement.
	// 		assert round(mpg, 0.001) == round(`mpg_old', 0.001)

	*******************************************************************************
	/* 4a. Everything Expressed in Nominal Dollars; Convert to SCC Dollar Year. */
	*******************************************************************************		
	ds year mpg age, not
	foreach var in `r(varlist)' {
		
		qui replace `var' = `var' * (${cpi_${sc_dollar_year}} / ${cpi_`dollar_year'}) // All in 2020 dollars (${sc_dollar_year}).
		
	}

	*******************************************************************************
	/* 4b. Account for Changes during Acceleration Period. */
	*******************************************************************************	
	if ${months_accelerated} > 0 {

		replace year = year + 1 // Assume acceleration takes up remainder of starting year. If year is 2020, and you accelerate 6 months, you purchased new car on July 1.
			local year_adj = year[1]
		local age_lower_bound = age + 1	
		
	}

	if ${months_accelerated} == 0 {
		
		local age_lower_bound = age + 1
		local year_adj = year[1]
		
	}

	// Code below handles decay during first year and changing social costs.
	local to_adjust			NOx VOC CO
	foreach p of local to_adjust {
		
		if inlist("`p'", "NOx") {
			
			local pre_adjust_`p' = wtp_`p'[1]
			
		}
		
		if !inlist("`p'", "NOx") {
			
			local pre_adjust_`p'_local = local_`p'[1]
			local pre_adjust_`p'_global = global_`p'[1]
			
		}
		
	}

	*******************************************************************************
	/* 4c. Import VMT (Varies with Counterfactual). */
	*******************************************************************************	
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
			qui replace year = (year[1] + `a') - age[1] if age == `a'
		}
		
		if "`cf'" == "fleet_avg" {
			qui replace year = (year[1] + (`a' - `fleet_avg_age')) if age == `a'
		}
			
	}
	assert _N == ${vehicle_`veh_lifespan_type'_lifetime}	
	qui replace mpg = mpg[1] // Assuming no decay in fuel-economy of vehicle.

	qui sum year
		assert year == (year[1] + age - age[1]) if ${months_accelerated} > 0
		assert year == (year[1] + age - age[1]) if ${months_accelerated} == 0

			
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

	if ${months_accelerated} > 6 {
		
		replace age = age + 1 if ${months_accelerated} < 12 // Only built to handle acceleration less than one year.
		
	}
		
	*******************************************************************************
	/* 4d. Deal with Static Externalities. */
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
	/* 4e. Deal with Time-varying Externalities. */
	***********************************************		
	local adj_ext			CO2 N2O CH4 NOx CO VOC

	levelsof(year), local(y_loop)
	qui foreach p of local adj_ext {
		
		if inlist("`p'", "CO2", "CH4", "N2O") { // Social costs rising over time; All expressed in 2020 dollars already.
			
			levelsof(year), local(y_loop)
			foreach y of local y_loop {
								
				replace wtp_`p' = wtp_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
				replace wtp_upstream_`p' = wtp_upstream_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
					
			}
		
		}
			
		if "`p'" == "NOx" { 
			
			foreach y of local y_loop {
				
				qui sum age if year == `y'
					local age_ind = r(mean)
				
				replace wtp_`p' = `pre_adjust_NOx' * ((1 + ${`p'_decay})^(`age_ind' - 1)) if year == `y' & age <= ${decay_age_cutoff}
				replace wtp_`p' = `pre_adjust_NOx' * ((1 + ${`p'_decay})^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
				
				replace wtp_upstream_`p' = wtp_upstream_`p'[1]
				
			}	
			
		}


		if "`p'" == "VOC" | "`p'" == "CO" {
						
			replace local_`p'_upstream = local_`p'_upstream[1] // No changes to local upstream damages over time.

			foreach y of local y_loop {
				
				qui sum age if year == `y'
					local age_ind = r(mean)
				
				if "`p'" == "VOC" {
					local decay = ${HC_decay} // Only doing this step b/c decay factor is named HC_decay, not VOC_decay.
				}
				if "`p'" == "CO" {
					local decay = ${CO_decay}
				}					
				
				replace global_`p'_upstream = global_`p'_upstream[1] * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' 
				// Same approach as upstream CO2 adjustment. GWP already applied in earlier calculations. Scale by annual change in SCC; constant GWP.
				
				** NOTE: THESE ACCOUNT FOR DECAY / RISING SOCIAL COSTS DURING ACCELERATION PERIOD.
				replace global_`p' = `pre_adjust_`p'_global' * ((1 + `decay')^(`age_ind' - 1)) * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' & age <= ${decay_age_cutoff}
				replace global_`p' = `pre_adjust_`p'_global' * ((1 + `decay')^(${decay_age_cutoff} - 1)) * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' & age > ${decay_age_cutoff}
				// VOC decay = HC decay rate. Rising social costs and emission rate.
				
				replace local_`p' = `pre_adjust_`p'_local' * ((1 + `decay')^(`age_ind' - 1)) if year == `y' & age <= ${decay_age_cutoff}
				replace local_`p' = `pre_adjust_`p'_local' * ((1 + `decay')^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
				// No change in VOC's and CO's marginal damages (local). Rising emission rate due to vehicle decay. 
				
			}
			
		}
		
	}

	if ${months_accelerated} < 6 {
		
	// 		assert round(wtp_NOx[1], 0.000001) == round(`pre_adjust_NOx', 0.000001)
	//		
	// 		assert round(local_CO[1], 0.000001) == round(`pre_adjust_CO_local', 0.000001)
	// 		assert round(local_VOC[1], 0.000001) == round(`pre_adjust_VOC_local', 0.000001)
	//		
	// 		assert round(global_CO[1], 0.000001) == round(`pre_adjust_CO_global' * (${sc_CO2_`year_adj'}/${sc_CO2_`dollar_year'}), 0.000001)
	// 		assert round(global_VOC[1], 0.000001) == round(`pre_adjust_VOC_global' * (${sc_CO2_`year_adj'}/${sc_CO2_`dollar_year'}), 0.000001)
		
	}

	*******************************************************************************
	/* 4f. Sum Damages to Calculate Total Local / Global Externality.      */
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
		
	***************************************************************
	/* 4g. Calculate Damages over Vehicle Lifetime and Discount. */
	***************************************************************	
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

	foreach c of local components_to_calculate {

		qui levelsof(year), local(year_loop)
		foreach y of local year_loop {
			
			if inlist("`c'", "total", "global", "local") {

				replace `c' = (gallons_used * wtp_`c') / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				
			}

			if inlist("`c'", "local_driving") {
				
				replace `c' = (vmt * wtp_`c') / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				
			}

			if inlist("`c'", "profits") {
				
				replace `c' = (gallons_used * ${nominal_gas_markup_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
			}
			
			if inlist("`c'", "taxes") {
				
				replace `c' = (gallons_used * ${nominal_gas_tax_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
			}
			
			if inlist("`c'", "savings") {
				
				replace `c' = (gallons_used * ${nominal_gas_price_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
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
				
		}

		if "`c'" == "mpg" {
			
			continue
			
		}
		
	}	

	keep total* mpg
	keep if _n == 1

	// Inflation Adjust Back to Dollar Year (from SCC Dollar Year)
	ds *CO2* *profits* *gallons* *taxes* *savings* mpg, not // All either not monetized or nominal already.
	foreach var in `r(varlist)' {
		
		assert substr("`var'", 7, .) == "local" | substr("`var'", 7, .) == "total" | substr("`var'", 7, .) == "global" | substr("`var'", 7, .) == "local_driving"
		replace `var' = `var' * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
		
	}

	***************************************************************
	/* 5. Calculate Lifetime Benefits from Fuel Econ. Improvements */
	***************************************************************	
	local save_mpg_new = `mpg_new'

	ds total*
	foreach var in `r(varlist)' {

		local comp_name = substr("`var'", strlen("total") + 2, .)
		local `comp_name'_old = `var'
					
		if !inlist("`comp_name'", "mpg", "local_driving") {
			
			local `comp_name'_new = (``comp_name'_old' / (1 + `pct_improvement_mpg')) 
			
			if "`comp_name'" == "mpg" {

				assert `save_mpg_new' == `mpg_new'
				
			}
			
		}

		if "`comp_name'" == "local_driving" {
					
			local `comp_name'_new = ``comp_name'_old' // Doesn't vary with fuel economy difference.
				
		}

		local delta_`comp_name' = (``comp_name'_old' - (``comp_name'_new'* (1 + `rebound'))) + `acceleration_`comp_name'' // Adding acceleration benefits here.
		
	}

	// Save Damages w/o Rebound. NOTE: Acceleration Includes Rebound.
	local global_wo_rbd = (`global_old' - `global_new') + (`acceleration_global' + `acceleration_global_rbd')

	local savings_wo_rbd = (`savings_old' - `savings_new') + (`acceleration_savings' + `acceleration_savings_rbd')

	local taxes_wo_rbd = (`taxes_old' - `taxes_new') + (`acceleration_taxes' + `acceleration_taxes_rbd')

	local profits_wo_rbd = (`profits_old' - `profits_new') + (`acceleration_profits' + `acceleration_profits_rbd')

	local carbon_wo_rbd = (`CO2_old' - `CO2_new') + (`acceleration_CO2' + `acceleration_CO2_rbd')


	// Combine Local Pollution and Driving Damages.

	local delta_local = `delta_local' + `delta_local_driving'	
	local local_wo_rbd = (`local_old' - `local_new') + (`local_driving_old' - `local_driving_new') + (`acceleration_local' + `acceleration_local_rbd') + (`acceleration_local_driving' + `acceleration_local_driving_rbd')

	assert `local_wo_rbd' > 0 if `mpg_improvement' > 0

restore

****************************************************
/* 6. Calculate Components and MVPF.  */
****************************************************
if "${value_savings}" == "yes" {
	
	local wtp_savings = `prop_marginal' * `delta_savings'
	
}
else {
	
	local wtp_savings = 0
	
}


local wtp_soc_global = `delta_global' * `prop_marginal'
local CO2_abated = `delta_CO2' * `prop_marginal'
local wtp_soc_local = `delta_local' * `prop_marginal'

local wtp_producers = ((`delta_profits' * (1 - ${gasoline_effective_corp_tax})) * -1) * `prop_marginal'

local wtp_marginal = 0
local wtp_inframarginal = (`federal_rebate' * (${cpi_`dollar_year'}/${cpi_${policy_year}}))

local total_wtp = `wtp_marginal' + `wtp_inframarginal' + `wtp_producers' + `wtp_soc_local' + /// 
				  (`wtp_soc_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + ///
				  `wtp_savings'


local program_cost = (`federal_rebate' * (${cpi_`dollar_year'}/${cpi_${policy_year}}))

local fiscal_externality_tax = (`delta_taxes' + (`delta_profits' * ${gasoline_effective_corp_tax})) * `prop_marginal'
	
local fiscal_externality_lr = -`wtp_soc_global' * ${USShareFutureSSC} * ${USShareGovtFutureSCC} // Already scaled by share marginal.
			
if "${value_profits}" == "no" {
	
	local wtp_producers = 0
	local fiscal_externality_tax = `delta_taxes' * `prop_marginal'
	
}

local total_wtp = `wtp_marginal' + `wtp_inframarginal' + `wtp_producers' + `wtp_soc_local' ///
					+ (`wtp_soc_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) ///
					+ `wtp_savings'	

local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_lr'
		
local MVPF = `total_wtp' / `total_cost'
			
local WTP_USPres = `wtp_marginal' + `wtp_inframarginal' + `wtp_producers' + `wtp_soc_local' + `wtp_savings'
local WTP_USFut = (`wtp_soc_global' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
local WTP_RoW = (`wtp_soc_global' * (1 - ${USShareFutureSSC}))

// assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW') / `total_cost', 0.1) == round(`MVPF', 0.1)

****************************************
/* 7. Cost-Effectiveness Calculations */
****************************************
local used_sales_2020 = 39.3 // millions
local new_sales_2020 = 14.2 // millions
local used_price_2020 = 27409 // CarGurus
local new_price_2020 = 39592 // KBB
local car_price = (`used_price_2020' * `used_sales_2020' + `new_price_2020' * `new_sales_2020') / (`used_sales_2020' + `new_sales_2020') // average transaction cost

local leasing_cost = ${c4c_interest_rate} * (${months_accelerated} / 12) * `car_price' // interest costs of 2 months, interest is 3%

local cafe_cost = 89.66666666666667 * (${cpi_2020} / ${cpi_2014}) // engineering cost, per mpg
local new_car_cost = `cafe_cost' * (`mpg_new' - `mpg_old')

local lifetime_gas_cost = 0.92 * `savings_wo_rbd' - `taxes_wo_rbd' - `profits_wo_rbd' 

local resource_cost =  `leasing_cost' + `new_car_cost' - `lifetime_gas_cost'
local q_carbon_mck = `carbon_wo_rbd'

local resource_ce = `resource_cost' / `q_carbon_mck'

local gov_carbon = `delta_CO2'

assert `q_carbon_mck' >= `gov_carbon' 

****************************************************
/* 8. Save Results.  */
****************************************************
return scalar MVPF = `MVPF'

return scalar WTP_USPres = `WTP_USPres'
return scalar WTP_USFut  = `WTP_USFut'
return scalar WTP_RoW    = `WTP_RoW'

return scalar WTP = `total_wtp'
return scalar wtp_marg = `wtp_marginal'
return scalar wtp_inf = `wtp_inframarginal'

// WTP Components without Rebound.
return scalar wtp_soc = (`global_wo_rbd' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `local_wo_rbd'
return scalar wtp_soc_global = (`global_wo_rbd' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
return scalar wtp_soc_local = `local_wo_rbd'

return scalar wtp_soc_rbd = (((`global_wo_rbd' - `wtp_soc_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + (`local_wo_rbd' - `wtp_soc_local')) * -1
return scalar wtp_r_glob = ((`global_wo_rbd' - `wtp_soc_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) * -1
return scalar wtp_r_loc = (`local_wo_rbd' - `wtp_soc_local') * -1
	
return scalar wtp_prod = `wtp_producers'
return scalar wtp_prod_s = `wtp_producers'

return scalar program_cost = `program_cost'

return scalar fisc_ext_t = `fiscal_externality_tax'
return scalar fisc_ext_s = 0
return scalar fisc_ext_lr = `fiscal_externality_lr'
return scalar total_cost = `total_cost'

// Do not want rebound effect in resource cost CO2 measures.
return scalar q_CO2 = `prop_marginal' * `carbon_wo_rbd'
return scalar q_CO2_no = `prop_marginal' * `carbon_wo_rbd'

return scalar q_carbon_mck = `q_carbon_mck'
return scalar q_CO2_mck_no = `carbon_wo_rbd'

return scalar resource_cost = `resource_cost'

return scalar c_savings = `delta_savings'

end