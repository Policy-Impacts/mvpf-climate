*****************************************************************
*             Export Final Datasets to Excel                    *
*****************************************************************

local ce_table_name "`1'"
local dwl "`2'"
local lbd "`3'"

local input_path "${output_tab}/tables_data"
local output_path ${output_tab}


use "`input_path'/table_3_data_with_lbd.dta", clear // Created in cost_per_ton.do ran in tables.do

append using "`input_path'/table_3_data_no_lbd.dta", gen(LBD_tag) // Created in cost_per_ton.do ran in tables.do

	
// Category Averages w/ and w/o LBD	
preserve 	

	keep if group_label == program_label_short | program == "opower_e"
	drop if program == "her_compiled"
	drop program
	drop if substr(group_label, 1, 5) == "Other"

	keep group_label mvpf resource_ce* gov_ce* net_social* LBD_tag
	order group_label mvpf
		
	// Organize Data
	gen resource_cost_table = .
	replace resource_cost_table = resource_ce_no_lbd if LBD_tag == 1
	replace resource_cost_table = resource_ce_yes_lbd if LBD_tag == 0
		
	gen govt_cost_table = .
	replace govt_cost_table = gov_ce_no_lbd if LBD_tag == 1
	replace govt_cost_table = gov_ce_yes_lbd if LBD_tag == 0
			
	gen net_social_cost_table = .
	replace net_social_cost_table = net_social_ce_no_lbd  if LBD_tag == 1
	replace net_social_cost_table = net_social_ce_yes_lbd  if LBD_tag == 0

	keep group_label mvpf *_table
		
	copy "${output_tab}/tables_templates/TEMPLATE_ce_averages.xlsx" "`output_path'/tables_main/Table3_CE_Table_Avg_`ce_table_name'.xlsx", replace	
	export excel "`output_path'/tables_main/Table3_CE_Table_Avg_`ce_table_name'.xlsx", first(var) sheet("data_export", replace) keepcellfmt

restore

// All Policies, with LBD
preserve 

	keep if LBD_tag == 0
	keep program_label_short mvpf resource_ce_yes_lbd gov_ce_yes_lbd net_social_ce_yes_lbd
	order program_label_short mvpf resource* gov* net_social*
	
	copy "${output_tab}/tables_templates/TEMPLATE_ce.xlsx" "`output_path'/tables_appendix/Table10_CE_Table_All_Policies_with_LBD_`ce_table_name'.xlsx", replace	
	export excel "`output_path'/tables_appendix/Table10_CE_Table_All_Policies_with_LBD_`ce_table_name'.xlsx", first(var) sheet("data_export", replace) keepcellfmt	
	
restore

if "`lbd'" == "no"{

	// All Policies, without LBD
	preserve 

		keep if LBD_tag == 1
		keep program_label_short mvpf resource_ce_no_lbd gov_ce_no_lbd net_social_ce_no_lbd
		order program_label_short mvpf resource* gov* net_social*
		
		copy "${output_tab}/tables_templates/TEMPLATE_ce.xlsx" "`output_path'/tables_appendix/Table11_CE_Table_All_Policies_no_LBD_`ce_table_name'.xlsx", replace	
		export excel "`output_path'/tables_appendix/Table11_CE_Table_All_Policies_no_LBD_`ce_table_name'.xlsx", first(var) sheet("data_export", replace) keepcellfmt	
		
	restore
}

if "`dwl'" == "yes"{

	// Category Averages w/ and w/o LBD	
	preserve 	

		keep if group_label == program_label_short | program == "opower_e"
		drop if program == "her_compiled"
		drop program
		drop if substr(group_label, 1, 5) == "Other"
			
		keep group_label mvpf resource_ce* gov_ce* net_social* LBD_tag
		order group_label mvpf
			
		// Organize Data
		gen DWL_0_table = .
		replace DWL_0_table = net_social_ce_yes_lbd	
			
		gen DWL_10_table = .
		replace DWL_10_table = net_social_ce_yes_lbd_dwl1
			
		gen DWL_30_table = .
		replace DWL_30_table = net_social_ce_yes_lbd_dwl3
				
		gen DWL_50_table = .
		replace DWL_50_table = net_social_ce_yes_lbd_dwl5

		keep group_label mvpf *_table
					
		copy "${output_tab}/tables_templates/TEMPLATE_ce_averages_DWL.xlsx" "`output_path'/tables_appendix/Table9_CE_Table_DWL_`ce_table_name'.xlsx", replace	
		export excel "`output_path'/tables_appendix/Table9_CE_Table_DWL_`ce_table_name'.xlsx", first(var) sheet("data_export", replace) keepcellfmt

	restore
}