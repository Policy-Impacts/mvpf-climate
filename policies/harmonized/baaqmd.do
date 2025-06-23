*************************************************************************************
/*       0. Program: Vehicle Buyback (BAAQMD_Buyback)                      */
*************************************************************************************
/*
Clunkers or Junkers? Adverse Selection in a Vehicle Retirement Program
By Ryan Sandler
https://pubs.aeaweb.org/doi/pdfplus/10.1257/pol.4.4.253
*/

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}

global c4c_interest_rate				0.03 //Assumption about vehicle leasing rate

*********************************
/* 2. Estimates from Paper */
*********************************
/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates. */

if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
*	if ${draw_number} ==1 {
        preserve
            use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
            qui ds draw_number, not 
            global estimates_${name} = r(varlist)
            
            mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
        restore
*	}
    local ests ${estimates_${name}}
    foreach var in `ests' {
        matrix temp = draws_${name}["${draw_number}", "`var'"]
        local `var' = temp[1,1]
    }
}
if "`bootstrap'" == "no" {
    preserve
        
qui import excel "${code_files}/2a_causal_estimates_papers/${folder_name}/${name}.xlsx", clear sheet("wrapper_ready") firstrow        
levelsof estimate, local(estimates)


        foreach est in `estimates' {
            su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

    ****************************************************
    /* 3a. Set Dollar Year and Policy Year */
    ****************************************************
	if "${spec_type}" == "baseline"{
		
		local dollar_year = ${policy_year}
		
	}
	
	if "${spec_type}" == "current"{
		
		local dollar_year = ${today_year}
		
	}

    ****************************************************
    /* 3b. Policy Category Assumptions */
    ****************************************************
    *i. Import car rebate assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("car_rebate")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
	

		local marginal_valuation = ${marg_valuation}
		local prop_marginal = ${prop_marginal}
		

	restore 
	
	
	if "${vehicle_mar_val_chng}" == "yes" {
	
		local marginal_valuation = 0.5
		
}

if "${vehicle_mar_val_chng}" == "no" | "${vehicle_mar_val_chng}" == ""  {
	
		local marginal_valuation = 1
}
    ****************************************************
    /* 3c. Policy Specific Assumptions */
    ****************************************************    
    local year_num = `days_accelerated' / 365 // retire cars 3.8 years earlier
    local age_retired 26 // Assume retired vehicle is 26 years old, as the Buyback Program required vehicles to be from model year 1998 or older in 2023 (BAAQMD 2023)
	
    ****************************************************
    /* 3d. Inflation Adjusted Values */
    ****************************************************
    *Convert rebate to current dollars
    local admin_costs = 240 * (${cpi_`dollar_year'}/${cpi_2000}) // these costs are reported in 2000 $s, Sandler (2012)
	
	if "${spec_type}" == "baseline" | "${spec_type}" == "baseline_gen" {
		local transfer_payment = 500 * (${cpi_`dollar_year'}/${cpi_2000}) // these costs are reported in 2000 $s, Sandler (2012)
	}
	if "${spec_type}" == "current" {
		local transfer_payment = 650 * (${cpi_`dollar_year'}/${cpi_2000}) // these costs are reported in 2000 $s, Sandler (2012)
	}	
	
	local adj_rebate = `transfer_payment'
   
	
************************f****************************
/* 4. Estimate Emissions of Replaced (Old) Vehicle */
****************************************************
preserve

	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_no_ethanol_${scc_ind_name}_${dr_ind_name}.dta", clear
		keep if year == `dollar_year'
		
	local cf new	
	if substr("`cf'", 1, 3) == "new" {
		
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
		keep if model_year == (`dollar_year' - `age_retired') + 1
								
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
			
		if (`dollar_year' - `age_retired') + 1 < `earliest_year' {
			
			ds PM25* CH4 N2O
			foreach var in `r(varlist)' {
				
				qui sum `var' if model_year == `earliest_year'
				replace `var' = r(mean) if model_year == (`dollar_year' - `age_retired') + 1
				
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
		keep if model_year == (`dollar_year' - `age_retired') + 1
		
		// Converting from g/gallon to tons/gallon. 
		qui ds mpg *_gal
		foreach var in `r(varlist)' {
			
			qui replace `var' = `var'/1000000 if `var' != mpg
			local `var' = r(mean)
			
		}	
		
		*************************************************
		/* Account for Vehicle Decay (Until Age 19). */
		*************************************************	
		gen age = `age_retired'
		gen decay_ind = age - 1
		replace decay_ind = ${decay_age_cutoff} if age > ${decay_age_cutoff}
		replace decay_ind = 0 if model_year < 1975 // Cars pre-1975 don't decay because they didn't have modern emission abatement technologies.

		replace CO_gal = CO_gal * (1 + ${CO_decay})^(decay_ind)		
		replace NOx_gal = NOx_gal * (1 + ${NOx_decay})^(decay_ind)		
		replace VOC_gal = VOC_gal * (1 + ${HC_decay})^(decay_ind)	
		
		drop age decay_ind

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
		assert model_year == (`dollar_year' - `age_retired') + 1
		gen year = `dollar_year'
		order year model_year
		merge 1:1 year using "`upstream_save'", nogen noreport assert(3)
		cap drop wtp_upstream_CO
		cap drop wtp_upstream_VOC
	}

	*******************************************************************************
	**# /* Account for Changing Social Costs. */
	*******************************************************************************			
	// Handle changes over vehicle lifetime the same for all counterfactuals, with exception of VMT.
	cap drop wtp_upstream_VOC wtp_upstream_CO *accidents *congestion // Need to keep local and global damages split.
	qui ds
	local numvars : word count `r(varlist)'
	cap drop model_year
	
	// Adjust for Ethanol
	
	****************************************************
	/* Adjust Components Proportional to Gas Usage.  */
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
	/* Adjust Local Pollution using % Change Estimates.  */
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

	local upstream_CO2_ethanol = (((${upstream_CO2_intensity_`dollar_year'} + ${luc_CO2_intensity}) * ${mj_per_gal_ethanol})/1000000) * (${sc_CO2_`dollar_year'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}}))
	// Grams per MJ, multiplied by MJ per/gallon of ethanol, converted to tons, multiplied by SCC.
	
	replace wtp_upstream_CO2 = wtp_upstream_CO2 + (`upstream_CO2_ethanol' * share_ethanol)
	// Already scaled down petroleum upstream emissions by share petroleum; now adding upstream ethanol emissions.
	
	drop wtp_CO wtp_VOC share_ethanol
				
	*******************************************************************************
	/* Everything Expressed in Nominal Dollars; Convert to SCC Dollar Year. */
	*******************************************************************************		
	ds year mpg, not
	foreach var in `r(varlist)' {
		
		qui replace `var' = `var' * (${cpi_${sc_dollar_year}} / ${cpi_`dollar_year'}) // All in 2020 dollars (${sc_dollar_year}).
		
	}
	
	gen age = .
	replace age = `age_retired' if _n == 1
	order year age
	insobs 3, after(1)
	replace age = (age[1] + _n - 1)
	replace age = `age_retired' + `year_num' - 1 if _n == 4 // Not retiring exactly 4 years early.
	pause
	replace mpg = mpg[1]
	replace year = year[1] + _n - 1
			
	*******************************************************************************
	/* Import VMT (Varies with Counterfactual). */
	*******************************************************************************	
	gen vmt = .
	gen days = 365 * (age - age[_n - 1])	
	replace days = 365 if _n == 1
	order year days age vmt
	replace vmt = (`miles_abated')/(`year_num' * 365) * days
	egen vmt_check = total(vmt)
	drop vmt_check days
				
	*******************************************************************************
	/* Deal with Static Externalities. */
	*******************************************************************************		
	local no_adj_ext		SO2 PM25 NH3
	qui foreach p of local no_adj_ext {
		
		if inlist("`p'", "SO2") {
			
			replace wtp_`p' = wtp_`p'[1]
			replace wtp_upstream_`p' = wtp_upstream_`p'[1]
			
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
	/* Deal with Time-varying Externalities. */
	***********************************************		
	local adj_ext			CO2 N2O CH4 NOx CO VOC
	
	foreach p of local adj_ext {
		
		if inlist("`p'", "CO2", "CH4", "N2O") { // Social costs rising over time; All expressed in 2020 dollars already.
			
			levelsof(year), local(y_loop)
			foreach y of local y_loop {
				
				qui sum year 
				assert `dollar_year' == r(min)
				
				replace wtp_`p' = wtp_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
				replace wtp_upstream_`p' = wtp_upstream_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
					
			}
		
		}
			
		if "`p'" == "NOx" { // Vehicle has finished decaying
			
			foreach y of local y_loop {
				
				replace wtp_`p' = wtp_`p'[1] 			
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
				
				replace global_`p'_upstream = global_`p'_upstream[1] * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' 
				// Same approach as upstream CO2 adjustment. GWP already applied in earlier calculations. Scale by annual change in SCC; constant GWP.
				
				replace global_`p' = global_`p'[1] * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' 
				// VOC decay = HC decay rate. Rising social costs and emission rate. Vehicle has stopped decaying.
				
				replace local_`p' = local_`p'[1] 
				// No change in VOC's and CO's marginal damages (local). Vehicle has stopped decaying. 
				
			}
			
		}
		
	}	
					
	*******************************************************************************
	/*      Sum Damages to Calculate Total Local / Global Externality.      */
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
	
	local wtp_accidents_mi = ${accidents_per_mi} // In 2020 dollars already, from gas_vehicle_externalities file.
	local wtp_congestion_mi = ${congestion_per_mi} // In 2020 dollars already, from gas_vehicle_externalities file.
	local wtp_PM25_TBW_mi = wtp_PM25_TBW / mpg // Calculated above, after all expressed in 2020 dollars.
	
	gen wtp_local_per_mi = `wtp_accidents_mi' + `wtp_congestion_mi' + `wtp_PM25_TBW_mi' // Does not vary over time.
	
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		qui sum wtp_local if year == `y'
			di in red "Local Pollution in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
			
		qui sum wtp_global if year == `y'
			di in red "Global Pollution in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
		
		qui sum wtp_local_per_mi if year == `y'
			di in red "Local Driving in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
		
	}
	
	keep year age vmt mpg wtp_total wtp_local* wtp_global
	gen gallons_used = vmt / mpg
		
	*******************************************************************************
	/*         Calculate Damages over Vehicle Lifetime and Discount.         */
	*******************************************************************************	
	local components_to_calculate total global local CO2 profits gallons taxes savings mpg local_driving
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
				
				replace `c' = (vmt * wtp_local_per_mi) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				
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
			global old_`c' = total_`c' 
			global old_`c'_rbd = 0
			
			if inlist("`c'", "global", "local", "local_driving") {
				di in red "`c'"
				di in red ${old_`c'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
			}
				
		}

		if "`c'" == "mpg" {
			
			global old_`c' = mpg 
			
		}
		
	}	
		
****************************************************
/* 5. Estimate Emissions of Replacement (New) Vehicle */
****************************************************
use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", clear
collapse (mean) age [aw=age_share]
assert age + `year_num' < ${decay_age_cutoff}

	****************************************************
	/* Estimate Emissions of Replacement (New) Vehicle -- Assuming Fleet Average */
	****************************************************
	use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", clear			
	keep if year == `dollar_year'
	drop CO2_total wtp_total wtp_local wtp_global *accidents *congestion wtp_CO wtp_VOC 
	qui ds
	local numvars : word count `r(varlist)'
	
	drop wtp_upstream_CO wtp_upstream_VOC share_ethanol
	
	// Already ethanol-adjusted b/c using fleet average.

	*******************************************************************************
	/* Everything Expressed in Nominal Dollars; Convert to SCC Dollar Year. */
	*******************************************************************************		
	ds year mpg, not
	foreach var in `r(varlist)' {
		
		qui replace `var' = `var' * (${cpi_${sc_dollar_year}} / ${cpi_`dollar_year'}) // All in 2020 dollars (${sc_dollar_year}).
		
	}
	
	gen age = .
	replace age = 1
	order year age
	insobs 3, after(1)
	replace age = (age[1] + _n - 1)
	replace age = `year_num' if _n == 4 // Not retiring exactly 4 years early.
	replace mpg = mpg[1]
	replace year = year[1] + _n - 1

	*******************************************************************************
	/* Import VMT (Varies with Counterfactual). */
	*******************************************************************************	
	gen vmt = .
	gen days = 365 * (age - age[_n - 1])	
	replace days = 365 if _n == 1
	order year days age vmt
	replace vmt = (`miles_abated')/(`year_num' * 365) * days

		egen vmt_check = total(vmt)
			drop vmt_check days
					
			
	*******************************************************************************
	/* Deal with Static Externalities. */
	*******************************************************************************		
	local no_adj_ext		SO2 PM25 NH3
	qui foreach p of local no_adj_ext {
		
		if inlist("`p'", "SO2") {
			
			replace wtp_`p' = wtp_`p'[1]
			replace wtp_upstream_`p' = wtp_upstream_`p'[1]
			
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
	/* Deal with Time-varying Externalities. */
	***********************************************		
	local adj_ext			CO2 N2O CH4 NOx CO VOC
	
	qui foreach p of local adj_ext {
		
		if inlist("`p'", "CO2", "CH4", "N2O") { // Social costs rising over time; All expressed in 2020 dollars already.
			
			levelsof(year), local(y_loop)
			foreach y of local y_loop {
				
				qui sum year 
				assert `dollar_year' == r(min)
				
				replace wtp_`p' = wtp_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
				replace wtp_upstream_`p' = wtp_upstream_`p'[1] * (${sc_`p'_`y'}/${sc_`p'_`dollar_year'}) if year == `y'
					
			}
		
		}
			
		if "`p'" == "NOx" { // Vehicle decaying, damages constant; NOT decaying 1st year.
			
			foreach y of local y_loop {
				
				replace wtp_`p' = wtp_`p'[1] * ((1 + ${`p'_decay})^(age - 1)) if year == `y' & age <= ${decay_age_cutoff}
				replace wtp_`p' = wtp_`p'[1] * ((1 + ${`p'_decay})^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
				assert `y' - `dollar_year' == age - 1 if year == `y' & _n != 4
				
				
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
				
				replace global_`p'_upstream = global_`p'_upstream[1] * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' 
				// Same approach as upstream CO2 adjustment. GWP already applied in earlier calculations. Scale by annual change in SCC; constant GWP.
				
				replace global_`p' = global_`p'[1] * ((1 + `decay')^(age - 1)) * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' & age <= ${decay_age_cutoff}
				replace global_`p' = global_`p'[1] * ((1 + `decay')^(${decay_age_cutoff} - 1)) * (${sc_CO2_`y'}/${sc_CO2_`dollar_year'}) if year == `y' & age > ${decay_age_cutoff}
				assert `y' - `dollar_year' == age - 1 if year == `y' & _n != 4
				// VOC decay = HC decay rate. Rising social costs and emission rate.
				
				replace local_`p' = local_`p'[1] * ((1 + `decay')^(age - 1)) if year == `y' & age <= ${decay_age_cutoff}
				replace local_`p' = local_`p'[1] * ((1 + `decay')^(${decay_age_cutoff} - 1)) if year == `y' & age > ${decay_age_cutoff}
					assert `y' - `dollar_year' == age - 1 if year == `y' & _n != 4
				// No change in VOC's and CO's marginal damages (local). Rising emission rate due to vehicle decay. 
				
			}
			
		}
		
	}	
	
	*******************************************************************************
	/*      Sum Damages to Calculate Total Local / Global Externality.           */
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
	
	local wtp_accidents_mi = ${accidents_per_mi} // In 2020 dollars already, from gas_vehicle_externalities file.
	local wtp_congestion_mi = ${congestion_per_mi} // In 2020 dollars already, from gas_vehicle_externalities file.
	local wtp_PM25_TBW_mi = wtp_PM25_TBW / mpg // Calculated above, after all expressed in 2020 dollars.
	
	gen wtp_local_per_mi = `wtp_accidents_mi' + `wtp_congestion_mi' + `wtp_PM25_TBW_mi' // Does not vary over time.	
	
	levelsof(year), local(year_loop)
	foreach y of local year_loop {
		
		qui sum wtp_local if year == `y'
			di in red "Local Pollution in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
			
		qui sum wtp_global if year == `y'
			di in red "Global Pollution in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
		
		qui sum wtp_local_per_mi if year == `y'
			di in red "Local Driving in `y'"
			di in red r(mean) * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}}) 
		
	}
	
	keep year age *vmt* mpg wtp_total wtp_local* wtp_global
	
	// Replacement vehicle should have fleet-wide averages in year one. 
	assert round(wtp_global[1], 0.001) == round(${gas_ldv_ext_global_`dollar_year'} * (${cpi_2020}/${cpi_`dollar_year'}), 0.001)
	
	*******************************************************************************
	/*         Account for Per-Mile Externalities if Accounting for Rebound.         */
	*******************************************************************************	
	local cost_of_driving_change = ((${nominal_gas_price_`dollar_year'}/mpg) - (${nominal_gas_price_`dollar_year'}/${old_mpg}))/(${nominal_gas_price_`dollar_year'}/${old_mpg})
	local vmt_change = `cost_of_driving_change' * ${vmt_rebound_elasticity}
	
	gen rebound_vmt = (vmt * (1 + `vmt_change')) - vmt
		replace vmt = vmt * (1 + `vmt_change')
		
	gen gallons_used = vmt / mpg	
	gen rebound_gallons = rebound_vmt / mpg		
	
	di in red `cost_of_driving_change'
	di in red `vmt_change'
	
	*******************************************************************************
	/*         Calculate Damages over Vehicle Lifetime and Discount.         */
	*******************************************************************************	
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
	
		qui levelsof(year), local(year_loop)
		foreach y of local year_loop {
			
			if inlist("`c'", "total", "global", "local") {

				replace `c' = (gallons_used * wtp_`c') / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				replace `c'_rbd = (rebound_gallons * wtp_`c') / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				
			}
			
			if inlist("`c'", "local_driving") {
				
				replace `c' = (vmt * wtp_local_per_mi) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.
				replace `c'_rbd = (rebound_vmt * wtp_local_per_mi) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // IN SCC DOLLAR YEAR DOLLARS.				
				
			}

			if inlist("`c'", "profits") {
				
				replace `c' = (gallons_used * ${nominal_gas_markup_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				replace `c'_rbd = (rebound_gallons * ${nominal_gas_markup_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
			}
			
			if inlist("`c'", "taxes") {
				
				replace `c' = (gallons_used * ${nominal_gas_tax_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				replace `c'_rbd = (rebound_gallons * ${nominal_gas_tax_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
			}
			
			if inlist("`c'", "savings") {
				
				replace `c' = (gallons_used * ${nominal_gas_price_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				replace `c'_rbd = (rebound_gallons * ${nominal_gas_price_`dollar_year'}) / ((1 + `discount')^(`y' - `dollar_year')) if year == `y' // NOMINAL DOLLARS.
				
			}
			
			if inlist("`c'", "CO2") {
				
				replace `c' = (gallons_used * (wtp_global / ${sc_CO2_`y'})) if year == `y' // Not discounting CO2 (b/c in tons).
				replace `c'_rbd = (rebound_gallons * (wtp_global / ${sc_CO2_`y'})) if year == `y' // Not discounting CO2 (b/c in tons).
				
			}	
			
			if inlist("`c'", "gallons") {
				
				replace `c' = gallons_used if year == `y' // Not discounting gallons.
				replace `c'_rbd = rebound_gallons if year == `y' // Not discounting gallons.
				
			}					
			
			if inlist("`c'", "mpg") {
				
				continue
				
			}
			
		}
		
	}	
			
	foreach c of local components_to_calculate {
	
		if "`c'" != "mpg" {
			
			egen total_`c' = total(`c')
			egen total_`c'_rbd = total(`c'_rbd)
			drop `c'
			
			global new_`c' = total_`c' 
			global new_`c'_rbd = total_`c'_rbd
			
			if inlist("`c'", "global", "local", "local_driving") {
				di in red "`c'"
				di in red ${new_`c'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
				di in red ${new_`c'_rbd} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})
			}
		
		}

		if "`c'" == "mpg" {
			
			global new_`c' = mpg 
			
		}
		
	}	
				
	*******************************************************************************
	/*  6.  Collect Results.         */
	*******************************************************************************		
	clear
	insobs 2
	gen vehicle_type = ""
	replace vehicle_type = "old" if _n == 1
	replace vehicle_type = "new" if _n == 2

	qui foreach c of local components_to_calculate {
		
		gen `c' = .
		if "`c'" != "mpg" {
			
			gen `c'_rbd = .
			
		}

		levelsof(vehicle_type), local(v_loop)
		foreach v of local v_loop {
			
			if "`c'" != "mpg" {
				
				replace `c' = (${`v'_`c'} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}})) if vehicle_type == "`v'" & inlist("`c'", "global", "local", "total", "local_driving")
				replace `c'_rbd = (${`v'_`c'_rbd} * (${cpi_`dollar_year'}/${cpi_${sc_dollar_year}})) if vehicle_type == "`v'" & inlist("`c'", "global", "local", "total", "local_driving")
				// Inflation adjusting back to dollar year.
			
				
				replace `c' = (${`v'_`c'}) if vehicle_type == "`v'" & inlist("`c'", "mpg", "gallons", "savings", "taxes", "profits", "CO2")
				replace `c'_rbd = (${`v'_`c'_rbd}) if vehicle_type == "`v'" & inlist("`c'", "gallons", "savings", "taxes", "profits", "CO2")
				// Already in nominal dollars.
				
			}
			
			if "`c'" == "mpg" {
				
				replace `c' = (${`v'_`c'}) if vehicle_type == "`v'" & inlist("`c'", "mpg")
				
			}
			
		}
		
	}	
	order vehicle_type mpg

	*********************************
	/* 7. Intermediate Calculations */
	*********************************
	*Environmental Benefit
	local local_benefit = (local[1] - local[2]) + (local_driving[1] - local_driving[2])
	local local_rbd = -(local_rbd[2] + local_driving_rbd[2])
	local global_benefit = global[1] - global[2]
	local global_rbd = -global_rbd[2]

	local tax_rev_loss = (taxes[1] - taxes[2]) + ((profits[1] - profits[2]) * ${gasoline_effective_corp_tax})
	local tax_rev_loss_no_rbd = (taxes[1] - taxes[2] + taxes_rbd[2]) + ((profits[1] - profits[2] + profits_rbd[2]) * ${gasoline_effective_corp_tax})	
	local profit_loss = ((profits[1] - profits[2]) * (1 - ${gasoline_effective_corp_tax})) * -1
	local profit_loss_no_rbd = ((profits[1] - profits[2] + profits_rbd[2]) * (1 - ${gasoline_effective_corp_tax})) * -1

	local carbon_reduced = CO2[1] - CO2[2]
	local carbon_rbd = -CO2_rbd[2]

	local gas_private_savings = savings[1] - savings[2]
	local gas_private_savings_no_rbd = savings[1] - savings[2] + savings_rbd[2]

	pause

	di in red `global_benefit'
	di in red `global_benefit' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
	di in red (local[1] - local[2])
	di in red (local_driving[1] - local_driving[2])
	di in red `local_benefit'
	
restore
**************************
/* 8. Cost Calculations  */
**************************
local program_cost = `adj_rebate' + `admin_costs'
local fiscal_externality_tax = (`prop_marginal' * `tax_rev_loss')

*************************
/* 9. WTP Calculations */
*************************
*Consumers
local inframarginal = `adj_rebate' * `marginal_valuation'

local marginal =  0

* Social Costs
local local_pollutants = `prop_marginal' * `local_benefit'
local global_pollutants = `prop_marginal' * `global_benefit'
local carbon_reduction = `prop_marginal' * `carbon_reduced'
local producers = `prop_marginal' * `profit_loss'

if "${value_profits}" == "no" {
	
	local producers = 0
	local fiscal_exernality_corp = 0	
	
}

if "${value_savings}" == "yes" {
	
	local wtp_savings = `prop_marginal' * `gas_private_savings'
	
}
else {
	
	local wtp_savings = 0
	
}



* Social benefits from reduced carbon 
local WTP = `marginal' + `inframarginal' + ///
			(`global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `local_pollutants' + `producers' + `wtp_savings'

// Quick decomposition
local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' + `producers' + `wtp_savings'
local WTP_USFut = `global_pollutants' * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = (1-(${USShareFutureSSC})) * `global_pollutants' 

local fiscal_externality_lr = -`global_pollutants' * (${USShareFutureSSC} * ${USShareGovtFutureSCC})


**************************
/* 10. MVPF Calculations */
**************************
local total_cost = `program_cost' + `fiscal_externality_lr' + `fiscal_externality_tax' 

local MVPF = `WTP'/`total_cost'
di in red `MVPF'

assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW')/`total_cost', 0.1) == round(`MVPF', 0.1)

****************************************
/* 11. Cost-Effectiveness Calculations */
****************************************
local used_sales_2020 = 39.3 // millions, sale numbers from Statista
local new_sales_2020 = 14.2 // millions, sale numbers from Statista
local used_price_2020 = 27409 // CarGurus
local new_price_2020 = 39592 // KBB
local car_price = (`used_price_2020' * `used_sales_2020' + `new_price_2020' * `new_sales_2020') / (`used_sales_2020' + `new_sales_2020') // average transaction cost

local leasing_cost = ${c4c_interest_rate} * (`days_accelerated' / 365) * `car_price' // interest is 3% 
di in red "days accelerated is `days_accelerated'"
di in red "leasing cost is `leasing_cost'"

local lifetime_gas_savings = 0.92 * `gas_private_savings_no_rbd' - `tax_rev_loss_no_rbd' +  `profit_loss_no_rbd' //economy-wide 8% markup from De Loecker et al. (2020)
di in red "gas savings are `gas_private_savings_no_rbd'"
di in red "tax revenue is `tax_rev_loss_no_rbd'"
di in red "profit loss is `profit_loss_no_rbd'"
di in red "gas savings are `lifetime_gas_savings'"

local resource_cost = `leasing_cost' - `lifetime_gas_savings'
di in red "resource cost is `resource_cost'"
local q_carbon_mck = (`carbon_reduced' - `carbon_rbd')

di in red "carbon is `q_carbon_mck'"

local resource_ce = `resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"
pause

local gov_carbon = `prop_marginal' * `carbon_reduced'
assert `q_carbon_mck' >= `gov_carbon'

****************
/* 12. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global program_cost_`1' = `program_cost'

global wtp_marg_`1' = `marginal' 
global wtp_inf_`1' = `inframarginal'

global wtp_glob_`1' = (`global_pollutants' - `global_rbd'*`prop_marginal') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = (`local_pollutants' - `local_rbd'*`prop_marginal')

global wtp_soc_rbd_`1' = (`global_rbd'*`prop_marginal' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + (`local_rbd'*`prop_marginal')
global wtp_r_glob_`1' = `global_rbd'*`prop_marginal' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_r_loc_`1' = `local_rbd'*`prop_marginal'

	assert round(${wtp_glob_`1'} + ${wtp_loc_`1'} + ${wtp_r_loc_`1'} + ${wtp_r_glob_`1'}, 0.01) == round((`global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + `local_pollutants', 0.01)
	
global wtp_prod_`1' = `producers'

global c_savings_`1' = `prop_marginal' * `gas_private_savings'

global fisc_ext_t_`1' = `fiscal_externality_tax'
global fisc_ext_lr_`1' = `fiscal_externality_lr'

global q_CO2_`1' = `carbon_reduced' *`prop_marginal'
global q_CO2_mck_`1' = `carbon_reduced'
global resource_cost_`1' = -`gas_private_savings'


global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global wtp_prod_s_`1' = `producers'

global admin_cost_`1' = `admin_costs'

global gov_carbon_`1' = `gov_carbon'
global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'