************************************************************************
/* Purpose: Produce MVPF Plots (w/ and w/o Bars) for All MVPF Types */
************************************************************************

. * Add category lines to the existing plot using addplot
* Install the gr_edit package
ssc install addplot

do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_09-44-45__full_current_193_nov" "Fig4_scc193" "193" "scc_193" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_01-31-00__full_current_no_lbd_193_nov" "Fig4_scc193" "193" "no_lbd" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_02-01-52__full_current_noprofits_193_nov" "Fig4_scc193" "193" "no_profit" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-15_01-32-09__full_current_savings_193_nov" "Fig4_scc193" "193" "e_savings" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-04-28_10-02-55__full_current_193_CA_grid" "Fig4_scc193" "193" "cali_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_13-00-03__full_current_193_MI_grid" "Fig4_scc193" "193" "mi_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_10-30-42__full_current_193_zero_rebound" "Fig4_scc193" "193" "zero_rebound" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_15-32-51__full_current_193_double_rebound" "Fig4_scc193" "193" "double_rebound" "" "categories_only"

* Generate category averages for SCC 76 and variations
do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-16_14-43-50__full_current_76_nov" "Fig5a_scc76" "76" "scc_76" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-12_10-16-37__full_current_no_lbd_76" "Fig5a_scc76" "76" "scc_76_no_lbd" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-12_14-55-09__full_current_noprofits_76" "Fig5a_scc76" "76" "scc_76_no_profit" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_11-16-30__full_current_savings_76" "Fig5a_scc76" "76" "scc_76_e_savings" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_01-15-05__full_current_76_CA_grid" "Fig5a_scc76" "76" "scc_76_cali_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_23-48-41__full_current_76_MI_grid" "Fig5a_scc76" "76" "scc_76_mi_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_19-40-13__full_current_76_zero_rebound" "Fig5a_scc76" "76" "scc_76_zero_rebound" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_22-11-19__full_current_76_double_rebound" "Fig5a_scc76" "76" "scc_76_double_rebound" "" "categories_only"

* Generate category averages for SCC 337 and variations
do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-16_15-20-07__full_current_337_nov" "Fig5b_scc337" "337" "scc_337" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-12_10-00-24__full_current_no_lbd_337" "Fig5b_scc337" "337" "scc_337_no_lbd" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-12_11-02-47__full_current_noprofits_337" "Fig5b_scc337" "337" "scc_337_no_profit" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_10-08-21__full_current_savings_337" "Fig5b_scc337" "337" "scc_337_e_savings" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_01-58-31__full_current_337_CA_grid" "Fig5b_scc337" "337" "scc_337_cali_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-14_00-32-09__full_current_337_MI_grid" "Fig5b_scc337" "337" "scc_337_mi_grid" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_17-00-23__full_current_337_zero_rebound" "Fig5b_scc337" "337" "scc_337_zero_rebound" "" "categories_only"
do "${github}/figtab/mvpf_plots.do" "subsidies" "2025-05-13_17-43-31__full_current_337_double_rebound" "Fig5b_scc337" "337" "scc_337_double_rebound" "" "categories_only"

e
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

if inlist("`2'", "Fig4_scc193", "Fig5a_scc76", "Fig5b_scc337", "Fig8_scc193", "Fig9_scc193") {
	local output_path "${output_fig}/figures_appendix"
}

************************************************************************
/* Step #0a: Define Data Paths for Scenarios */
************************************************************************

local path_scc_193 = "${code_files}/4_results/2024-11-15_09-44-45__full_current_193_nov"
local path_no_lbd = "${code_files}/4_results/2024-11-15_01-31-00__full_current_no_lbd_193_nov"
local path_no_profit = "${code_files}/4_results/2024-11-15_02-01-52__full_current_noprofits_193_nov"
local path_e_savings = "${code_files}/4_results/2024-11-15_01-32-09__full_current_savings_193_nov"
local path_cali_grid = "${code_files}/4_results/2025-04-28_10-02-55__full_current_193_CA_grid"
local path_mi_grid = "${code_files}/4_results/2025-05-14_13-00-03__full_current_193_MI_grid"
local path_zero_rebound = "${code_files}/4_results/2025-05-13_10-30-42__full_current_193_zero_rebound"
local path_double_rebound = "${code_files}/4_results/2025-05-13_15-32-51__full_current_193_double_rebound"

local path_scc_337 = "${code_files}/4_results/2024-11-16_15-20-07__full_current_337_nov" 
local path_scc_337_no_lbd = "${code_files}/4_results/2025-05-12_10-00-24__full_current_no_lbd_337"
local path_scc_337_no_profit = "${code_files}/4_results/2025-05-12_11-02-47__full_current_noprofits_337" 
local path_scc_337_e_savings = "${code_files}/4_results/2025-05-14_10-08-21__full_current_savings_337" 
local path_scc_337_cali_grid = "${code_files}/4_results/2025-05-14_01-58-31__full_current_337_CA_grid" 
local path_scc_337_mi_grid = "${code_files}/4_results/2025-05-14_00-32-09__full_current_337_MI_grid" 
local path_scc_337_zero_rebound = "${code_files}/4_results/2025-05-13_17-00-23__full_current_337_zero_rebound" 
local path_scc_337_double_rebound = "${code_files}/4_results/2025-05-13_17-43-31__full_current_337_double_rebound" 

local path_scc_76 = "${code_files}/4_results/2024-11-16_14-43-50__full_current_76_nov"
local path_scc_76_no_lbd = "${code_files}/4_results/2025-05-12_10-16-37__full_current_no_lbd_76"
local path_scc_76_no_profit = "${code_files}/4_results/2025-05-12_14-55-09__full_current_noprofits_76"
local path_scc_76_e_savings = "${code_files}/4_results/2025-05-14_11-16-30__full_current_savings_76"
local path_scc_76_cali_grid = "${code_files}/4_results/2025-05-14_01-15-05__full_current_76_CA_grid" 
local path_scc_76_mi_grid = "${code_files}/4_results/2025-05-13_23-48-41__full_current_76_MI_grid" 
local path_scc_76_zero_rebound = "${code_files}/4_results/2025-05-13_19-40-13__full_current_76_zero_rebound" 
local path_scc_76_double_rebound = "${code_files}/4_results/2025-05-13_22-11-19__full_current_76_double_rebound"

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
foreach arg_num in 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 {
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
    gen j_`var' = rnormal(0.1, 0.1) if `var' == `subsidy_censor_value' & `var' != .
    
    * Apply jitter but ensure we don't exceed a reasonable upper bound
    replace `var' = min(`var' + j_`var', 5.3) if `var' == `subsidy_censor_value' & `var' != .
    
    * Clean up
    drop j_`var'
}
************************************************************************
/* Step #3d: Produce Scatter Plot. */
************************************************************************

local scenarios "scc_193 no_lbd no_profit e_savings cali_grid mi_grid zero_rebound double_rebound scc_337 scc_337_no_lbd scc_337_no_profit scc_337_e_savings scc_337_cali_grid scc_337_mi_grid scc_337_zero_rebound scc_337_double_rebound scc_76 scc_76_no_lbd scc_76_no_profit scc_76_e_savings scc_76_cali_grid scc_76_mi_grid scc_76_zero_rebound scc_76_double_rebound"
local symbols "circle X square triangle diamond plus v v circle X square triangle diamond plus v v circle X square triangle diamond plus v v"
local colors "navy navy navy navy navy navy navy navy green green green green green green green green orange orange orange orange orange orange orange orange"
local sizes "vsmall small vsmall vsmall vsmall small small small vsmall small vsmall vsmall vsmall small small small vsmall small vsmall vsmall vsmall small small small"
local orientations "0 0 0 0 0 0 180 0 0 0 0 0 0 0 180 0 0 0 0 0 0 0 180 0"

* Build marker properties dynamically for all scenarios
forvalues i = 1/24 {
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



* Add colored squares for the SCC values legend
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(navy) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(green) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(orange) msize(medium))"

* Add black shapes for specs in legend
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(circle) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(X) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(square) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(triangle) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(diamond) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(plus) mcolor(black) msize(medium))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(v) mcolor(black) msize(medium) msangle(180))"
local scatter_cmd_base "`scatter_cmd_base' (scatter yaxis MVPF_scc_193 if _n < 0, msymbol(v) mcolor(black) msize(medium))"

* Create legend entries
local color_start = `legend_count' + 1
local shape_start = `legend_count' + 4

* Build the order list to arrange items in rows
* First row: SCC values (3 columns)
local legend_order "`color_start' `=`color_start'+1' `=`color_start'+2'"

* Second row: First 3 shapes
local legend_order "`legend_order' `shape_start' `=`shape_start'+1' `=`shape_start'+2'"

* Third row: Next 3 shapes
local legend_order "`legend_order' `=`shape_start'+3' `=`shape_start'+4' `=`shape_start'+5'"

* Fourth row: Last 2 shapes
local legend_order "`legend_order' `=`shape_start'+6' `=`shape_start'+7'"

* Build labels for each entry
local legend_labels ""
local legend_labels `"`legend_labels' label(`color_start' "SCC $193")"'
local legend_labels `"`legend_labels' label(`=`color_start'+1' "SCC $337")"'
local legend_labels `"`legend_labels' label(`=`color_start'+2' "SCC $76")"'
local legend_labels `"`legend_labels' label(`shape_start' "Base")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+1' "No LBD")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+2' "No Profit")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+3' "Energy Savings")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+4' "CA Grid")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+5' "MW Grid")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+6' "Zero Rebound")"'
local legend_labels `"`legend_labels' label(`=`shape_start'+7' "2x Rebound")"'

* Combine legend options - use cols(3) to arrange in 3 columns
local legend_options `"legend(order(`legend_order') `legend_labels' cols(3) position(12) size(small) forcesize rowgap(*.8) colgap(*1.5))"'

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

************************************************************************
/* Step #3e: Adding Category Averages. */
************************************************************************
* Store category positions in globals
di as text "Storing category positions as globals:"
foreach cat in WindProductionCredits ResidentialSolar ElectricVehicles ApplianceRebates VehicleRetirement HybridVehicles Weatherization {
    global `cat'_min = ``cat'_min'
    global `cat'_max = ``cat'_max'
    global `cat'_midpoint = (``cat'_min' + ``cat'_max') / 2
    di as text "  `cat': min=${`cat'_min}, max=${`cat'_max}, midpoint=${`cat'_midpoint}"
}

* Combine plot options
local plot_options "plotregion(margin(l=0 b=0 t=0)) graphregion(color(white) margin(l=8))"
local plot_options "`plot_options' title()"
local plot_options "`plot_options' ytitle("") xtitle(MVPF, axis(1) size(small))"
local plot_options "`plot_options' ylabel(`ylabel_min'(1)`ylabel_max', value labsize(tiny) angle(0) nogrid tlw(0.15) tlength(0))"
local plot_options "`plot_options' yline(`yline_list', lcolor(black%30) lw(0.05) lpattern(dash))"
local plot_options "`plot_options' yscale(range(`ylabel_min' `ylabel_max'))"
local plot_options "`plot_options' xscale(range(1.5 5.3) axis(1) titlegap(+1.5))"
local plot_options "`plot_options' xlab(0(1)5.3, axis(1) nogrid)"

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

* Create a complete command with everything
local full_command "`scatter_cmd_base' `cat_lines', `plot_options' `text_labels' `legend_options'"

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
