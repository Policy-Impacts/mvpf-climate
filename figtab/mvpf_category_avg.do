************************************************************************
/* Purpose: Calculate MVPF Category Averages*/
************************************************************************
ssc install missings
local stub1 "2025-08-06_14-24-41__full_current_.999_clean_grid_no_lbd_solar"
foreach i of numlist 1/1 {
	local stub `stub`i''
	quietly {
		use "${code_files}/4_results/`stub'/compiled_results_all_uncorrected_vJK", clear
		missings dropvars, force
		drop component_over_prog_cost
		cap drop perc_switch
		ren component_value cv
		cap drop assumptions component_sd
			
		replace cv = cv
		cap drop l_component u_component
			
		reshape wide cv, i(program) j(component_type) string
		ren cv* *
		replace WTP_cc = WTP if WTP_cc == .
		gen WTP_cc_scaled = WTP_cc / program_cost
		gen cost_scaled = cost/program_cost
		keep program WTP_cc_scaled cost_scaled
		collapse (mean) cost_scaled WTP_cc_scaled
		gen MVPF = WTP_cc_scaled / cost_scaled
	}
	di "Category Average for: `stub':"
	di  MVPF[1]
}

*local stub1 "2025-08-04_11-38-36__full_current_.999_subs"
