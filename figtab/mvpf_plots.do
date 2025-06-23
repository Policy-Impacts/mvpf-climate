************************************************************************
/* Purpose: Produce MVPF Plots (w/ and w/o Bars) for All MVPF Types */
************************************************************************

************************************************************************
/* Step #0: Set Macros that Will NOT Change. */
************************************************************************
local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

local output_path "${output_fig}/figures_appendix"

if inlist("`3'", "Fig4_scc193", "Fig5a_scc76", "Fig5b_scc337", "Fig8_scc193", "Fig9_scc193") {
	local output_path "${output_fig}/figures_main"
}

local scc = 193
if "`4'" != "" & "`4'" != "split" & "`4'" != "nosplit" {
	local scc = `4'
}

if "`4'" == "split"{
	local RoW_color = "`bar_dark_orange'"
	local output_path "${output_fig}/figures_appendix"
}
else{
	local RoW_color = "`bar_blue'"
}

if "`c(os)'"=="MacOSX" local suf svg
else local suf wmf

************************************************************************
/* Step #0a: Dynamic Folder Selection Logic */
************************************************************************

local selected_data_stub 		`2'

local pattern_suffix = "`selected_data_stub'"
di in yellow "Looking for folders ending with pattern: `pattern_suffix'"

* Find all folders in the results directory that end with the pattern
local results_dir = "${code_files}/4_results"
local folder_list = ""
local folder_dates = ""

* Get list of all subdirectories
qui local folders : dir "`results_dir'" dirs "*"

* Filter folders that end with our pattern and extract timestamps
foreach folder of local folders {
    if regexm("`folder'", "^([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})__`pattern_suffix'$") {
        local timestamp = regexs(1)
        local folder_list = "`folder_list' `folder'"
        local folder_dates = "`folder_dates' `timestamp'"
        di in green "Found matching folder: `folder' (timestamp: `timestamp')"
    }
}

* If no matching folders found, display error and exit
if "`folder_list'" == "" {
    di as error "`pattern_suffix' folder has not been created, please run the masterfile first to create this folder"
    exit 601
}
else {
    * Find the most recent folder by comparing timestamps
    local most_recent_folder = ""
    local most_recent_timestamp = ""
    
    local folder_count : word count `folder_list'
    local date_count : word count `folder_dates'
    
    forvalues i = 1/`folder_count' {
        local current_folder : word `i' of `folder_list'
        local current_timestamp : word `i' of `folder_dates'
        
        * Convert timestamp to comparable format (remove hyphens and underscores)
        local current_numeric = subinstr(subinstr("`current_timestamp'", "-", "", .), "_", "", .)
        
        if "`most_recent_timestamp'" == "" {
            local most_recent_folder = "`current_folder'"
            local most_recent_timestamp = "`current_numeric'"
        }
        else {
            local most_recent_numeric = subinstr(subinstr("`most_recent_timestamp'", "-", "", .), "_", "", .)
            if `current_numeric' > `most_recent_numeric' {
                local most_recent_folder = "`current_folder'"
                local most_recent_timestamp = "`current_numeric'"
            }
        }
    }
    
    local selected_data_stub = "`most_recent_folder'"
    di in green "Selected most recent folder: `selected_data_stub'"
}

************************************************************************
/* Step #0: Set Macros that CAN Change. */
************************************************************************

if "`1'" != ""{
	if "`1'" == "subsidies"{
		local run_subsidies yes
		local run_revenue_raisers no
		local run_international no
	}
	else if "`1'" == "taxes"{
		local run_subsidies no
		local run_revenue_raisers yes
		local run_international no
	}
	else if "`1'" == "intl"{
		local run_subsidies no
		local run_revenue_raisers no
		local run_international yes
	}
}

* setting manually
else{
	local run_subsidies									yes
	local run_revenue_raisers							no
	local run_international								no
	local run_ce_mvpf_plot								no
}

local subsidy_censor_value  						5
local tax_censor_value 								1.5
local international_censor_value 					6 // Differs b/c of how we handle infinite MVPFs.

local include_other_subsidies						no

local nm_mvpf_plot									no

************************************************************************
local plot_name			 		`3'
************************************************************************

************************************************************************
/* Step #1: Merge Output and Policy Details. */
************************************************************************
preserve
	import excel "${code_files}/policy_details_v3.xlsx", clear first
	tempfile policy_labels
	save "`policy_labels'", replace
restore

di in red "selected data stub is `selected_data_stub'"

if "`6'" == "" {
	use "${code_files}/4_results/`selected_data_stub'/compiled_results_all_uncorrected_vJK.dta", clear
}

if "`6'" != "" {
	use "${code_files}/4_results/`selected_data_stub'/compiled_results_all_corrected.dta", clear
	qui sum component_value if program == "federal_ev"
	if `r(N)' > 0 {
		drop if program == "federal_ev"
	}
	
}
merge m:1 program using "`policy_labels'", nogen noreport keep(3)
cap drop if broad_category == "Regulation"

// Save non-marginal MVPFs for later (if toggle enabled).
if "`nm_mvpf_plot'" == "yes" {
	
	preserve
	
		use "${code_files}/4_results/non_marginal/non_marginal_mvpfs_lbd.dta", clear
		
		levelsof(policy), local(nm_loop) 
		foreach p of local nm_loop {
			
			qui sum mvpf if policy == "`p'"
				local `p'_nm_mvpf = r(mean)
			
			
		}
		
		qui sum mvpf if policy == "wind" 
			global nma_wind = `r(mean)' 
			if ${nma_wind} > `subsidy_censor_value' {
				global nma_wind = `subsidy_censor_value'
			}
			
			
		qui sum mvpf if policy == "solar"
			global nma_solar = `r(mean)' 
			if ${nma_solar} > `subsidy_censor_value' {
				global nma_solar = `subsidy_censor_value'
			}
			
		qui sum mvpf if policy == "bevs"
			global nma_bevs = `r(mean)' 	
			if ${nma_bevs} > `subsidy_censor_value' {
				global nma_bevs = `subsidy_censor_value'
			}
			
	restore
	
}


	
************************************************************************
/* Step #2: Clean and Rearrange Data. */
************************************************************************
keep if inlist(component_type, "MVPF", "cost", "WTP_USPres", "WTP_USFut", "WTP_RoW", "WTP", "WTP_cc", "program_cost", "admin_cost")
sort program component_type component_value
qui by program component_type component_value:  gen dup = cond(_N==1,0,_n)
drop if dup > 1
drop dup
		
	************************************************************************
	/* Step #2a: Normalize by Program Cost. */
	************************************************************************
	replace component_value = 0 if (component_type == "admin_cost" & missing(component_value)) | (component_type == "admin_cost" & program == "care")
	
	levelsof(program), local(program_loop)
	foreach p of local program_loop {
		
		qui sum component_value if component_type == "program_cost" & program == "`p'"
		local program_cost = r(mean)

		local normalization = `program_cost'
		replace component_value = component_value / `normalization' if inlist(component_type, "WTP", "WTP_cc", "cost", "WTP_RoW", "WTP_USFut", "WTP_USPres") & program == "`p'"
		
	}
	drop if component_type == "program_cost" | component_type == "admin_cost"

	************************************************************************
	/* Step #2b: Calculate Category Averages. */
	************************************************************************
	preserve
	
		drop if extended == 1
		drop if component_type == "MVPF"
		collapse (mean) component_value (first) broad_category, by(group_label component_type)
		
		gen group_label_code = subinstr(group_label, " ", "", .)
		gen category_avg_MVPF = .
		
		levelsof(group_label_code), local(group_loop)
		qui foreach g of local group_loop {
			
			// Handling policies that have LBD component differently.
			qui sum component_value if component_type == "WTP_cc" & group_label_code == "`g'"
			if r(mean) == . {
				
				qui sum component_value if component_type == "WTP" & group_label_code == "`g'"	
				local avg_wtp = r(mean)

				qui sum component_value if component_type == "cost" & group_label_code == "`g'"	
				local avg_cost = r(mean)
					
				local `g'_MVPF = `avg_wtp' / `avg_cost'
								
			}
			else {
				
				assert inlist("`g'", "WindProductionCredits", "ResidentialSolar", "ElectricVehicles", "HybridVehicles")
				
				qui sum component_value if component_type == "WTP_cc" & group_label_code == "`g'"	
				local avg_wtp = r(mean)
				
				qui sum component_value if component_type == "cost" & group_label_code == "`g'"	
				local avg_cost = r(mean)
					
				local `g'_MVPF = `avg_wtp' / `avg_cost'	
					
			}
			
			replace category_avg_MVPF = ``g'_MVPF' if group_label_code == "`g'"
			di in red "Category average MVPF for `g' is ``g'_MVPF'"			
			
		}
		

		// Handling censoring of category average MVPFs differently for taxes and subsidies.
		replace category_avg_MVPF = 0 if category_avg_MVPF < 0 
		replace category_avg_MVPF = `subsidy_censor_value' if category_avg_MVPF > `subsidy_censor_value' & broad_category == "Subsidies"
		replace category_avg_MVPF = `tax_censor_value' if category_avg_MVPF > `tax_censor_value' & broad_category == "Revenue Raisers"
		
		replace category_avg_MVPF = `international_censor_value' if category_avg_MVPF > `international_censor_value' & broad_category == "International" & category_avg_MVPF == 99999 
		replace category_avg_MVPF = (`international_censor_value' - 1) if category_avg_MVPF > (`international_censor_value' - 1) & broad_category == "International" & category_avg_MVPF != 99999 		
		
		levelsof(group_label_code), local(group_loop)
		qui foreach g of local group_loop {
			
			qui sum category_avg_MVPF if group_label_code == "`g'"
			local `g'_MVPF = r(mean)
			
		}
	restore
	
	************************************************************************
	/* Step #2c: Divide WTP Components by Cost. */
	************************************************************************	
	ds component_value
	foreach var in `r(varlist)' {
		gen `var'_div_cost = .
	}

	levelsof(program), local(program_loop)
	foreach val of local program_loop {
		
		qui sum component_value if component_type == "cost" & program == "`val'"
		local cost_local = r(mean)
		
		local component_loop component_value 
		foreach component of local component_loop {
			qui replace `component'_div_cost = `component' / `cost_local' if program == "`val'" & !inlist(component_type, "MVPF", "cost")
			
		}
		
	}
	
	** Making sure WTPs sum to MVPF.
	bysort program : egen MVPF_check = total(component_value_div_cost) if inlist(component_type, "WTP_USPres", "WTP_USFut", "WTP_RoW")
	levelsof(program), local(program_loop)
	qui foreach p of local program_loop {
		
		qui sum MVPF_check if program == "`p'"
		replace MVPF_check = r(mean) if program == "`p'" & component_type == "MVPF"

		assert round(MVPF, 0.001) == round(MVPF_check, 0.001) if component_type == "MVPF" & MVPF != 99999 & program == "`p'"		
		
	}
	rename MVPF_check MVPF	
		
	local wtp_loop 				WTP_USPres WTP_USFut WTP_RoW
	foreach wtp_val of local wtp_loop {
		
		qui gen `wtp_val' = .
			qui bysort program : replace `wtp_val' = component_value_div_cost if component_type == "`wtp_val'"
			
	}	
	collapse (firstnm) *label* broad_category (mean) MVPF WTP_* extended international regulation table_order, by(program across_group_ordering in_group_ordering)		
	sort across_group_ordering in_group_ordering
	

	
************************************************************************
/* Step #3: Produce MVPF Plot for Subsidies. */
************************************************************************	
preserve
	use "${output_fig}/figures_data/avgs_current_`scc'_yes_no_yes.dta", clear
	levels category, local(categories)
	foreach cat in `categories' {
		qui sum l_MVPF if category == "`cat'"
		local `cat'_l = `r(mean)'
		
		qui sum h_MVPF if category == "`cat'"
		local `cat'_h = `r(mean)'
	}
restore
		
if "`run_subsidies'" == "yes" {
	preserve

		keep if broad_category == "Subsidies"
		drop if extended == 1

		if "`include_other_subsidies'" == "no" {
			
			drop if group_label == "Other Subsidies"
			local OtherSubsidies_max = 1
			local OtherSubsidies_min = 1
			local OtherSubsidies_xpos = -10
			
		}	
			
		gsort -across_group_ordering -in_group_ordering
		gen yaxis = _n


		
		************************************************************************
		/* Step #3a: Insert Blank Observations b/w Categories. */
		************************************************************************	
		levelsof(across_group_ordering), local(group_loop)
		foreach g of local group_loop {
			
			qui sum across_group_ordering
			local max_group_number = r(max)
			
			replace yaxis = _n 
			qui sum yaxis if across_group_ordering == `g'
				
			if `g' != `max_group_number' {
				insobs 1, before(r(min)) 
				replace program_label_long = "— — — — — — — — — — — — — — —" if program_label_long == ""
			}
				
			replace yaxis = _n 
				
		}
		insobs 1, before(1)
		replace yaxis = _n
		replace program_label_long = "— — — — — — — — — — — — — — —" if _n == 1

		************************************************************************
		/* Step #3b: Labeling. */
		************************************************************************
		labmask(yaxis), value(program_label_long)
		qui sum yaxis

		local ylabel_min = r(min)
		local ylabel_max = r(max)
			
		// Horizontal y-axis lines.	
		levelsof(yaxis), local(yloop)
		foreach y of local yloop {
			
			qui sum yaxis if program_label_long == "— — — — — — — — — — — — — — —" & yaxis == `y' & _n != 1
			local yline_list  `"`yline_list' `r(mean)'"'
			
		}		
		
		// Group label positioning.
		gen group_label_code = subinstr(group_label, " ", "", .)
		
		* Check that all expected categories are present
local expected_categories "WindProductionCredits ResidentialSolar ElectricVehicles ApplianceRebates VehicleRetirement HybridVehicles Weatherization"
if "`include_other_subsidies'" == "yes" {
    local expected_categories "`expected_categories' OtherSubsidies"
}

local missing_categories ""
foreach cat of local expected_categories {
    qui count if group_label_code == "`cat'"
    if r(N) == 0 {
        local missing_categories "`missing_categories' `cat'"
    }
}

if "`missing_categories'" != "" {
    di as error "Missing programs, make sure you're running all programs in the masterfile"
    di as error "Missing categories: `missing_categories'"
    exit 601
}

		
		levelsof(group_label_code), local(group_loop)
		foreach g of local group_loop {
			
			qui sum yaxis if group_label_code == "`g'"
			local `g'_xpos = r(mean)
			local `g'_min = r(min) - 1 
			local `g'_max = r(max) + 1	
				
			if "`g'" == "WindProductionCredits" {
			
				qui sum yaxis if group_label_code == "`g'"
				local `g'_min = r(min) - 1 
				local `g'_max = r(max) + 0.25
				
			}

		}
	 
if "`7'" == "categories_only" {
    di "Stopping after category calculations - locals are available"
    
    * Get the SCC value from argument 4 and spec from argument 5
    local scc_value = "`4'"
    local spec = "`5'"
    
    * Save the category averages to a temporary file first
    tempfile temp_cats
    clear
    set obs 0
    gen category = ""
    gen scc = .
    gen scenario = ""
    gen mvpf = .
    
    * Add records for this run
    foreach g of local group_loop {
        local n = _N + 1
        set obs `n'
        replace category = "`g'" in `n'
        replace scc = `scc_value' in `n'
        replace scenario = "`spec'" in `n'
        replace mvpf = ``g'_MVPF' in `n'
        di "Added `g' MVPF for SCC `scc_value', spec `spec': ``g'_MVPF'"
    }
    
    save "`temp_cats'", replace
    
    * Now check if the main file exists and merge if it does
    capture confirm file "category_averages.dta"
    if _rc == 0 {
        * File exists, load it and merge
        use "category_averages.dta", clear
        
        * Get rid of any records that would be duplicated
        drop if (scc == `scc_value' & scenario == "`spec'")
        
        * Append the new records
        append using "`temp_cats'"
        
        save "category_averages.dta", replace
        di "Updated category_averages.dta with new values"
    }
    else {
        * File doesn't exist, just save the temp file as the main file
        use "`temp_cats'", clear
        save "category_averages.dta", replace
        di "Created new category_averages.dta file"
    }
    
    exit
}
		************************************************************************
		/* Step #3c: Censoring and Edge Cases. */
		************************************************************************
		gen negative_WTP = 1 if WTP_USFut < 0 | WTP_RoW < 0 | WTP_USPres < 0
			
		gen base = 0 
		gen bar_USPres = base + WTP_USPres if negative_WTP != 1
		gen bar_USFut = bar_USPres + WTP_USFut if negative_WTP != 1
		gen bar_RoW = bar_USFut + WTP_RoW if negative_WTP != 1
		assert round(MVPF, 0.01) == round(bar_RoW, 0.01) if bar_RoW != .
		replace bar_USPres = 0 if WTP_USPres <= 0
		replace bar_USPres = WTP_USPres + WTP_USFut if (WTP_USPres + WTP_USFut) > 0 & negative_WTP == 1
		replace bar_USFut = WTP_USPres + WTP_USFut if (WTP_USPres + WTP_USFut) > 0 & negative_WTP == 1
		replace bar_RoW = bar_USFut + WTP_RoW if negative_WTP == 1
		replace bar_USFut = WTP_USPres + WTP_USFut + WTP_RoW if WTP_RoW < 0
		replace bar_USPres = WTP_USPres + WTP_USFut + WTP_RoW if WTP_RoW < 0
		replace MVPF = `subsidy_censor_value' if MVPF > `subsidy_censor_value' & MVPF != . & negative_WTP != 1
		ds bar*
		foreach var in `r(varlist)' {
			
			replace `var' = `subsidy_censor_value' if `var' > `subsidy_censor_value' & `var' != .
			
		}
		
		replace MVPF = 0 if MVPF < 0		
		
		************************************************************************
		/* Step #3d: Produce figure w/ bars. */
		************************************************************************
		tw	///
			(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///	
			(rbar base bar_USPres yaxis, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
			(rbar bar_USPres bar_USFut yaxis, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
			(rbar bar_USFut bar_RoW yaxis, horizontal barw(0.15) color("`RoW_color'") xaxis(1)) ///	
			(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///
			///
			(pci `WindProductionCredits_min' `WindProductionCredits_MVPF' `WindProductionCredits_max' `WindProductionCredits_MVPF', color(black)) ///		
			(pci `ResidentialSolar_min' `ResidentialSolar_MVPF' `ResidentialSolar_max' `ResidentialSolar_MVPF', color(black)) ///	
			(pci `ElectricVehicles_min' `ElectricVehicles_MVPF' `ElectricVehicles_max' `ElectricVehicles_MVPF', color(black)) ///	
			(pci `ApplianceRebates_min' `ApplianceRebates_MVPF' `ApplianceRebates_max' `ApplianceRebates_MVPF', color(black)) ///		
			(pci `VehicleRetirement_min' `VehicleRetirement_MVPF' `VehicleRetirement_max' `VehicleRetirement_MVPF', color(black)) ///
			(pci `HybridVehicles_min' `HybridVehicles_MVPF' `HybridVehicles_max' `HybridVehicles_MVPF', color(black)) ///	
			(pci `Weatherization_min' `Weatherization_MVPF' `Weatherization_max' `Weatherization_MVPF', color(black)) ///	
			(pci `OtherSubsidies_min' `OtherSubsidies_MVPF' `OtherSubsidies_max' `OtherSubsidies_MVPF', color(black)) ///												
			///
			, /// 
			///
			plotregion(margin(l=0 b=0 t=0)) ///
			graphregion(color(white) margin(l=8)) ///
			title(" ") ///
			ytitle(" ") ///
				ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0)) ///
				yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash)) ///
				yscale(range(`ylabel_min' `ylabel_max')) ///
			xtitle("MVPF", axis(1) size(small)) ///
				xscale(range(0 `subsidy_censor_value') axis(1) titlegap(+1.5)) ///
				xlab(0(1)`subsidy_censor_value', axis(1) nogrid) ///
			text(`OtherSubsidies_xpos' -3 "{bf:Other Subsidies}", size(vsmall)) ///
			text(`Weatherization_xpos' -3 "{bf:Weatherization}", size(vsmall)) ///
			text(`HybridVehicles_xpos' -3 "{bf:Hybrid Vehicles}", size(vsmall)) ///
			text(`VehicleRetirement_xpos' -3 "{bf:Vehicle Retirement}", size(vsmall)) ///
			text(`ApplianceRebates_xpos' -3 "{bf:Appliance Rebates}", size(vsmall)) ///
			text(`ElectricVehicles_xpos' -3 "{bf:Electric Vehicles}", size(vsmall)) ///
			text(`ResidentialSolar_xpos' -3 "{bf:Residential Solar}", size(vsmall)) ///
			text(`WindProductionCredits_xpos' -3 "{bf:Wind Production Credits}", size(vsmall)) ///
			legend(off)

		graph export "`output_path'/mvpf_subsidies_`plot_name'.png", replace
		cap graph export "`output_path'/mvpf_subsidies_`plot_name'.wmf", replace
		
				
		************************************************************************
		/* Step #3e: Produce figure w/ non-marginal MVPFs (Wind, Solar, EVs). */
		************************************************************************
		if "`nm_mvpf_plot'" == "yes" {
			
			foreach p of local nm_loop {
				
				replace MVPF =  ``p'_nm_mvpf' if program == "`p'"
				
			}
			replace MVPF = `subsidy_censor_value' if MVPF > `subsidy_censor_value' & MVPF != . & negative_WTP != 1

			local WindProductionCredits_MVPF = ${nma_wind}
			local ResidentialSolar_MVPF = ${nma_solar}
			local ElectricVehicles_MVPF = ${nma_bevs}
				
			tw	///
				(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///	
				(rbar base MVPF yaxis, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
				(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///
				///
				(pci `WindProductionCredits_min' `WindProductionCredits_MVPF' `WindProductionCredits_max' `WindProductionCredits_MVPF', color(black)) ///		
				(pci `ResidentialSolar_min' `ResidentialSolar_MVPF' `ResidentialSolar_max' `ResidentialSolar_MVPF', color(black)) ///	
				(pci `ElectricVehicles_min' `ElectricVehicles_MVPF' `ElectricVehicles_max' `ElectricVehicles_MVPF', color(black)) ///	
				(pci `ApplianceRebates_min' `ApplianceRebates_MVPF' `ApplianceRebates_max' `ApplianceRebates_MVPF', color(black)) ///		
				(pci `VehicleRetirement_min' `VehicleRetirement_MVPF' `VehicleRetirement_max' `VehicleRetirement_MVPF', color(black)) ///
				(pci `HybridVehicles_min' `HybridVehicles_MVPF' `HybridVehicles_max' `HybridVehicles_MVPF', color(black)) ///	
				(pci `Weatherization_min' `Weatherization_MVPF' `Weatherization_max' `Weatherization_MVPF', color(black)) ///	
				(pci `OtherSubsidies_min' `OtherSubsidies_MVPF' `OtherSubsidies_max' `OtherSubsidies_MVPF', color(black)) ///												
				///
				, /// 
				///
				plotregion(margin(l=0 b=0 t=0)) ///
				graphregion(color(white) margin(l=8)) ///
				title(" ") ///
				ytitle(" ") ///
					ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0)) ///
					yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash)) ///
					yscale(range(`ylabel_min' `ylabel_max')) ///
				xtitle("MVPF", axis(1) size(small)) ///
					xscale(range(0 `subsidy_censor_value') axis(1) titlegap(+1.5)) ///
					xlab(0(1)`subsidy_censor_value', axis(1) nogrid) ///
				text(`OtherSubsidies_xpos' -3 "{bf:Other Subsidies}", size(vsmall)) ///
				text(`Weatherization_xpos' -3 "{bf:Weatherization}", size(vsmall)) ///
				text(`HybridVehicles_xpos' -3 "{bf:Hybrid Vehicles}", size(vsmall)) ///
				text(`VehicleRetirement_xpos' -3 "{bf:Vehicle Retirement}", size(vsmall)) ///
				text(`ApplianceRebates_xpos' -3 "{bf:Appliance Rebates}", size(vsmall)) ///
				text(`ElectricVehicles_xpos' -3 "{bf:Electric Vehicles}", size(vsmall)) ///
				text(`ResidentialSolar_xpos' -3 "{bf:Residential Solar}", size(vsmall)) ///
				text(`WindProductionCredits_xpos' -3 "{bf:Wind Production Credits}", size(vsmall)) ///
				legend(off)		
				
			graph export "`output_path'/mvpf_subsidies_`plot_name'_nm.png", replace
			cap graph export "`output_path'/mvpf_subsidies_`plot_name'_nm.wmf", replace
			
		}
		
		************************************************************************
		/* Step #3f: Produce figure w/ CI bars. */
		************************************************************************
		
		gen ci_lb = .
		replace ci_lb = `wind_l' if group_label == "Wind Production Credits" 
		replace ci_lb = `solar_l' if group_label == "Residential Solar" 
		replace ci_lb = `bev_l' if group_label == "Electric Vehicles" 
		replace ci_lb = `hev_l' if group_label == "Hybrid Vehicles" 
		replace ci_lb = `appliance_rebates_l' if group_label == "Appliance Rebates" 
		replace ci_lb = `vehicle_retirement_l' if group_label == "Vehicle Retirement" 
		replace ci_lb = `weatherization_l' if group_label == "Weatherization"     

		gen ci_ub = .

		replace ci_ub = `wind_h' if group_label == "Wind Production Credits" 
		replace ci_ub = `solar_h' if group_label == "Residential Solar" 
		replace ci_ub = `bev_h' if group_label == "Electric Vehicles" 
		replace ci_ub = `hev_h' if group_label == "Hybrid Vehicles" 
		replace ci_ub = `appliance_rebates_h' if group_label == "Appliance Rebates" 
		replace ci_ub = `vehicle_retirement_l' if group_label == "Vehicle Retirement" 
		replace ci_ub = `weatherization_h' if group_label == "Weatherization"

		
		replace ci_ub = `subsidy_censor_value' if ci_ub > `subsidy_censor_value'
		replace ci_lb = `subsidy_censor_value' if ci_lb > `subsidy_censor_value'
		
		replace ci_lb = 0 if ci_lb < 0 

		if "`5'" == "yes_cis"{
		
			tw	///
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `VehicleRetirement_min', `VehicleRetirement_max') & group_label == "Vehicle Retirement", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `Weatherization_min', `Weatherization_max') & group_label == "Weatherization", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///			
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `ApplianceRebates_min', `ApplianceRebates_max') & group_label == "Appliance Rebates", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///			
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `HybridVehicles_min', `HybridVehicles_max') & group_label == "Hybrid Vehicles", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///		
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `ElectricVehicles_min', `ElectricVehicles_max') & group_label == "Electric Vehicles", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///	
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `ResidentialSolar_min', `ResidentialSolar_max') & group_label == "Residential Solar", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///	
				(rarea ci_lb ci_ub yaxis if inrange(yaxis, `WindProductionCredits_min', `WindProductionCredits_max') & group_label == "Wind Production Credits", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///																		
				///
				(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///	
				(rbar base bar_USPres yaxis if negative_WTP != 1, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
				(rbar bar_USPres bar_USFut yaxis if negative_WTP != 1, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
				(rbar bar_USFut bar_RoW yaxis if negative_WTP != 1, horizontal barw(0.15) color("`RoW_color'") xaxis(1)) ///	
				(rbar base MVPF yaxis if negative_WTP == 1, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
				(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///
				///
				(pci `WindProductionCredits_min' `WindProductionCredits_MVPF' `WindProductionCredits_max' `WindProductionCredits_MVPF', color(black)) ///		
				(pci `ResidentialSolar_min' `ResidentialSolar_MVPF' `ResidentialSolar_max' `ResidentialSolar_MVPF', color(black)) ///	
				(pci `ElectricVehicles_min' `ElectricVehicles_MVPF' `ElectricVehicles_max' `ElectricVehicles_MVPF', color(black)) ///	
				(pci `ApplianceRebates_min' `ApplianceRebates_MVPF' `ApplianceRebates_max' `ApplianceRebates_MVPF', color(black)) ///		
				(pci `VehicleRetirement_min' `VehicleRetirement_MVPF' `VehicleRetirement_max' `VehicleRetirement_MVPF', color(black)) ///
				(pci `HybridVehicles_min' `HybridVehicles_MVPF' `HybridVehicles_max' `HybridVehicles_MVPF', color(black)) ///	
				(pci `Weatherization_min' `Weatherization_MVPF' `Weatherization_max' `Weatherization_MVPF', color(black)) ///	
				(pci `OtherSubsidies_min' `OtherSubsidies_MVPF' `OtherSubsidies_max' `OtherSubsidies_MVPF', color(black)) ///												
				///
				, /// 
				///
				plotregion(margin(l=0 b=0 t=0)) ///
				graphregion(color(white) margin(l=8)) ///
				ytitle(" ") ///
					ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0)) ///
					yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash)) ///
					yscale(range(`ylabel_min' `ylabel_max')) ///
				xtitle("MVPF", axis(1) size(small)) ///
					xscale(range(0 `subsidy_censor_value') axis(1) titlegap(+1.5)) ///
					xlab(0(1)`subsidy_censor_value', axis(1)) ///
				text(`OtherSubsidies_xpos' -3 "{bf:Other Subsidies}", size(vsmall)) ///
				text(`Weatherization_xpos' -3 "{bf:Weatherization}", size(vsmall)) ///
				text(`HybridVehicles_xpos' -3 "{bf:Hybrid Vehicles}", size(vsmall)) ///
				text(`VehicleRetirement_xpos' -3 "{bf:Vehicle Retirement}", size(vsmall)) ///
				text(`ApplianceRebates_xpos' -3 "{bf:Appliance Rebates}", size(vsmall)) ///
				text(`ElectricVehicles_xpos' -3 "{bf:Electric Vehicles}", size(vsmall)) ///
				text(`ResidentialSolar_xpos' -3 "{bf:Residential Solar}", size(vsmall)) ///
				text(`WindProductionCredits_xpos' -3 "{bf:Wind Production Credits}", size(vsmall)) ///
				legend(off)
			
			graph export "`output_path'/`plot_name'_mvpf_subsidies_with_CIs.png", replace
			cap graph export "`output_path'/`plot_name'_mvpf_subsidies_with_CIs.wmf", replace

		}

	
	restore
	
}

************************************************************************
/* Step #4: Produce MVPF Plot for International Policies. */
************************************************************************	
if "`run_international'" == "yes" {
	preserve

		keep if broad_category == "International"
		drop if extended == 1
			
		gsort -across_group_ordering -in_group_ordering
		gen yaxis = _n
		
		************************************************************************
		/* Step #4a: Insert Blank Observations b/w Categories. */
		************************************************************************	
		levelsof(across_group_ordering), local(group_loop)
		foreach g of local group_loop {
			
			qui sum across_group_ordering
			local max_group_number = r(max)
			
			replace yaxis = _n 
			qui sum yaxis if across_group_ordering == `g'
				
			if `g' != `max_group_number' {
				insobs 1, before(r(min)) 
				replace program_label_long = "— — — — — — — — — — — — — — —" if program_label_long == ""
			}
				
			replace yaxis = _n 
				
		}
		insobs 1, before(1)
		replace yaxis = _n
		replace program_label_long = "— — — — — — — — — — — — — — —" if _n == 1
		
		************************************************************************
		/*                         Step #4b: Labeling.                        */
		************************************************************************
		labmask(yaxis), value(program_label_long)
		qui sum yaxis
		local ylabel_min = r(min)
		local ylabel_max = r(max)
			
		// Horizontal y-axis lines.	
		levelsof(yaxis), local(yloop)
		foreach y of local yloop {
			
			qui sum yaxis if program_label_long == "— — — — — — — — — — — — — — —" & yaxis == `y' & _n != 1
			local yline_list  `"`yline_list' `r(mean)'"'
			
		}		
		
		// Group label positioning.
		gen group_label_code = subinstr(group_label, " ", "", .)
		levelsof(group_label_code), local(group_loop)
		foreach g of local group_loop {
			
			qui sum yaxis if group_label_code == "`g'"
			local `g'_xpos = r(mean)
			local `g'_min = r(min) - 1 
			local `g'_max = r(max) + 1	
				
			if "`g'" == "Cookstoves" {
			
				qui sum yaxis if group_label_code == "`g'"
				local `g'_min = r(min) - 1 
				local `g'_max = r(max) + 0.25
				
			}

		}
		
		************************************************************************
		/* Step #4c: Censoring and Edge Cases. */
		************************************************************************
		gen negative_WTP = 1 if WTP_USFut < 0 | WTP_RoW < 0 | WTP_USPres < 0
			
		gen base = 0 
		gen bar_USPres = base + WTP_USPres if negative_WTP != 1
		gen bar_USFut = bar_USPres + WTP_USFut if negative_WTP != 1
		gen bar_RoW = bar_USFut + WTP_RoW if negative_WTP != 1
		assert round(MVPF, 0.01) == round(bar_RoW, 0.01) if bar_RoW != .
			
		replace bar_USPres = 0 if negative_WTP == 1
		replace bar_USFut = 0 if negative_WTP == 1 & (WTP_USFut + WTP_USPres) < 0
		replace bar_RoW = WTP_USPres + WTP_USFut + WTP_RoW if negative_WTP == 1 & (WTP_USFut + WTP_USPres) <= 0
		
		replace MVPF = (`international_censor_value' - 1) if MVPF > (`international_censor_value' - 1) & MVPF != . & negative_WTP != 1
		ds bar*
		foreach var in `r(varlist)' {
			
			replace `var' = (`international_censor_value' - 1) if `var' > (`international_censor_value' - 1) & `var' != .
			replace `var' = 0 if `var' < 0
			
		}
		
		// Negative MVPF Censoring.
		replace MVPF = 0 if MVPF < 0
		
		// Handling Infinite MVPFs
		ds bar*
		foreach var in `r(varlist)' {
			
			replace `var' = (`international_censor_value') if `var' > (`international_censor_value') & `var' != . & MVPF == 99999
			
		}	
		replace MVPF = `international_censor_value' if MVPF == 99999
		
		
		************************************************************************
		/* Step #4d: Produce figure w/ bars. */
		************************************************************************
		tw	///
			(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)) ///	
			(rbar base bar_USPres yaxis, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
			(rbar bar_USPres bar_USFut yaxis, horizontal barw(0.15) color("`bar_blue'") xaxis(1)) ///
			(rbar bar_USFut bar_RoW yaxis, horizontal barw(0.15) color("`RoW_color'") xaxis(1)) ///	
			(scatter yaxis MVPF, msize(vtiny) mcolor(black) xaxis(1)), /// 
			plotregion(margin(l=0 b=0 t=0)) ///
			graphregion(color(white) margin(l=8)) ///
			title(" ") ///
				subtitle(" ") ///			
			ytitle(" ") ///
				ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0)) ///
				yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash)) ///
				yscale(range(`ylabel_min' `ylabel_max')) ///
			xtitle("MVPF", axis(1) size(small)) ///
				xscale(range(0 `subsidy_censor_value') axis(1) titlegap(+1.5)) ///
				xlab(0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5", axis(1)) ///
			text(`Cookstoves_xpos' -2.5 "{bf:Cookstoves}", size(vsmall)) ///
			text(`Deforestation_xpos' -2.5 "{bf:Deforestation}", size(vsmall)) ///
			text(`RiceBurning_xpos' -2.5 "{bf:Rice Burning}", size(vsmall)) ///
			text(`WindOffset_xpos' -2.5 "{bf:Wind Offsets}", size(vsmall)) ///
			text(`InternationalRebates_xpos' -2.5 "{bf:Rebates}", size(vsmall)) ///				
			legend(off)

		graph export "`output_path'/mvpf_intl_`plot_name'_with_CIs.png", replace
		cap graph export "`output_path'/mvpf_intl_`plot_name'_with_CIs.wmf", replace
	
	restore
	
}	

************************************************************************
/* Step #5: Revenue Raisers. */
************************************************************************
if "`run_revenue_raisers'" == "yes" {
	

	keep if broad_category == "Revenue Raisers"
	drop if extended == 1
	drop if group_label == "Cap and Trade"
		
	gsort -table_order
	
	************************************************************************
	/* Step #5a: Add Reference Taxes. */
	************************************************************************	
	qui sum across_group_ordering
	local comparison_ordering = r(min) - 1

	
	local ref_policies 	`""Taxes (Low-Income Paycheck+, 2013)" "Taxes (Low-Income EITC, 1993)" "Taxes (Top Earners, 2013)" "Taxes (Top Earners, 1993)""'
	foreach p of local ref_policies {
			
		insobs 1, before(1)
		replace program_label_long = "`p'" if _n == 1
		
		replace MVPF = 1.16 if program_label_long == "Taxes (Top Earners, 2013)"
		
		replace MVPF = 1.85 if program_label_long == "Taxes (Top Earners, 1993)"
		
		replace MVPF = 1.12 if program_label_long == "Taxes (Low-Income EITC, 1993)"
			
		replace MVPF = 1 if program_label_long == "Taxes (Low-Income Paycheck+, 2013)"
			
		replace group_label = "Comparisons" if _n == 1
		replace across_group_ordering = `comparison_ordering' if _n == 1
			
			
	}
	gen yaxis = _n

	************************************************************************
	/* Step #5b: Insert Blank Observations b/w Categories. */
	************************************************************************	
	levelsof(across_group_ordering), local(group_loop)
	foreach g of local group_loop {
		
		qui sum yaxis
		local max_group_number = r(max)
		
		replace yaxis = _n 
		qui sum yaxis if across_group_ordering == `g'
			
		if `g' != `max_group_number' {
			insobs 1, after(r(max)) 
			replace program_label_long = "— — — — — — — — — — — — — — —" if program_label_long == ""
		}
			
		replace yaxis = _n 
			
	}
	
	insobs 1, before(1)
	replace yaxis = _n
	replace program_label_long = "— — — — — — — — — — — — — — —" if _n == 1
	
	qui sum yaxis
	drop if yaxis == r(max) & program_label_long == "— — — — — — — — — — — — — — —"
		
	************************************************************************
	/* Step #5c: Labeling. */
	************************************************************************
	labmask(yaxis), value(program_label_long)
	qui sum yaxis

	local ylabel_min = r(min)
	local ylabel_max = r(max)
		
	// Horizontal y-axis lines.	
	levelsof(yaxis), local(yloop)
	foreach y of local yloop {
		
		qui sum yaxis if program_label_long == "— — — — — — — — — — — — — — —" & yaxis == `y' & _n != 1
		local yline_list  `"`yline_list' `r(mean)'"'
		
	}		
	
	// Group label positioning.
	gen group_label_code = subinstr(group_label, " ", "", .)
	levelsof(group_label_code), local(group_loop)
	foreach g of local group_loop {
		
		qui sum yaxis if group_label_code == "`g'"
		local `g'_xpos = r(mean)
		local `g'_min = r(min) - 1 
		local `g'_max = r(max) + 1	
			
		if "`g'" == "GasolineTaxes" {
		
			qui sum yaxis if group_label_code == "`g'"
			local `g'_min = r(min) - 1 
			local `g'_max = r(max) + 0.25
			
		}

	}
	
	************************************************************************
	/* Step #5d: Make Plot. */
	************************************************************************
	gen base = 1
	gen ci_lb = .

	replace ci_lb =  `gas_tax_l' if group_label == "Gasoline Taxes" 
	replace ci_lb = `other_fuel_taxes_l' if group_label == "Other Fuel Taxes" 
	replace ci_lb = `other_rev_raisers_l' if group_label == "Other Revenue Raisers" 

	gen ci_ub = .

	replace ci_ub = `gas_tax_h' if group_label == "Gasoline Taxes" 
	replace ci_ub = `other_fuel_taxes_h' if group_label == "Other Fuel Taxes" 
	replace ci_ub = `other_rev_raisers_h' if group_label == "Other Revenue Raisers" 
	
	replace ci_ub = `tax_censor_value' if ci_ub > `tax_censor_value'
	replace ci_lb = `tax_censor_value' if ci_lb > `tax_censor_value'
	
	replace ci_lb = 0 if ci_lb < 0 
	
	tw	///
		(rarea ci_lb ci_ub yaxis if inrange(yaxis, `GasolineTaxes_min', `GasolineTaxes_max') & group_label == "Gasoline Taxes", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///
		(rarea ci_lb ci_ub yaxis if inrange(yaxis, `OtherFuelTaxes_min', `OtherFuelTaxes_max') & group_label == "Other Fuel Taxes", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///			
		(rarea ci_lb ci_ub yaxis if inrange(yaxis, `OtherRevenueRaisers_min', `OtherRevenueRaisers_max') & group_label == "Other Revenue Raisers", horizontal fcolor("`bar_blue'") lwidth(none) fintensity(inten50)) ///			
		///																		
		///
		(rbar base MVPF yaxis, horizontal barw(0.15) color("`bar_blue'")) ///
		(scatter yaxis MVPF, msize(tiny) mcolor(black) xaxis(1)) ///		
		///
		(pci `GasolineTaxes_min' `GasolineTaxes_MVPF' `GasolineTaxes_max' `GasolineTaxes_MVPF', color(black)) ///		
		(pci `OtherFuelTaxes_min' `OtherFuelTaxes_MVPF' `OtherFuelTaxes_max' `OtherFuelTaxes_MVPF', color(black)) ///	
		(pci `OtherRevenueRaisers_min' `OtherRevenueRaisers_MVPF' `OtherRevenueRaisers_max' `OtherRevenueRaisers_MVPF', color(black)) ///	
		///
		, /// 
		///
		plotregion(margin(l=0 b=0 t=0)) ///
		graphregion(color(white) margin(l=8)) ///
		ytitle(" ") ///
			ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0)) ///
			yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash)) ///
			yscale(range(`ylabel_min' `ylabel_max')) ///
		xtitle("MVPF", axis(1) size(small)) ///
			xscale(range(0 `tax_censor_value') axis(1) titlegap(+1.5)) ///
			xlab(0(.5)`tax_censor_value', axis(1)) ///
			xline(1, lcolor(black)) ///
		text(`GasolineTaxes_xpos' -1 "{bf:Gasoline Taxes}", size(vsmall)) ///
		text(`OtherFuelTaxes_xpos' -1 "{bf:Other Fuel Taxes}", size(vsmall)) ///
		text(`OtherRevenueRaisers_xpos' -1 "{bf:Other Revenue Raisers}", size(vsmall)) ///
		text(`Comparisons_xpos' -1 "{bf:Reference Taxes}", size(vsmall)) ///		
		legend(off)

	graph export "`output_path'/mvpf_taxes_`plot_name'_with_CIs.png", replace
	cap graph export "`output_path'/mvpf_taxes_`plot_name'_with_CIs.wmf", replace
		

}