************************************************************************
/* Purpose: Produce MVPF Plots for All MVPF Types */
************************************************************************

. * Add category lines to the existing plot using addplot
* Install the gr_edit package
ssc install addplot

// do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_09-44-45__full_current_193_nov" "Fig4_scc193" "193" "scc_193" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_01-31-00__full_current_no_lbd_193_nov" "Fig4_scc193" "193" "no_lbd" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_02-01-52__full_current_noprofits_193_nov" "Fig4_scc193" "193" "no_profit" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_01-32-09__full_current_savings_193_nov" "Fig4_scc193" "193" "e_savings" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-04-28_10-02-55__full_current_193_CA_grid" "Fig4_scc193" "193" "cali_grid" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_13-00-03__full_current_193_MI_grid" "Fig4_scc193" "193" "mi_grid" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_10-30-42__full_current_193_zero_rebound" "Fig4_scc193" "193" "zero_rebound" "" "categories_only"
// do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_15-32-51__full_current_193_double_rebound" "Fig4_scc193" "193" "double_rebound" "" "categories_only"


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
************************************************************************
/* Step #0a: Define Data Paths for Local Scenarios */
************************************************************************

local path_scc_193 = "${code_files}/4_results/2024-11-15_09-44-45__full_current_193_nov" // baseline
* Wind Locals (8)
local path_wind_no_cap_factor = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_15-57-36__wind_current_no_cap_factor_193" 
local path_wind_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_15-13-01__wind_current_lifetime_increase_193" 
local path_wind_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_15-10-16__wind_current_lifetime_reduce_193" 
local path_wind_emissions_half = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_15-07-33__wind_current_emissions_half_193" // check
local path_wind_emissions_double = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_16-52-33__wind_current_emissions_double_193" // check
local path_wind_lcoe_2 = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_15-02-02__wind_current_lcoe_2_193"
local path_wind_lcoe_05 = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_14-59-23__wind_current_lcoe_05_193"
local path_wind_semie = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-09_14-43-55__wind_current_semie_193"

* Solar Locals (4)
local path_solar_output_decrease = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_15-26-00__solar_output_decrease_193"
local path_solar_output_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_15-09-51__solar_output_increase_193"
local path_solar_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_14-47-03__solar_lifetime_increase_193"
local path_solar_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_14-24-30__solar_lifetime_reduce_193"

* EVs (3)
local path_ev_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_16-52-16__ev_vehicle_lifetime_20"
local path_ev_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_16-28-03__ev_vehicle_lifetime_15"
local path_ev_vmt_rebound_one = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_15-42-59__ev_VMT_rebound_one_193"
local path_ev_new_car = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_16-03-07__ev_new_car_193"


* Weatherization (3)
local path_wea_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_23-12-05__weather_current_decr_lifespan_193"
local path_wea_mar_val_decr = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_22-52-13__weather_current_marginal_chng_193" // potential to remove wisc
local path_wea_mar_per_incr = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_22-33-59__weather_current_marginal_per_193"

* Hybrids (3)
local path_hybrid_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_23-59-38__hybrid_current_lifetime_decr_193" // check
local path_hybrid_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_23-44-53__hybrid_current_lifetime_incr_193" //check
local path_hybrid_new_car = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-02_23-30-44__hybrid_current_new_car_193"

* Appliances (2)
local path_app_lifetime_reduce = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-03_00-24-09__appliance_current_lifetime_5_193" 
local path_app_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-03_00-13-30__appliance_current_lifetime_25_193" 

* Vehicle Retirement (3)
local path_vehicle_lifetime_increase = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-03_00-55-18__vehicle_ret_current_age_incr_193"
local path_vehicle_mar_decrease ="${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-03_00-44-36__vehicle_ret_current_marginal_chng_193" 
local path_vehicle_no_rb = "${code_files}/4_results/local_assumption_mvpf_plot_data/2025-06-03_10-30-00__vehicle_ret_current_no_rb_193" //check

* Identify primary SCC from command argument
local primary_scenario = "`3'"
di "Primary scenario: `primary_scenario'"

* Set the primary data path based on the primary scenario
local primary_path = "`path_`primary_scenario''"
di in red "Primary data path: `primary_path'"

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
/* Step #0b: Set Macros that CAN Change. */
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
local primary_scenario  		`3'
local plot_name			 		`2'
************************************************************************
************************************************************************
/* Step #1: Merge Output and Policy Details. */
************************************************************************
preserve
    import excel "${code_files}/policy_details_v3.xlsx", clear first
    tempfile policy_labels
    save "`policy_labels'", replace
restore

di in red "Primary data path: `primary_path'"

* First load the primary dataset
use "`primary_path'/compiled_results_all_uncorrected_vJK.dta", clear
merge m:1 program using "`policy_labels'", nogen noreport keep(3)
cap drop if broad_category == "Regulation"

* Save non-marginal MVPFs for later (if toggle enabled).
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

* Define scenarios to process based on command arguments
local scenarios = ""
foreach arg_num in 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 {
    if "``arg_num''" != "" {
        local scenarios "`scenarios' ``arg_num''"
    }
}

* Save main dataset to tempfile before processing
tempfile main_dataset
save "`main_dataset'", replace

* Process each additional scenario
foreach scenario of local scenarios {
    * Skip the primary scenario since we already loaded it
    if "`scenario'" != "`primary_scenario'" {
        di as text "Processing `scenario' dataset"
        
        * Determine dataset path
        local dataset_path = "`path_`scenario''"
        
        * Check if we have a path for this scenario
        if "`dataset_path'" != "" {
            di as text "  Using path: `dataset_path'"
            
            * Load the dataset
            use "`dataset_path'/compiled_results_all_uncorrected_vJK.dta", clear
            
            * Merge with policy labels
            merge m:1 program using "`policy_labels'", nogen noreport keep(3)
            cap drop if broad_category == "Regulation"
            
            * Process the data
            keep if inlist(component_type, "MVPF", "cost", "WTP_USPres", "WTP_USFut", "WTP_RoW", "WTP", "WTP_cc", "program_cost", "admin_cost")
            sort program component_type component_value
            qui by program component_type component_value: gen dup = cond(_N==1,0,_n)
            drop if dup > 1
            drop dup
            
            * Normalize by program cost
            replace component_value = 0 if (component_type == "admin_cost" & missing(component_value)) | (component_type == "admin_cost" & program == "care")
            levelsof(program), local(program_loop)
            foreach p of local program_loop {
                qui sum component_value if component_type == "program_cost" & program == "`p'"
                local program_cost = r(mean)
                local normalization = `program_cost'
                replace component_value = component_value / `normalization' if inlist(component_type, "WTP", "WTP_cc", "cost", "WTP_RoW", "WTP_USFut", "WTP_USPres") & program == "`p'"
            }
            drop if component_type == "program_cost" | component_type == "admin_cost"
            
            * Keep only MVPF values
            keep if component_type == "MVPF"
            
            * Rename to create scenario-specific MVPF column
            rename component_value MVPF_`scenario'
            keep program MVPF_`scenario'
            
            * Save to tempfile
            tempfile `scenario'_data
            save "``scenario'_data'", replace
            di as text "  Saved `scenario' data to tempfile"
        }
    }
}

* Load main dataset back
use "`main_dataset'", clear

* Keep only MVPF values in the main dataset before merging
keep if component_type == "MVPF"


* Merge in MVPF values from each additional scenario
foreach scenario of local scenarios {
    if "`scenario'" != "`primary_scenario'" {
        capture confirm file "``scenario'_data'"
        if _rc == 0 {
            merge 1:1 program using "``scenario'_data'", keep(1 3) nogen
            di as text "Merged `scenario' MVPF values"
        }
    }
}

* Rename the primary MVPF to include scenario name for consistency
rename component_value MVPF_`primary_scenario'


* Display sample of merged data
di as text _n "Sample of merged MVPF data:"
list program MVPF_* in 1/5, abbreviate(40)


************************************************************************
/* Step #2: Prepare MVPF Data for Visualization */
************************************************************************
* Create a clean dataset with one row per program

keep program *label* broad_category MVPF_* across_group_ordering in_group_ordering extended international regulation table_order

* Sort data for visualization
sort across_group_ordering in_group_ordering
	
************************************************************************
/* Step #3: Produce MVPF Plot for Subsidies. */
************************************************************************	
	
if "`run_subsidies'" == "yes" {
	 preserve

		keep if broad_category == "Subsidies"
		drop if extended == 1

		if "`include_other_subsidies'" == "no" {
			
			drop if group_label == "Other Subsidies"
			local OtherSubsidies_max = 1
			local OtherSubsidies_min = 1
			local OtherSubsidies_xpos = -20
			
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
		

		************************************************************************
		/* Step #3c: Censoring and Edge Cases. */
		************************************************************************
		
	foreach var of varlist MVPF_* {
    replace `var' = `subsidy_censor_value' if `var' > `subsidy_censor_value' & `var' != .
    replace `var' = 0 if `var' < 0
		}
		
* First, set the random number seed for reproducibility
set seed 12345

* Apply jitter to individual data points that have been capped to exactly 5
foreach var of varlist MVPF_* {
    * Generate jitter values from N(0.1, 0.1) for capped values
    gen j_`var' = rnormal(0.1, 0.05) if `var' == `subsidy_censor_value' & `var' != .
    
    * Apply jitter but ensure we don't exceed a reasonable upper bound
    replace `var' = min(`var' + j_`var', 5.3) if `var' == `subsidy_censor_value' & `var' != .
    
    * Clean up
    drop j_`var'
}


************************************************************************
/* Step #3d: Produce Scatter Plot. */
************************************************************************
local scenarios "scc_193 wind_no_cap_factor wind_lifetime_increase wind_lifetime_reduce wind_emissions_half wind_emissions_double wind_lcoe_2 wind_lcoe_05 wind_semie solar_output_decrease solar_output_increase solar_lifetime_increase solar_lifetime_reduce ev_lifetime_increase ev_lifetime_reduce ev_vmt_rebound_one ev_new_car wea_lifetime_reduce wea_mar_val_decr wea_mar_per_decr hybrid_lifetime_reduce hybrid_lifetime_increase hybrid_new_car app_lifetime_reduce app_lifetime_increase vehicle_lifetime_increase vehicle_mar_decrease vehicle_no_rb"

local symbols "circle square v v triangle diamond plus X smcircle square triangle v v v v diamond square v square triangle v v square v v v square triangle"
local colors "black navy navy navy navy navy navy navy navy green green green green orange orange orange orange maroon maroon maroon purple purple purple teal teal gold gold gold"
local sizes "vsmall vsmall small small vsmall vsmall small small vsmall vsmall vsmall small small small small vsmall vsmall small vsmall vsmall small small vsmall small small small vsmall vsmall"
local orientations "0 0 180 0 0 0 0 0 0 0 0 180 0 180 0 0 0 0 0 0 0 0 0 0 180 180 0 0"

* Build marker properties dynamically for all scenarios
forvalues i = 1/30 {
    local scenario : word `i' of `scenarios'
    local symbol : word `i' of `symbols'
    local color : word `i' of `colors'
    local size : word `i' of `sizes'
	local orient : word `i' of `orientations'


    * Create the marker properties local for this scenario
    local mp_`scenario' "msize(`size') msymbol(`symbol') mcolor(`color') msangle(`orient') xaxis(1)"
}

* Start with the basic graph command
local scatter_cmd_base "twoway"

* Add primary scenario to scatter command (this should always be included)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_`primary_scenario', `mp_`primary_scenario'')"

local legend_count = 1

* Loop through each scenario and add to graph command if it exists
foreach scenario of local scenarios {
    * Skip primary scenario as it's already added
    if "`scenario'" != "`primary_scenario'" {
        * Check if variable exists in dataset
        capture confirm variable MVPF_`scenario'
        if _rc == 0 {
            local legend_count = `legend_count' + 1
            local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_`scenario', `mp_`scenario'')"
        }
    }
}


* Add colored shapes for specs in legend (organized by category)
* Baseline (black)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(circle) mcolor(black) msize(small))"

* Wind specs (navy)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(navy) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(triangle) mcolor(navy) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(diamond) mcolor(navy) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(plus) mcolor(navy) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(X) mcolor(navy) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(smcircle) mcolor(navy) msize(small))"

* Solar specs (green)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(green) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(triangle) mcolor(green) msize(small))"

* EV specs (orange)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(diamond) mcolor(orange) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(orange) msize(small))"

* Weatherization specs (maroon)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(maroon) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(triangle) mcolor(maroon) msize(small))"

* Hybrid specs (purple)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(purple) msize(small))"

* Vehicle specs (gold)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(gold) msize(small))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(triangle) mcolor(gold) msize(small))"

* Lifetime specs (black - used across categories)
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(v) mcolor(black) msize(small) msangle(180))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(v) mcolor(black) msize(small))"

* Create legend entries
local shape_start = `legend_count' + 1

* Build the order list for all shapes
local legend_order "`shape_start' `=`shape_start'+1' `=`shape_start'+2' `=`shape_start'+3' `=`shape_start'+4' `=`shape_start'+5' `=`shape_start'+6' `=`shape_start'+7' `=`shape_start'+8' `=`shape_start'+9' `=`shape_start'+10' `=`shape_start'+11' `=`shape_start'+12' `=`shape_start'+13' `=`shape_start'+14' `=`shape_start'+15' `=`shape_start'+16' `=`shape_start'+17'"

local legend_labels ""
local legend_labels `"`legend_labels' label(`shape_start' "Baseline")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+1' "Wind: No Capacity Factor Reduction")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+2' "Wind: Emissions Half")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+3' "Wind: Emissions Double")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+4' "Wind: LCOE 2x")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+5' "Wind: LCOE 0.5x")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+6' "Wind: Constant Semie Elasticity")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+7' "Solar: Output Decrease")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+8' "Solar: Output Increase")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+9' "EV: VMT Rebound as 1")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+10' "EV: New Car as Counterfactual")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+11' "Weather: Marginal Value Decrease")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+12' "Weather: Marginal Percent Increase")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+13' "Hybrid: New Car as Counterfactual")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+14' "Vehicle: Marginal Valuation Decrease")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+15' "Vehicle: No Rebound")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+16' "Lifetime Increase")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+17' "Lifetime Decrease")"'

* Combine legend options - use cols(3) to arrange in 3 columns
local legend_options `"legend(order(`legend_order') `legend_labels' cols(4) position(12) size(tiny) forcesize rowgap(*.5) colgap(*1))"'

* Create a loop for all the text labels
local text_labels ""
foreach category in WindProductionCredits ResidentialSolar ElectricVehicles ApplianceRebates VehicleRetirement HybridVehicles Weatherization {
    * Get position value for this category
    local pos_val = "``category'_xpos'"
    
    * Automatically insert spaces before capital letters
    local readable_label = ""
    local first_char = 1
    
    * Process each character in the category name
    forvalues i = 1/`=length("`category'")' {
        local char = substr("`category'", `i', 1)
        
        * Check if it's uppercase (except for the first character)
        if "`char'" != lower("`char'") & `first_char' == 0 {
            * Add a space before uppercase letter
            local readable_label = "`readable_label' `char'"
        }
        else {
            * Add the character as is
            local readable_label = "`readable_label'`char'"
        }
        
        * No longer on first character
        local first_char = 0
    }
    
    local text_labels `"`text_labels' text(`pos_val' -2.5 "`readable_label'", size(vsmall))"'
}
* Add the Other Subsidies label  
local text_labels `"`text_labels' text(`OtherSubsidies_xpos' -20 "Other Subsidies", size(vsmall))"'

* Combine plot options
local plot_options "plotregion(margin(l=0 b=0 t=0)) graphregion(color(white) margin(l=8))"
local plot_options "`plot_options' title()"
local plot_options "`plot_options' ytitle("") xtitle(MVPF, axis(1) size(small))"
local plot_options "`plot_options' ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0))"
local plot_options "`plot_options' yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash))"
local plot_options "`plot_options' yscale(range(`ylabel_min' `ylabel_max'))"
local plot_options "`plot_options' xscale(range(1.5 5.3) axis(1) titlegap(+1.5))"
local plot_options "`plot_options' xlab(0(1)5.3, axis(1) nogrid)"

************************************************************************
/* Step #3e: Adding Category Averages. */
************************************************************************
* Store category positions in globals
/*
di as text "Storing category positions as globals:"
foreach cat in WindProductionCredits ResidentialSolar ElectricVehicles ApplianceRebates VehicleRetirement HybridVehicles Weatherization {
    global `cat'_min = ``cat'_min'
    global `cat'_max = ``cat'_max'
    global `cat'_midpoint = (``cat'_min' + ``cat'_max') / 2
    di as text "  `cat': min=${`cat'_min}, max=${`cat'_max}, midpoint=${`cat'_midpoint}"
}


* Combine legend options
local legend_options `"legend(order(`legend_order') `legend_labels' cols(3) position(6) size(vsmall))"'

* Save the current dataset to a tempfile
tempfile main_data
save "`main_data'", replace

* Load and process category averages
capture confirm file "category_averages.dta"
if _rc == 0 {
    use "category_averages.dta", clear
	
gen j = rnormal(0.1, 0.1) if mvpf == `subsidy_censor_value' & mvpf != .
replace mvpf = min(mvpf + j, 5.3) if mvpf == `subsidy_censor_value' & mvpf != .

* Display which points were jittered for verification
list category scenario mvpf j if j != . & j != 0

* Clean up
drop j

* Create scenario_index only once, before the loops
gen scenario_index = .
local i 1
foreach s in scc_193 no_lbd no_profit e_savings cali_grid mi_grid zero_rebound double_rebound scc_337 scc_337_no_lbd scc_337_no_profit scc_337_e_savings scc_337_cali_grid scc_337_mi_grid scc_337_zero_rebound scc_337_double_rebound scc_76 scc_76_no_lbd scc_76_no_profit scc_76_e_savings scc_76_cali_grid scc_76_mi_grid scc_76_zero_rebound scc_76_double_rebound {
    replace scenario_index = `i' if scenario == "`s'"
    local i = `i' + 1
}

* Build the category lines part
local cat_lines ""
foreach catg in WindProductionCredits ResidentialSolar ElectricVehicles ApplianceRebates VehicleRetirement HybridVehicles Weatherization {
    levelsof scenario, local(scen_list)
    foreach sc in `scen_list' {
        count if category == "`catg'" & scenario == "`sc'"
        if r(N) > 0 {
            * Get MVPF value
            sum mvpf if category == "`catg'" & scenario == "`sc'"
            local mvpf = r(mean)
            
            * Get style info
            sum scenario_index if scenario == "`sc'"
            local idx = r(mean)
            local sym : word `idx' of `symbols'
            local col : word `idx' of `colors'
            local sz : word `idx' of `sizes'
			local orient: word `idx' of `orientations'
            
            * Get min/max from globals
            local min = ${`catg'_min}
            local max = ${`catg'_max}
            local mid = (${`catg'_min} + ${`catg'_max}) / 2
				if "`sz'" == "vsmall" local one_size_larger "medium"
				else if "`sz'" == "small" local one_size_larger "large"
            * Add to cat_lines
            local cat_lines "`cat_lines' (pci `min' `mvpf' `max' `mvpf', color(`col') lwidth(vthin))"
            local cat_lines "`cat_lines' (scatteri `mid' `mvpf', msymbol(`sym') mcolor(`col') msize(`one_size_larger') msangle(`orient'))"
			}
		}
	}
}



* Go back to main dataset
use "`main_data'", replace
*/
* Create a complete command with everything
local full_command "`scatter_cmd_base', `plot_options' `text_labels' `legend_options'"

*display locals
di "`cat_lines'"
di "`scatter_cmd_base'"
*`cat_lines', `plot_options' `text_labels' `legend_options'
* Run the full command
`full_command'

* Export the graph
graph export "`output_path'/mvpf_comparison_`plot_name'.png", replace
cap graph export "`output_path'/mvpf_comparison_`plot_name'.emf", replace
}
