
local output_path ${output_fig}

*-----------------------------------------------------------------------*
* 0 -  Get Data File
*-----------------------------------------------------------------------*

local selected_data_stub 		`1'
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



use "${code_files}/4_results/`selected_data_stub'/compiled_results_all_uncorrected_vJK.dta", clear

local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

global program_keep 		"`3'"
global reg_compare 			"`2'"

global value_local_RPS 		no

*-----------------------------------------------------------------------*
* 0 -  Automated Graph Titles.
*-----------------------------------------------------------------------*
if "${program_keep}" == "cafe_dk" {
	local reg_graph_title "CAFE Standards"
	local subtitle "Leard and McConnell (2017); Davis and Knittel (2019)"
}
if "${program_keep}" == "cafe_j" {
	local reg_graph_title "CAFE Standards"
	local subtitle "Jacobsen (2013)"
}
if "${program_keep}" == "cafe_as" {
	local reg_graph_title "CAFE Standards"
	local subtitle "Anderson and Sallee (2011)"
}
if "${program_keep}" == "rps" {
	local reg_graph_title "RPS"
	
	if "${value_local_RPS}" == "yes"{
		local subtitle "Greenstone and Nath (2020), with Local Pollution"	
	}
	
	if "${value_local_RPS}" == "no"{
		local subtitle "Greenstone and Nath (2020)"	
	}
}

if "${reg_compare}" == "gas" {
	local policy_graph_title = "Gas Tax"
}
if "${reg_compare}" == "wind" {
	local policy_graph_title = "Wind PTC"
}

local legend_policy_name = substr("`policy_graph_title'", 1, strpos("`policy_graph_title'", " ") - 1)


*-----------------------------------------------------------------------*
* 1 -  Define Components to Which We Compare the Regulation.
*-----------------------------------------------------------------------*
if "${reg_compare}" == "wind" {
	
	preserve
	
		use "${code_files}/4_results/`selected_data_stub'/compiled_results_all_uncorrected_vJK.dta", clear
				
		keep if inlist(program, "metcalf_ptc", "hitaj_ptc", "shirmali_ptc")
		keep if inlist(component_type, "cost", "wtp_glob", "wtp_loc", "wtp_e_cost", "wtp_prod", "wtp_cons", "program_cost")
			
		levelsof(program), local(p_loop)
		foreach p of local p_loop {
			
			qui sum component_value if component_type == "program_cost" & program == "`p'"
			local program_cost = r(mean)
				
			levelsof(component_type), local(c_loop)
			foreach c of local c_loop {
				
				qui sum component_value if component_type == "`c'" & program == "`p'"
				replace component_value = (r(mean) / `program_cost') if component_type == "`c'" & program == "`p'"
				
			}
			
		}
						
		collapse (mean) component_value, by(component_type)
		replace component_type = "wtp_soc_g" if component_type == "wtp_glob" // Includes rebound but not lifecycle costs.
		replace component_type = "wtp_soc_l" if component_type == "wtp_loc"	 // Includes rebound.
				
		if "${value_local_RPS}" == "no" {
			
			replace component_value = 0 if component_type == "wtp_soc_l"
			replace component_value = 0 if component_type == "wtp_r_loc"			
			
		}			
		
		levelsof(component_type), local(c_loop)
		foreach c of local c_loop {
			
			replace component_value = 0 if component_type == "`c'" & component_value == .
			qui sum component_value if component_type == "`c'"
			local `c' = r(mean)
			
		}
		
		local normalize = abs(`wtp_soc_g' + `wtp_soc_l' + `wtp_e_cost')
		assert `wtp_cons' == 0
		assert `wtp_soc_l' == 0
		
		local compare_prod = (0) / `normalize'
		local compare_cons = (`wtp_cons' + `wtp_prod') / `normalize'
		local compare_soc = (`wtp_soc_g' + `wtp_soc_l' + `wtp_e_cost') / `normalize'
		local compare_cost = (`cost') / `normalize' // Assume subsidy is entirely passed on through lower prices.
	
		di in red `compare_prod'
		di in red `compare_cons'
		di in red `compare_soc'
		di in red `compare_cost'
		
	restore
	
}

if "${reg_compare}" == "gas" {
	
	preserve
	
		use "${code_files}/4_results/`selected_data_stub'/compiled_results_all_uncorrected_vJK.dta", clear		
		
		keep if inlist(program, "cog_gas", "dk_gas", "gelman_gas", "h_gas_01_06", "k_gas_15_22") | ///
				inlist(program, "levin_gas", "li_gas", "manzan_gas", "sent_ch_gas", "park_gas", "small_gas_lr", "su_gas")
			
		keep if inlist(component_type, "cost", "wtp_soc_g", "wtp_soc_l", "wtp_prod", "wtp_cons", "cost_wtp", "env_cost_wtp", "WTP")
		collapse (mean) component_value, by(component_type)
				
		levelsof(component_type), local(c_loop)
		foreach c of local c_loop {
			
			qui sum component_value if component_type == "`c'"
			local `c' = r(mean)
			
		}
		
		// Leaving LBD components out for now.
		local normalize = abs(`wtp_soc_g' + `wtp_soc_l') // For now, assume env_cost_wtp from gas taxes all global benefits.
		
		local compare_prod = (`wtp_prod' * -1) / `normalize'
		local compare_cons = ((`wtp_cons') * -1) / `normalize'
		local compare_soc = ((`wtp_soc_g' + `wtp_soc_l') * -1) / `normalize'
		local compare_cost = (`cost' * -1) / `normalize'
		
		di in red `compare_prod'
		di in red `compare_cons'
		di in red `compare_soc'
		di in red `compare_cost'
	
	restore
	
}

*-----------------------------------------------------------------------*
* 2 -  Clean Regulation Component Data.
*-----------------------------------------------------------------------*
keep if inlist(program, "${program_keep}")
keep if inlist(component_type, "wtp_prod", "wtp_cons", "wtp_soc", "cost")
keep program component_type component_value	

levelsof(component_type), local(c_loop)
foreach c of local c_loop {
	
	insobs 1
	replace program = "${reg_compare}" if program == ""
	replace component_type = "`c'" if program == "${reg_compare}" & component_type == ""
	
}	
sort component_type
replace component_value = `compare_prod' if program == "${reg_compare}" & component_type == "wtp_prod"
replace component_value = `compare_cons' if program == "${reg_compare}" & component_type == "wtp_cons"
replace component_value = `compare_cost' if program == "${reg_compare}" & component_type == "cost"
replace component_value = `compare_soc'  if program == "${reg_compare}" & component_type == "wtp_soc"

gsort -component_type program
gen xaxis = _n
levelsof(component_type), local(c_loop)
foreach c of local c_loop {
	
	qui sum xaxis if component_type == "`c'"
	insobs 1, after(r(max))
	replace xaxis = _n
	
}
qui sum xaxis
drop if xaxis == r(max) & component_value == .
	
levelsof(component_type), local(c_loop)
foreach c of local c_loop {
	
	qui sum xaxis if component_type == "`c'"
	local `c'_pos = r(mean)
	
}

qui sum xaxis
local xaxis_right_bound = r(max) + .5
	
*-----------------------------------------------------------------------*
* PANEL #1 -- COMPARISON OF REGULATION AND TAX/SPENDING POLICY
*-----------------------------------------------------------------------*	

if "${program_keep}" == "cafe_dk" & "${reg_compare}" == "gas" {
	
	tw ///
		(scatter component_value xaxis if component_type != "" & component_value >= 0 & program == "${program_keep}", mlabel(component_value) mcolor("`bar_light_blue'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///
		(scatter component_value xaxis if component_type != "" & component_value >= 0 & program == "${reg_compare}", mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///
		///
		(scatter component_value xaxis if component_type != "" & component_value < 0 & program == "${program_keep}", mlabel(component_value) mcolor("`bar_light_blue'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
		(scatter component_value xaxis if component_type != "" & component_value < 0 & program == "${reg_compare}", mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
		///
		(bar component_value xaxis if program == "${program_keep}", bcolor("`bar_light_blue'") barw(0.75)) ///
		(bar component_value xaxis if program == "${reg_compare}" , bcolor("`bar_light_orange'") barw(0.75)) ///
		(scatteri 0 0 0 `xaxis_right_bound', c(l) lcolor(black) msize(vsmall) mcolor(black) msize(zero)) ///
		, ///
		graphregion(color(white)) ///	
		plotregion(margin(b=0 l=0)) ///	
		xtitle(" ") ///
			xscale(range(0 `xaxis_right_bound')) ///
			xlab(`wtp_soc_pos' "Env Benefits" `wtp_prod_pos' "Producers" `wtp_cons_pos' "Consumers" `cost_pos' "Govt Cost", nogrid) ///
			xlab(`wtp_soc_pos' "Env Benefits" `wtp_prod_pos' "Producers" `wtp_cons_pos' "Consumers" `cost_pos' "Govt Cost", nogrid) ///
		ytitle("Component Value") ///
			ylab(-3(1)1, format(%9.1f) nogrid) ///
			yscale(titlegap(+4)) ///
		legend(order (5 "`reg_graph_title'" 6 "`policy_graph_title'") row(3) position(0) bplacement(neast) size(vsmall) symxsize(2) symysize(2) region(lcolor(white)) textfirst)  ///
		name(panel1, replace)
graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel1.png", replace
cap graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel1.wmf", replace		
}
*-----------------------------------------------------------------------*
* PANEL #2 -- COST WATERFALL
*-----------------------------------------------------------------------*		
preserve

	levelsof(program), local(p_loop)
	foreach p of local p_loop {
		
		qui sum component_value if program == "`p'" & component_type == "cost"
		local `p'_cost = r(mean)
		
	}

	levelsof(component_type), local(c_loop)
	foreach c of local c_loop {
		
		qui sum component_value if component_type == "`c'" & program == "${reg_compare}"
		local reg_`c' = r(mean)
		qui sum component_value if component_type == "`c'" & program == "${program_keep}"
		local policy_`c' = r(mean)
			
		local diff_`c' = `policy_`c'' - `reg_`c''
	}

	clear
	gen component_value = .
	insobs 5

	replace component_value = `${reg_compare}_cost' if _n == 1
	replace component_value = component_value[_n - 1] + (`diff_wtp_prod' / 1.8) if _n == 2
	replace component_value = component_value[_n - 1] + (`diff_wtp_cons' / 1.2) if _n == 3	
	replace component_value = (`diff_wtp_cons' / 1.2) + (`diff_wtp_prod' / 1.8) + `${reg_compare}_cost' if _n == 4
	replace component_value = `${program_keep}_cost' if _n == 5

	gen intermediate_value = component_value[_n - 1] if inrange(_n, 2, 3)
			
	gen base = 0
	gen xaxis = _n
	qui sum xaxis
	local xaxis_right_bound = r(max) + .5

	gen xlab_name = ""
	replace xlab_name = `""Gas Tax" "Revenue""' if _n == 1
	replace xlab_name = `""Compensating" "Producers""' if _n == 2
	replace xlab_name = `""Compensating" "Consumers""' if _n == 3
	replace xlab_name = `""Revenue" "Raised""' if _n == 4
	replace xlab_name = `""`reg_graph_title'" "Cost""' if _n == 5
	labmask(xaxis), values(xlab_name)

gen cost_difference = intermediate_value - component_value
		
if "${program_keep}" == "cafe_dk" & "${reg_compare}" == "gas" {		
	
	tw ///
		///
		(scatter component_value xaxis if _n == 1, mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
		(scatter component_value xaxis if _n == 4, mlabel(component_value) mcolor("`bar_dark_blue'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///	
		(scatter component_value xaxis if _n == 5, mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///
		(scatter component_value xaxis if cost_difference != . & cost_difference > 0, mlabel(cost_difference) mcolor("`bar_light_gray'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
		(scatter component_value xaxis if cost_difference != . & cost_difference < 0, mlabel(cost_difference) mcolor("`bar_light_gray'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///	
		///
		(bar component_value xaxis if inlist(xaxis, 1), bcolor("`bar_light_orange'") barw(0.75)) ///
		(bar component_value xaxis if inlist(xaxis, 4), bcolor("`bar_dark_blue'") barw(0.75)) ///
		(bar component_value xaxis if inlist(xaxis, 5), bcolor("`bar_light_blue'") barw(0.75)) ///	
			(rbar intermediate_value component_value xaxis if intermediate_value != ., bcolor("`bar_light_gray'") barw(0.75)) ///
		(scatteri 0 0 0 `xaxis_right_bound', c(l) lcolor(black) msize(vsmall) mcolor(black) msize(zero)) ///
		, ///
		graphregion(color(white)) ///	
		plotregion(margin(b=0 l=0)) ///		
		xtitle(" ") ///
			xscale(range(0 5)) ///
			xlab(1 "Gas Tax" 2 `""Compensation" "from Producers""' 3 `""Compensation" "to Drivers""' 4 "`legend_policy_name' + Income Tax" 5 `""CAFE" "Standards""', labsize(vsmall) nogrid) ///
		ytitle("Net Govt Cost") ///
			ylab(-3(1)1, format(%9.1f) nogrid) ///
			yscale(titlegap(+4)) ///
		legend(off) ///
		name(panel2, replace)
graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel2.png", replace
cap graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel2.wmf", replace		
}

	qui sum component_value if _n == 4	
	local final_revenue_save = r(mean)

restore

*-----------------------------------------------------------------------*
* PANEL #3 -- ADD FINAL REVENUE PIECE TO ORIGINAL GRAPH
*-----------------------------------------------------------------------*	
qui sum xaxis
insobs 1, after(r(max))
replace xaxis = _n
		
qui sum xaxis
replace component_value = `final_revenue_save' if xaxis == r(max)
replace component_type = "cost" if xaxis == r(max)
replace program = "DET" if xaxis == r(max)

levelsof(component_type), local(c_loop)
foreach c of local c_loop {
	
	qui sum xaxis if component_type == "`c'"
	local `c'_pos = r(mean)
	
}	
qui sum xaxis
local xaxis_right_bound = r(max) + .5	

if "$reg_compare" == "gas" {
	
	local fig_lower_bound = -3
	local tick_width = 1
	
}
if "${reg_compare}" == "wind" {
	
	local fig_lower_bound = -1
	local tick_width = 0.5
	
}
	
tw ///
	(scatter component_value xaxis if component_type != "" & component_value >= 0 & program == "${program_keep}", mlabel(component_value) mcolor("`bar_light_blue'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///
	(scatter component_value xaxis if component_type != "" & component_value >= 0 & program == "${reg_compare}", mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///
	(scatter component_value xaxis if component_type != "" & component_value >= 0 & program == "DET", mlabel(component_value) mcolor("`bar_dark_blue'") mstyle(none) mlabposition(12) mlabcolor(black) mlabformat(%9.2f)) ///	
	///
	(scatter component_value xaxis if component_type != "" & component_value < 0 & program == "${program_keep}", mlabel(component_value) mcolor("`bar_light_blue'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
	(scatter component_value xaxis if component_type != "" & component_value < 0 & program == "${reg_compare}", mlabel(component_value) mcolor("`bar_light_orange'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///
	(scatter component_value xaxis if component_type != "" & component_value < 0 & program == "DET", mlabel(component_value) mcolor("`bar_dark_blue'") mstyle(none) mlabposition(6) mlabcolor(black) mlabformat(%9.2f)) ///		
	///
	(bar component_value xaxis if program == "${program_keep}", bcolor("`bar_light_blue'") barw(0.75)) ///
	(bar component_value xaxis if program == "${reg_compare}" , bcolor("`bar_light_orange'") barw(0.75)) ///
	(bar component_value xaxis if program == "DET" , bcolor("`bar_dark_blue'") barw(0.75)) ///	
	(scatteri 0 0 0 `xaxis_right_bound', c(l) lcolor(black) msize(vsmall) mcolor(black) msize(zero)) ///
	, ///
	graphregion(color(white)) ///	
	plotregion(margin(b=0 l=0)) ///	
	xtitle(" ") ///
		xscale(range(0 `xaxis_right_bound')) ///
		xlab(`wtp_soc_pos' "Env Benefits" `wtp_prod_pos' "Producers" `wtp_cons_pos' "Consumers" `cost_pos' "Govt Cost", nogrid) ///
	ytitle("Component Value") ///
		ylab(`fig_lower_bound'(`tick_width')1, format(%9.1f) nogrid) ///
		yscale(titlegap(+4)) ///
	legend(order (7 "`reg_graph_title'" 8 "`policy_graph_title'" 9 "`legend_policy_name' + Income Tax") row(3) position(0) bplacement(neast) size(vsmall) symxsize(2) symysize(2) region(lcolor(white)) textfirst)  ///
	name(panel3, replace)

graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel3.png", replace
cap graph export "`output_path'/figures_appendix/reg_bars_${program_keep}_${reg_compare}_panel3.wmf", replace