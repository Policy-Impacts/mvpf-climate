***** MVPF with Changing Elasticity Figure *****
/*
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
*/
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
gen category = "Wind Production Credits"

*Appending Solar
local percent = 0.01
foreach f of local folders_solar {
	
		append using "${github}/data/4_results/solar_grid/`f'/compiled_results_all_uncorrected_vJK.dta"
		
		replace percent = `percent' if percent == .
		local percent = `percent' + 0.01	
	
}
replace category = "Residential Solar" if category == ""

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
replace category = "Electric Vehicles" if category == ""

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
replace category = "Weatherization" if inlist(program, "retrofit_res", "ihwap_nb","wisc_rf", "wap", "hancevic_rf")
replace category = "Appliance Rebates" if inlist(program, "c4a_cw", "rebate_es", "cw_datta", "c4a_dw", "dw_datta", "c4a_fridge", "fridge_datta", "esa_fridge")
replace category = "wind no lbd" if inlist(program, "hitaj_ptc", "metcalf_ptc", "shirmali_ptc") & category == ""
replace category = "solar no lbd" if inlist(program, "ct_solar", "ne_solar" ,"hughes_csi", "pless_ho", "pless_tpo") & category == ""


*----------------------------------------------------------
* Getting CA and MI grid MVPFs
*----------------------------------------------------------
preserve
	import excel "${code_files}/policy_details_v3.xlsx", clear first
	tempfile policy_labels
	save "`policy_labels.dta'", replace
restore
	
preserve
foreach spec in "2025-04-28_10-02-55__full_current_193_CA_grid" "2025-05-14_13-00-03__full_current_193_MI_grid" {
	
	local stub_toggle = "`spec'"
	
	if strpos("`spec'" , "MI_grid") {
		local state_grid = "MI"
	}
	
	if strpos("`spec'" , "CA_grid") {
		local state_grid = "CA"
	}

	
	use "${code_files}/4_results/`stub_toggle'/compiled_results_all_uncorrected_vJK", clear
	
	

	// missings dropvars, force
	drop component_over_prog_cost 
	cap drop perc_switch
	ren component_value cv
	cap drop assumptions component_sd
		
	replace cv = cv
	cap drop l_component u_component
		
	reshape wide cv, i(program) j(component_type) string
	ren cv* *
	drop WTP_RoW WTP_USFut WTP_USPres WTP_USTotal wind_g_wf wind_l_wf epsilon

	merge m:1 program using "`policy_labels.dta'", keep(3)
	drop if program == "cafe_dk"
	drop if broad_category == "Regulation"
	// // assert _N == 96

	// missings dropvars, force
	drop _merge program_label_long
	drop correlation replications
	mvencode _all, mv(0) override
	order program_cost, after(WTP)

	***********************************************
	* A. Check that Each Component Sums Correctly *
	***********************************************

	**** Transfer
	cap gen wtp_install = 0
	cap drop transfer
	gen transfer = wtp_cons + wtp_deal + wtp_install
	drop wtp_cons wtp_deal wtp_install
	replace transfer = wtp_inf + wtp_marg if (inlist(group_label, "Weatherization", "Appliance Rebates", "Other Nudges", "Vehicle Retirement") & ///
											 program != "care" & program != "solarize" & program != "her_compiled" & program != "cw_datta" & program != "dw_datta" & ///
											 program != "fridge_datta" & program != "wisc_rf") | inlist(program, "ca_electric", "cookstoves", "mx_deforest", "ug_deforest")
	replace transfer = wtp_inf + wtp_marg + wtp_ctr if inlist(program, "ihwap_hb", "ihwap_lb")
	drop wtp_inf wtp_marg wtp_private
	cap gen wtp_abatement = 0
	cap gen wtp_permits = 0
	replace transfer = wtp_abatement + wtp_permits if group_label == "Cap and Trade"
	drop wtp_abatement wtp_permits
	replace transfer = wtp_prod if group_label == "Wind Production Credits" | inlist(program, "rao_crude", "bmm_crude", "india_offset")
	replace transfer = 1 if program == "sallee_hy"

	**** Global and Local Enviro

	drop wtp_no_ice_g wtp_no_ice_local wtp_yes_ev_g wtp_yes_ev_local
	
	replace wtp_glob = wtp_glob + wtp_e_cost if group_label == "Residential Solar"| program == "solarize"
	replace wtp_glob = (wtp_glob + wtp_e_cost) - wtp_r_glob if group_label == "Wind Production Credits"
	replace wtp_glob = wtp_soc_g if inlist(group_label, "Gasoline Taxes", "Cap and Trade") | inlist(program, "cookstoves", "bmm_crude", "bunker_fuel", "ethanol", "rao_crude")
	replace wtp_loc = wtp_soc_l if inlist(group_label, "Gasoline Taxes", "Cap and Trade") | inlist(program, "cookstoves", "bmm_crude", "bunker_fuel", "ethanol", "rao_crude")
	replace wtp_loc = 0 if wtp_loc == -1.00e-35
	replace wtp_loc = wtp_loc - wtp_r_loc if group_label == "Wind Production Credits"

	cap gen wtp_leak = 0
	cap gen wtp_no_leak = 0
	drop wtp_yes_ev wtp_yes_hev wtp_no_ice wtp_soc wtp_e_cost wtp_soc_g wtp_soc_l wtp_leak wtp_no_leak 

	**** Rebound
	replace wtp_soc_rbd = 0 if wtp_soc_rbd == 1.00e-11
	replace wtp_soc_rbd_l = 0 if wtp_soc_rbd_l == 1.00e-20 | program == "rggi"
	replace wtp_soc_rbd_g = 0 if wtp_soc_rbd_g == 1.00e-20 | program == "rggi"

	replace wtp_r_loc = wtp_soc_rbd_l if wtp_soc_rbd_l != 0 & wtp_r_loc == 0
	replace wtp_r_glob = wtp_soc_rbd_g if wtp_soc_rbd_g != 0  & wtp_r_glob == 0
	drop wtp_soc_rbd_l wtp_soc_rbd_g
	replace wtp_soc_rbd = wtp_r_glob + wtp_r_loc if wtp_soc_rbd == 0 & wtp_r_glob != 0 & wtp_r_loc != 0
	replace wtp_soc_rbd = wtp_r_glob if inlist(program, "care", "opower_ng", "rebate_es", "es_incent", "ac_mex", "fridge_mex", "nudge_ger", "nudge_qatar", "wap_mexico") | inlist(program, "india_offset")
	replace wtp_soc_rbd = -wtp_soc_rbd if program == "wisc_rf"


	**** Dynamic Price and Dynamic Enviro
	replace env_cost_wtp = 0 if env_cost_wtp == -1.00e-17
	replace cost_wtp = 0 if cost_wtp == -1.00e-17

	drop cost_mvpf enviro_mvpf firm_mvpf

	**** Producers
	gen producers = firm_cost_wtp + wtp_prod_s + wtp_prod_u
	replace producers = wtp_prod if inlist(group_label, "Residential Solar", "Appliance Rebates", "Weatherization", "Other Nudges", "Home Energy Reports") | program == "care" | program == "ca_electric"
	replace producers = wtp_prod if inlist(program, "jet_fuel", "CPP_aj", "CPP_pj", "PER", "baaqmd", "ca_electric")
	replace producers = -wtp_prod if program == "wisc_rf"
	drop wtp_prod_s wtp_prod_u wtp_prod

	**** Fiscal Externalities
	replace fisc_ext_s = beh_fisc_ext + fed_fisc_ext + state_fisc_ext if group_label == "Electric Vehicles" | group_label == "Hybrid Vehicles"
	replace fisc_ext_t = gas_corp_fisc_e + gas_fisc_ext + utility_fisc_ext if group_label == "Electric Vehicles" | group_label == "Hybrid Vehicles"

	gen fisc_ext_sr = fisc_ext_s + fisc_ext_t
	drop fisc_ext_s fisc_ext_t

	drop beh_fisc_ext fed_fisc_ext state_fisc_ext gas_corp_fisc_e gas_fisc_ext utility_fisc_ext

	**** Total WTP
	gen WTP_no_cc = WTP
	replace WTP = WTP_cc if WTP_cc != 0

	**** Total Cost
	// assert total_cost == cost if total_cost != 0
	drop total_cost


	**** Normalization Factor
	gen normalization = program_cost // for normalizing all the factors such that program_cost (without admin cost) is 1
	gen prog_cost_no_normal = program_cost

	local components transfer wtp_loc wtp_glob wtp_soc_rbd env_cost_wtp cost_wtp producers WTP program_cost fisc_ext_sr fisc_ext_lr cost wtp_r_loc wtp_r_glob WTP_no_cc WTP_cc env_cost_wtp_g c_savings
	foreach comp of local components{
		replace `comp' = `comp' / normalization
	}


	*********************************
	* B. Calculate Category Average *
	*********************************
		drop if extended == 1 & group_label != "International Nudges"
		sort table_order
			
		collapse (mean) WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer table_order, by(group_label)

		gen MVPF = WTP / cost
		replace table_order = .
		rename MVPF MVPF_`state_grid'
		rename group_label category
		keep category MVPF

		keep if inlist(category, "Appliance Rebates", "Weatherization", "Electric Vehicles", "Residential Solar", "Wind Production Credits") 

				
		tempfile category_averages_`state_grid'
		save "`category_averages_`state_grid''", replace		
}

use `category_averages_CA', clear
merge 1:1 category using `category_averages_MI', nogen

tempfile category_averages
save "`category_averages'"
restore

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

*Add in CA and MI MVPFs
merge m:1 category using "`category_averages'", nogen
end
replace MVPF_CA = . if abs(percent -.44) > 0.005 // eGRID 2020 CA Renewable Share is 43.64%
replace MVPF_MI = . if abs(percent -.10) > 0.005 // eGRID 2020 CA Renewable Share is 10.30%

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
	(scatter MVPF_CA percent) ///
	(scatter MVPF_MI percent) ///
	, ///
	xline(`percent_today', noextend lcolor("black") lpattern(shortdash)) ///
	graphregion(color(white)) legend(off) ///
	plotregion(margin(b=0 l=0)) ///
	xtitle("Percent Renewables") ///
		xsize(8) ///	
		xlab(0(5)90, nogrid ) ///
	ytitle("MVPF") ///
	ylab(0(2.0)8, nogrid  format(%9.1f))
end
cap graph export "${output_fig}/figures_appendix/changing_grid_with_scatter.wmf", replace

	