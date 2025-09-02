// ***** MVPF with Changing Elasticity Figure *****
//
// *Set toggles for figure
// local mvpf_max 				8
// local bar_dark_orange = "214 118 72"
// local bar_blue = "36 114 237"
// local bar_dark_blue = "8 51 97"
// local re_pull_data = "yes" // Re-run data for the figure (if no, uses saved data from previous run)
//
// global renewables_loop = "yes"
// global renewables_2020 = 0.1952 // EPA eGRID renewables (including Hydro)
//
// local loop_nums 0.01 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9
//
//
// *--------------------------------------------
// * Changing Renewable Percentages (Wind)
// *--------------------------------------------
// if "`re_pull_data'" == "yes" {
//
// 	foreach percent of local loop_nums {
// 		global renewables_percent = `percent'
//		
// 		do "${github}/wrapper/metafile.do" ///
// 			"current" /// 2020
// 			"193" /// SCC
// 			"yes" /// learning-by-doing
// 			"no" /// savings
// 			"yes" /// profits
// 			"hitaj_ptc shirmali_ptc metcalf_ptc" /// programs to run
// 			0 /// reps
// 			"full_current_${renewables_percent}_wind_cg" // nrun
//
// 	}
// }	
// *--------------------------------------------
// * Changing Renewable Percentages (Solar)
// *--------------------------------------------
// if "`re_pull_data'" == "yes" {
// 	foreach percent of local loop_nums {
// 		global renewables_percent = `percent'
//		
// 		do "${github}/wrapper/metafile.do" ///
// 			"current" /// 2020
// 			"193" /// SCC
// 			"yes" /// learning-by-doing
// 			"no" /// savings
// 			"yes" /// profits
// 			"ct_solar ne_solar hughes_csi pless_ho pless_tpo" /// programs to run
// 			0 /// reps
// 			"full_current_${renewables_percent}_solar_cg" // nrun
//
// 	}
//
// }
// *--------------------------------------------
// * Changing Renewable Percentages (EVs)
// *--------------------------------------------
// local re_pull_data = "yes"
//
// if "`re_pull_data'" == "yes" {
// 	foreach percent of local loop_nums {
// 		global renewables_percent = `percent'
//		
// 		do "${github}/wrapper/metafile.do" ///
// 			"current" /// 2020
// 			"193" /// SCC
// 			"yes" /// learning-by-doing
// 			"no" /// savings
// 			"yes" /// profits
// 			"federal_ev bev_state muehl_efmp" /// programs to run
// 			0 /// reps
// 			"full_current_${renewables_percent}_evs_cg" // nrun
//
// 	}
//
// }	
//
// *--------------------------------------------------------------------------------------
// * Changing Renewable Percentages (Weatherization, Appliance Rebates, Wind No LBD, Solar No LBD)
// *--------------------------------------------------------------------------------------
// local re_pull_data = "yes"
// if "`re_pull_data'" == "yes" {
// 	foreach percent of local loop_nums {
// 		global renewables_percent = `percent'
//		
// 		do "${github}/wrapper/metafile.do" ///
// 			"current" /// 2020
// 			"193" /// SCC
// 			"no" /// learning-by-doing
// 			"no" /// savings
// 			"yes" /// profits
// 			"c4a_cw rebate_es cw_datta c4a_dw dw_datta c4a_fridge fridge_datta esa_fridge retrofit_res ihwap_nb wisc_rf wap hancevic_rf hitaj_ptc metcalf_ptc shirmali_ptc ct_solar ne_solar hughes_csi pless_ho pless_tpo" /// programs to run
// 			0 /// reps
// 			"full_current_${renewables_percent}_subs_cg" // nrun
//
// 	}
//
// }	
// *--------------------------------------------------------------------------------------
// * Changing Renewable Percentages (EVs No LBD)
// *--------------------------------------------------------------------------------------
// local re_pull_data = "yes"
// if "`re_pull_data'" == "yes" {
// 	foreach percent of local loop_nums {
// 		global renewables_percent = `percent'
//		
// 		do "${github}/wrapper/metafile.do" ///
// 			"current" /// 2020
// 			"193" /// SCC
// 			"no" /// learning-by-doing
// 			"no" /// savings
// 			"yes" /// profits
// 			"federal_ev bev_state muehl_efmp" /// programs to run
// 			0 /// reps
// 			"full_current_${renewables_percent}_ev_nolbd" // nrun
//
// 	}
//
// }	
// global renewables_loop = "no"

*----------------------------------------------------------
* Append Runs Together (Need to Adjust if re-running data)
*----------------------------------------------------------
	
local folders_wind : dir "${github}/data/4_results" dirs "*full_current*wind_cg*"
local folders_solar : dir "${github}/data/4_results" dirs "*full_current*solar_cg*"
local folders_no_lbd : dir "${github}/data/4_results" dirs "*full_current*subs_cg*"
local folders_ev: dir "${github}/data/4_results" dirs "*full_current*evs_cg*"
local folders_ev_nolbd: dir "${github}/data/4_results" dirs "*full_current*ev_nolbd*"

*Appending Wind
*Appending Wind
local first_run = 1
foreach f of local folders_wind {
    if `first_run' == 1 {
        use "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta", clear
        gen percent = .  // Create the percent variable
        local first_run = 0
    }
    else {
        append using "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta"
    }
    
    if regexm("`f'", "full_current_([0-9\.]+)_wind_cg") {
        local extracted_percent = regexs(1)
        replace percent = `extracted_percent' if percent == .
    }
}
gen category = "Wind Production Credits"

*Appending Solar

foreach f of local folders_solar {
    append using "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta"
        if regexm("`f'", "full_current_([0-9\.]+)_solar_cg") {
        local extracted_percent = regexs(1)
        replace percent = `extracted_percent' if percent == .
    }
}


replace category = "Residential Solar" if category == ""

*Appending EVs

foreach f of local folders_ev {
    append using "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta"
    
    if regexm("`f'", "full_current_([0-9\.]+)_evs_cg") {
        local extracted_percent = regexs(1)
        replace percent = `extracted_percent' if percent == .
    }
}

replace category = "Electric Vehicles" if category == ""

*Appending EVs (No LBD)

foreach f of local folders_ev_nolbd {
    append using "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta"
    
    if regexm("`f'", "full_current_([0-9\.]+)_ev_nolbd") {
        local extracted_percent = regexs(1)
        replace percent = `extracted_percent' if percent == .
    }
}
replace category = "ev_no_lbd" if category == ""


*Appending No LBD policies

foreach f of local folders_no_lbd {
    append using "${github}/data/4_results/`f'/compiled_results_all_uncorrected_vJK.dta"
    
    if regexm("`f'", "full_current_([0-9\.]+)_subs_cg") {
        local extracted_percent = regexs(1)
        replace percent = `extracted_percent' if percent == .
    }
}

replace category = "Weatherization" if inlist(program, "retrofit_res", "ihwap_nb","wisc_rf", "wap", "hancevic_rf")
replace category = "Appliance Rebates" if inlist(program, "c4a_cw", "rebate_es", "cw_datta", "c4a_dw", "dw_datta", "c4a_fridge", "fridge_datta", "esa_fridge")
replace category = "wind no lbd" if inlist(program, "hitaj_ptc", "metcalf_ptc", "shirmali_ptc") & category == ""
replace category = "solar no lbd" if inlist(program, "ct_solar", "ne_solar" ,"hughes_csi", "pless_ho", "pless_tpo") & category == ""

*----------------------------------------------------------
* Prep Data for Graph
*----------------------------------------------------------

keep if inlist(component_type, "WTP_cc", "cost", "program_cost", "WTP")

egen group_id = group(percent program)

gen ref_val = .
bysort group_id (component_type): replace ref_val = component_value if component_type == "program_cost"

bysort group_id (ref_val): replace ref_val = ref_val[_n-1] if missing(ref_val)
bysort group_id (ref_val): replace ref_val = ref_val[_n+1] if missing(ref_val)

gen component_value_scaled = component_value / ref_val

collapse (mean) component_value_scaled, by(component_type percent category)
rename component_value_scaled value_
reshape wide value, i(percent category) j(component_type) string

replace value_WTP_cc = value_WTP if value_WTP_cc == .

gen MVPF = value_WTP_cc / value_cost

*----------------------------------------------------------
* Graphing
*----------------------------------------------------------
replace percent = percent * 100
local percent_today = ${renewables_2020} * 100

local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

tw ///
	(line MVPF percent if category == "Wind Production Credits", lc("`bar_dark_blue'")) ///
	(line MVPF percent if category == "Residential Solar", lc("`bar_light_orange'")) ///
	(line MVPF percent if category == "solar no lbd", lp(dash) lc("`bar_light_orange'")) ///
	(line MVPF percent if category == "wind no lbd", lc("`bar_dark_blue'") lp(dash)) ///
	(line MVPF percent if category == "Weatherization", lc("`bar_light_blue'")) ///
	(line MVPF percent if category == "Appliance Rebates") ///
	(line MVPF percent if category == "Electric Vehicles", lc("`bar_light_gray'")) ///
	(line MVPF percent if category == "ev_no_lbd", lp(dash) lc("`bar_light_gray'")) ///
	, ///
	xline(`percent_today', noextend lcolor("black") lpattern(shortdash)) ///
	graphregion(color(white)) legend(off) ///
	plotregion(margin(b=0 l=0)) ///
	xtitle("Percent Renewables") ///
		xsize(8) ///	
		xlab(0(5)90, nogrid ) ///
	ytitle("MVPF") ///
	ylab(0(2.0)8, nogrid  format(%9.1f))
	
cap graph export "${output_fig}/figures_appendix/changing_grid_with_scatter.wmf", replace

	