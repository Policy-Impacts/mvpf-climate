***** MVPF with Changing Elasticity Figure *****

*Set toggles for figure
local mvpf_max 				8
local bar_dark_orange = "214 118 72"
local bar_blue = "36 114 237"
local bar_dark_blue = "8 51 97"
local re_pull_data = "no" // Re-run data for the figure (if no, uses saved data from previous run)

global renewables_loop = "yes"
global renewables_2020 = 0.1952 // EPA eGRID renewables (including Hydro)

*--------------------------------------------
* Changing Renewable Percentages (Wind)
*--------------------------------------------
if "`re_pull_data'" == "yes" {

	forvalues percent = 0.01(0.01)0.90 {
		global renewables_percent = `percent'
		
		do "${github}/wrapper/metafile.do" ///
			"current" /// 2020
			"193" /// SCC
			"yes" /// learning-by-doing
			"no" /// savings
			"yes" /// profits
			"hitaj_ptc shirmali_ptc metcalf_ptc" /// programs to run
			0 /// reps
			"full_current_${renewables_percent}" // nrun

	}
}	
*--------------------------------------------
* Changing Renewable Percentages (Solar)
*--------------------------------------------
if "`re_pull_data'" == "yes" {
	forvalues percent = 0.01(0.01)0.90 {
		global renewables_percent = `percent'
		
		do "${github}/wrapper/metafile.do" ///
			"current" /// 2020
			"193" /// SCC
			"yes" /// learning-by-doing
			"no" /// savings
			"yes" /// profits
			"ct_solar ne_solar hughes_csi pless_ho pless_tpo" /// programs to run
			0 /// reps
			"full_current_${renewables_percent}_solar" // nrun

	}

}
*--------------------------------------------
* Changing Renewable Percentages (EVs)
*--------------------------------------------
local re_pull_data = "yes"

if "`re_pull_data'" == "yes" {
	forvalues percent = 0.10(0.10)0.90 {
		global renewables_percent = `percent'
		
		do "${github}/wrapper/metafile.do" ///
			"current" /// 2020
			"193" /// SCC
			"yes" /// learning-by-doing
			"no" /// savings
			"yes" /// profits
			"federal_ev bev_state muehl_efmp" /// programs to run
			0 /// reps
			"full_current_${renewables_percent}_evs" // nrun

	}

}	

*--------------------------------------------------------------------------------------
* Changing Renewable Percentages (Weatherization, Appliance Rebates, Wind No LBD, Solar No LBD)
*--------------------------------------------------------------------------------------
local re_pull_data = "yes"
if "`re_pull_data'" == "yes" {
	forvalues percent = 0.01(0.01)0.90 {
		global renewables_percent = `percent'
		
		do "${github}/wrapper/metafile.do" ///
			"current" /// 2020
			"193" /// SCC
			"no" /// learning-by-doing
			"no" /// savings
			"yes" /// profits
			"c4a_cw rebate_es cw_datta c4a_dw dw_datta c4a_fridge fridge_datta esa_fridge retrofit_res ihwap_nb wisc_rf wap hancevic_rf hitaj_ptc metcalf_ptc shirmali_ptc ct_solar ne_solar hughes_csi pless_ho pless_tpo" /// programs to run
			0 /// reps
			"full_current_${renewables_percent}_subs" // nrun

	}

}	
global renewables_loop = "no"

*--------------------------------------------------------------------------------------
* Changing Renewable Percentages (EVs No LBD)
*--------------------------------------------------------------------------------------
global renewables_loop = "yes"
local re_pull_data = "yes"
if "`re_pull_data'" == "yes" {
	forvalues percent = 0.9(0.05)0.95 {
		global renewables_percent = `percent'
		
		do "${github}/wrapper/metafile.do" ///
			"current" /// 2020
			"193" /// SCC
			"no" /// learning-by-doing
			"no" /// savings
			"yes" /// profits
			"federal_ev bev_state muehl_efmp" /// programs to run
			0 /// reps
			"full_current_${renewables_percent}_ev_nolbd" // nrun

	}

}	
global renewables_loop = "no"

*----------------------------------------------------------
* Append Runs Together (Need to Adjust if re-running data)
*----------------------------------------------------------
	
local folders_wind : dir "${github}/data/4_results/wind_grid" dirs "*_full_current_.*"
local folders_solar : dir "${github}/data/4_results/solar_grid" dirs "*_full_current_.*"
local folders_no_lbd : dir "${github}/data/4_results/no_lbd_grid" dirs "*_full_current_.*"
local folders_ev: dir "${github}/data/4_results/ev_grid" dirs "*_full_current_.*"
local folders_ev_nolbd: dir "${github}/data/4_results/ev_no_lbd_grid" dirs "*_full_current_.*"


*Appending Wind
use "${github}/data/4_results/wind_grid/2025-05-07_11-16-17__full_current_.01/compiled_results_all_uncorrected_vJK.dta", clear
gen percent = 0.01

local percent = 0.02
foreach f of local folders_wind {
		if "`f'" != "2025-05-07_11-16-17__full_current_.01" {
	
		append using "${github}/data/4_results/wind_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		replace percent = `percent' if percent == .
		local percent = `percent' + 0.01	
		
	}
	
}
gen category = "wind"

*Appending Solar
local percent = 0.01
foreach f of local folders_solar {
	
		append using "${github}/data/4_results/solar_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		replace percent = `percent' if percent == .
		local percent = `percent' + 0.01	
	
}
replace category = "solar" if category == ""

*Appending EVs
local percent = 0.01
foreach f of local folders_ev {
	
		append using "${github}/data/4_results/ev_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		if `percent' == 0.09 {
				
			local percent = 0.1
		}
		
		if `percent' > 0.08 {
			
			replace percent = `percent' if percent == .
			local percent = `percent' + 0.1
			
		}
		
		if `percent' <= 0.08 {
			replace percent = `percent' if percent == .
			local percent = `percent' + 0.01
		}
	
}
replace category = "ev" if category == ""

*Appending EVs (No LBD)
local percent = 0.01
foreach f of local folders_ev_nolbd {
	
		append using "${github}/data/4_results/ev_no_lbd_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		if `percent' >= 0.05 & `percent' < 0.9 {
			
			replace percent = `percent' if percent == .
			local percent = `percent' + 0.25
			
			if `percent' == 0.8 {
				local percent = 0.9
			}
			
		}
		
		if `percent' <= 0.03 {
			replace percent = `percent' if percent == .
			local percent = `percent' + 0.01
			
			if `percent' == 0.04 {
				local percent = 0.05
			}
		}
		
		if `percent' == 0.9 {
			replace percent = `percent' if percent == .
		}
	
}
replace category = "ev_no_lbd" if category == ""

*Appending No LBD policies
local percent = 0.01
foreach f of local folders_no_lbd {
	
		append using "${github}/data/4_results/no_lbd_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		replace percent = `percent' if percent == .
		local percent = `percent' + 0.01	
	
}
replace category = "weatherization" if inlist(program, "retrofit_res", "ihwap_nb","wisc_rf", "wap", "hancevic_rf")
replace category = "appliance rebates" if inlist(program, "c4a_cw", "rebate_es", "cw_datta", "c4a_dw", "dw_datta", "c4a_fridge", "fridge_datta", "esa_fridge")
replace category = "wind no lbd" if inlist(program, "hitaj_ptc", "metcalf_ptc", "shirmali_ptc") & category == ""
replace category = "solar no lbd" if inlist(program, "ct_solar", "ne_solar" ,"hughes_csi", "pless_ho", "pless_tpo") & category == ""


*----------------------------------------------------------
* Graphing
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
replace percent = percent * 100
local percent_today = ${renewables_2020} * 100

local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

tw ///
	(line MVPF percent if category == "wind", lc("`bar_dark_blue'")) ///
	(line MVPF percent if category == "solar", lc("`bar_light_orange'")) ///
	(line MVPF percent if category == "solar no lbd", lp(dash) lc("`bar_light_orange'")) ///
	(line MVPF percent if category == "wind no lbd", lc("`bar_dark_blue'") lp(dash)) ///
	(line MVPF percent if category == "weatherization", lc("`bar_light_blue'")) ///
	(line MVPF percent if category == "appliance rebates") ///
	(line MVPF percent if category == "ev", lc("`bar_light_gray'")) ///
	(line MVPF percent if category == "ev_no_lbd", lp(dash) lc("`bar_light_gray'")) ///
	, ///
	xline(`percent_today', noextend lcolor("black") lpattern(shortdash)) ///
	graphregion(color(white)) legend(order(1 "Wind" 2 "Solar" 3 "Solar No LBD" 4 "Wind No LBD" 5 "Weatherization" 6 "Appliance Rebates" 7 "EVs" 8 "EVs No LBD")) ///
	plotregion(margin(b=0 l=0)) ///
	xtitle("Percent Renewables") ///
		xsize(8) ///	
		xlab(0(5)90, nogrid ) ///
	ytitle("MVPF") ///
	ylab(0(2.0)8, nogrid  format(%9.1f))

	