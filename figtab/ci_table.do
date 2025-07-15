*****************************************************************
*             Export Final Datasets to Excel                    *
*****************************************************************

local table_name					"`4'"

local savings						"`5'"

local with_international			no

local export_excel_toggle			yes

	local output_path ${output_tab}/tables_appendix

*****************************************************
* 1. Reshape Datasets and Merge with Policy Details *
*****************************************************
foreach scc in "76" "193" "337" {
	
	*****************************************************
	* 1A.             Get Dataset Names                  *
	*****************************************************
	local selected_data_stub 		full_current_`scc'
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
		local stub_toggle = "`most_recent_folder'"
		di in green "Selected most recent folder: `selected_data_stub'"
	}
	
	
	use "${code_files}/4_results/`stub_toggle'/compiled_results_all_uncorrected_vJK", clear

	missings dropvars, force
	drop component_over_prog_cost 
	cap drop perc_switch
	ren component_value cv
	cap drop assumptions component_sd
		
	replace cv = cv
	cap drop l_component u_component
		
	reshape wide cv, i(program) j(component_type) string
	ren cv* *
	drop WTP_RoW WTP_USFut WTP_USPres WTP_USTotal

	preserve
		import excel "${code_files}/policy_details_v3.xlsx", clear first
		tempfile policy_labels
		save "`policy_labels.dta'", replace
	restore

	merge m:1 program using "`policy_labels.dta'", keep(3)
	drop if program == "cafe_dk"
	drop if broad_category == "Regulation"
	
	assert _N == 96

	missings dropvars, force
	drop _merge program_label_long
	drop correlation replications
	mvencode _all, mv(0) override
	order program_cost, after(WTP)

	***********************************************
	* 2. Check that Each Component Sums Correctly *
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
	assert round(wtp_no_ice, 0.0001) == round(wtp_no_ice_g + wtp_no_ice_local, 0.0001)
	assert round(wtp_yes_ev, 0.0001) == round(wtp_yes_ev_local + wtp_yes_ev_g, 0.0001) if group_label == "Electric Vehicles"
	assert round(wtp_loc, 0.0001) == round(wtp_yes_ev_local + wtp_no_ice_local, 0.0001) if group_label == "Electric Vehicles"

	drop wtp_no_ice_g wtp_no_ice_local wtp_yes_ev_g wtp_yes_ev_local

	assert round(wtp_soc, 0.0001) == round(wtp_glob + wtp_loc, 0.0001) if group_label == "Electric Vehicles"
	assert round(wtp_soc, 0.0001) == round(wtp_glob + wtp_loc, 0.0001) if group_label == "Hybrid Vehicles"
	 
	replace wtp_glob = wtp_glob + wtp_e_cost - wtp_r_glob if group_label == "Wind Production Credits"
	replace wtp_glob = wtp_glob + wtp_e_cost if group_label == "Residential Solar" | program == "solarize"
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
	assert round(wtp_soc_rbd, 0.0001) == round(wtp_soc_rbd_g + wtp_soc_rbd_l, 0.0001) if wtp_soc_rbd_g != 0 & wtp_soc_rbd_l != 0
	replace wtp_r_loc = wtp_soc_rbd_l if wtp_soc_rbd_l != 0 & wtp_r_loc == 0
	replace wtp_r_glob = wtp_soc_rbd_g if wtp_soc_rbd_g != 0  & wtp_r_glob == 0
	drop wtp_soc_rbd_l wtp_soc_rbd_g
	replace wtp_soc_rbd = wtp_r_glob + wtp_r_loc if wtp_soc_rbd == 0 & wtp_r_glob != 0 & wtp_r_loc != 0
	replace wtp_soc_rbd = wtp_r_glob if inlist(program, "care", "opower_ng", "rebate_es", "es_incent", "ac_mex", "fridge_mex", "nudge_ger", "nudge_qatar", "wap_mexico") | inlist(program, "india_offset")
	replace wtp_soc_rbd = -wtp_soc_rbd if program == "wisc_rf"


	**** Dynamic Price and Dynamic Enviro
	replace env_cost_wtp = 0 if env_cost_wtp == -1.00e-17
	replace cost_wtp = 0 if cost_wtp == -1.00e-17

	assert round(env_cost_wtp, 0.0001) == round(env_cost_wtp_g + env_cost_wtp_l, 0.0001) if env_cost_wtp_l != 0 & env_cost_wtp_g != 0 & group_label != "Gasoline Tax"

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
	assert total_cost == cost if total_cost != 0
	drop total_cost


	**** Normalization Factor
	gen normalization = program_cost // for normalizing all the factors such that program_cost (without admin cost) is 1
	gen prog_cost_no_normal = program_cost

	local components transfer wtp_loc wtp_glob wtp_soc_rbd env_cost_wtp cost_wtp producers WTP program_cost fisc_ext_sr fisc_ext_lr cost wtp_r_loc wtp_r_glob WTP_no_cc WTP_cc env_cost_wtp_g c_savings
	foreach comp of local components{
		replace `comp' = `comp' / normalization
	}


	if "`savings'" == "yes"{
		assert round(WTP, 0.001) == round(transfer + c_savings + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers, 0.001)
	}
	else{
		assert round(WTP, 0.001) == round(transfer + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers, 0.001)
	}

	assert round(cost, 0.01) == round(program_cost + fisc_ext_sr + fisc_ext_lr, 0.01) if program != "bev_state_i" // see if this is fixed after the latest big run
	assert round(MVPF, 0.01) == round(WTP / cost, 0.01) if MVPF != 99999


	*********************************
	* 3. Calculate Category Average *
	*********************************
	preserve

		tempfile all_policy_save
		save "`all_policy_save'", replace
		
		drop if extended == 1 & group_label != "International Nudges"
		assert WTP_cc == WTP if WTP_cc != 0
		sort table_order
			
		if "`savings'" == "no" {
			collapse (mean) WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer table_order, by(group_label)
		}	
		
		if "`savings'" == "yes" {
			collapse (mean) WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer c_savings table_order, by(group_label)
		}

		gen MVPF = WTP / cost
		replace table_order = .
		tempfile category_averages
		save "`category_averages'", replace		
					
	restore

	**************************
	* 4. Organize Components *
	**************************
	keep program_label_short group_label MVPF WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer table_order extended c_savings across_group_ordering
	sort table_order
		
	if "`savings'" == "no"{
		drop c_savings
		order program_label_short transfer wtp_glob wtp_loc wtp_soc_rbd env_cost_wtp cost_wtp producers WTP program_cost fisc_ext_sr fisc_ext_lr cost MVPF

	}	
	else {
		order program_label_short transfer wtp_glob wtp_loc wtp_soc_rbd env_cost_wtp cost_wtp producers WTP program_cost fisc_ext_sr fisc_ext_lr cost MVPF c_savings
	}

	replace program_label_short = program_label_short + " " + "*" if extended == 1
	drop extended
	order table_order

	// Deal with Ordering of Revenue Raisers
	replace across_group_ordering = 11 if group_label == "Gasoline Taxes"
	replace across_group_ordering = 12 if group_label == "Other Fuel Taxes"
	replace across_group_ordering = 13 if group_label == "Other Revenue Raisers"
	replace across_group_ordering = 14 if group_label == "Cap and Trade"	

	replace table_order = table_order + across_group_ordering


	// Bring in Category Averages
	append using "`category_averages'"

	levelsof(group_label), local(group_loop)
	foreach g of local group_loop {
		
		sum table_order if group_label == "`g'"
		replace table_order = (r(min) - 1) if group_label == "`g'" & program_label_short == "" 
		replace program_label_short = "`g'" if group_label == "`g'" & program_label_short == ""
				
	}
	sort table_order


***************************************************************************
* 5. Make Confidence Interval Table. *
***************************************************************************	

preserve 

	use "${output_fig}/figures_data/avgs_current_`scc'_yes_no_yes_v3.dta", clear

	levelsof category, local(categories)
	
	foreach cat in `categories' {
		qui sum l_MVPF if category == "`cat'"
		local `cat'_low = `r(mean)'
		
		qui sum h_MVPF if category == "`cat'"
		local `cat'_high = `r(mean)'

	}
	
restore

preserve 
	use "${output_fig}/figures_data/bts_current_`scc'_yes_no_yes_v3.dta", clear
	rename policy program
	merge 1:1 program using "`policy_labels.dta'", keep(3)
	keep program_label_short *MVPF
	
	tempfile MVPF_bootstraps	
	save "`MVPF_bootstraps'", replace	
restore

drop if inlist(group_label, "Cookstoves", "Deforestation", "Rice Burning", "Wind Offset", "International Rebates", "International Nudges")
drop if substr(program_label_short, -1, 1) == "*"
replace table_order = _n

levelsof(group_label), local(group_loop)
foreach g of local group_loop {
	
	qui sum table_order if group_label == "`g'"
	insobs 1, after(r(min))
	replace table_order = _n
	
}

replace program_label_short = program_label_short[_n - 1] + ", with SEs" if program_label_short == ""
replace group_label = group_label[_n - 1] if group_label == ""


// Calculate Average MVPFs w/o Policies w/o SEs
preserve

	use "`all_policy_save'", clear
	drop if international == 1 | extended == 1 | no_SE == 1
	
	assert WTP_cc == WTP if WTP_cc != 0
	sort table_order
		
	if "`savings'" == "no" {
		collapse (mean) WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer table_order, by(group_label)
	}	
	
	if "`savings'" == "yes" {
		collapse (mean) WTP program_cost cost env_cost_wtp cost_wtp producers fisc_ext_lr wtp_glob wtp_loc wtp_soc_rbd fisc_ext_sr transfer c_savings table_order, by(group_label)
	}

	gen MVPF = WTP / cost
	replace table_order = .
	replace group_label = group_label + ", with SEs"
	
	ds group_label table_order, not
	foreach var in `r(varlist)' {
		
		rename `var' `var'_averaged
		
	}	
	rename group_label program_label_short
	
	tempfile category_averages_no_SE
	save "`category_averages_no_SE'", replace		
		
restore

merge 1:1 program_label_short using "`category_averages_no_SE'"

ds *_averaged
foreach var in `r(varlist)' {
	
	local original = substr("`var'", 1, strlen("`var'") - 9)
	replace `original' = `var' if _merge == 3 & `original' == .
	drop `var'
	
}
sort table_order
drop _merge across_group_ordering

merge 1:1 program_label_short using "`MVPF_bootstraps'"
sort table_order
drop _merge group_label

// Handle MVPFs with cost curves manually.

// WIND CIS
replace l_MVPF = `wind_low' if program_label_short == "Wind Production Credits, with SEs"
replace h_MVPF = `wind_high' if program_label_short == "Wind Production Credits, with SEs"

// SOLAR CIs
replace l_MVPF = `solar_low' if program_label_short == "Residential Solar, with SEs"
replace h_MVPF = `solar_high' if program_label_short == "Residential Solar, with SEs"

// EVs CIs
replace l_MVPF = `bev_low' if program_label_short == "Electric Vehicles, with SEs"
replace h_MVPF = `bev_high'  if program_label_short == "Electric Vehicles, with SEs"

// HYBRID CIs
replace l_MVPF = `hev_low' if program_label_short == "Hybrid Vehicles, with SEs"
replace h_MVPF = `hev_high'  if program_label_short == "Hybrid Vehicles, with SEs"

// VEHICLE RETIREMENT CIs
replace l_MVPF = `vehicle_retirement_low' if program_label_short == "Vehicle Retirement, with SEs"
replace h_MVPF =  `vehicle_retirement_high' if program_label_short == "Vehicle Retirement, with SEs"

// APPLIANCE REBATES CIs
replace l_MVPF = `appliance_rebates_low' if program_label_short == "Appliance Rebates, with SEs"
replace h_MVPF = `appliance_rebates_high' if program_label_short == "Appliance Rebates, with SEs"

// WEATHERIZATION CIs
replace l_MVPF = `weatherization_low' if program_label_short == "Weatherization, with SEs"
replace h_MVPF = `weatherization_high' if program_label_short == "Weatherization, with SEs"

// GASOLINE TAXES CIs
replace l_MVPF = `gas_tax_low' if program_label_short == "Gasoline Taxes, with SEs"
replace h_MVPF = `gas_tax_high' if program_label_short == "Gasoline Taxes, with SEs"

// OTHER FUEL TAXES CIs
replace l_MVPF = `other_fuel_taxes_low' if program_label_short == "Other Fuel Taxes, with SEs"
replace h_MVPF = `other_fuel_taxes_high' if program_label_short == "Other Fuel Taxes, with SEs"

// OTHER REVENUE RAISERS CIs
replace l_MVPF = `other_rev_raisers_low' if program_label_short == "Other Revenue Raisers, with SEs"
replace h_MVPF = `other_rev_raisers_high' if program_label_short == "Other Revenue Raisers, with SEs"

// OTHER NUDGES CIs
replace l_MVPF = `other_nudges_low' if program_label_short == "Other Nudges, with SEs"
replace h_MVPF = `other_nudges_high' if program_label_short == "Other Nudges, with SEs"

// OTHER SUBSIDIES CIs
replace l_MVPF = `other_subsidies_low' if program_label_short == "Other Subsidies, with SEs"
replace h_MVPF = `other_subsidies_high' if program_label_short == "Other Subsidies, with SEs"

replace program_label_short = "(Sub)sample with SEs" if substr(program_label_short, -8, .) == "with SEs"


sort table_order
drop table_order
drop if transfer == .
gen id = _n
keep program_label_short MVPF l_MVPF h_MVPF id
rename (MVPF l_MVPF h_MVPF) (MVPF_`scc' l_MVPF_`scc' h_MVPF_`scc')

	tempfile `scc'_mvpfs	
		save "``scc'_mvpfs.dta'", replace
}

use "`76_mvpfs.dta'", clear

foreach scc in "193" "337" {
	merge 1:1 program_label_short id using "``scc'_mvpfs.dta'", nogen
}
sort id
drop id
order program_label_short *193 *76 *337
	
copy "${output_tab}/tables_templates/TEMPLATE_with_CIs.xlsx" "`output_path'/`table_name'_with_cis.xlsx", replace	
export excel "`output_path'/`table_name'_with_cis.xlsx", first(var) sheet("data_export", replace) keepcellfmt
