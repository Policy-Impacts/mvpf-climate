
/***************************************************************************
 *                            WATERFALL CHARTS                             *
 ***************************************************************************
    This file produces waterfall charts for any policy in the main and
	extended samples of A Welfare Analysis of Policies Impacting Climate 
	Change.
****************************************************************************/



** 0) In policy .do file, determine what components will be in the waterfall chart

** 1) Import .dta file from bootstrap draws

** 2) All the normal waterfall stuff

** 3) Make sure I can go to the next policy in the wrapper smoothly (this is relevant for the metafile I think)

local output_path "${output_fig}/figures_main"

di in red "output path is `output_path'"

local weatherization_policies "wap", "ihwap", "ihwap_nb", "hancevic_rf", "retrofit_res"
local marketing_policies1 "opower_e", "opower_ng", "her_compiled", "audit_nudge", "food_labels"
local marketing_policies2 "solarize", "wap_nudge", "ihwap_hb", "ihwap_lb", "es_incent"
local rebates "ca_electric", "care", "c4a_cw", "c4a_dw", "c4a_fridge", "rebate_es", "esa_fridge"
local vehicles_re "baaqmd", "c4c_texas" , "c4c_federal" 
local cap_trade "rggi", "ca_cnt"

***************************************************************************************************************************

local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"


*****************************************************
* 0.             Get Dataset Names                  *
*****************************************************

local selected_data_stub 		`3'
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

********************************************************************************
*					  		  	 MAIN CODE  	    						   *
********************************************************************************
cap log close

log using "${code_files}/0_log/log_waterfalls", text replace

*Set modes if running externally
if "`2'"!="" local modes "`2'"

*Set all
if "`modes'"=="all" local modes baseline current

local fix_y_axis = 1

*-------------------------------------------------------------------------------
*	0. Define programs to run for
*-------------------------------------------------------------------------------
*Get all programs
local files : dir "${program_folder}" files "*.do"
foreach file in `files' {
	local cleanfile = subinstr("`file'",".do","",.)
	local all_functioning_programs `all_functioning_programs' `cleanfile'
}
local count_programs : word count `all_functioning_programs'
local half_progs = round(`count_programs'/2)
forval i = `half_progs'/`count_programs' {
	local prog: word `i' of `all_functioning_programs'
	local second_half `second_half' `prog'
}


local first_half : list all_functioning_programs - second_half

local programs `all_functioning_programs'
*****************************************


*Set programs if running externally
if "`1'"!="" {
	if "`1'"=="all_programs" local programs `all_functioning_programs'
	else local programs "`1'"
}
if "`1'" == ""{
	local programs "muehl_efmp"
}

global bootstrap_files = "${bootstrap_folder}/`selected_data_stub'_uncorrected_vJK"
global reps = 0

di in red "`programs'"

foreach mode in `modes' {
	di in red "The mode is `mode'"
	foreach program in `programs' {

		noi di "Mode: `mode'"
		noi di "Program: `program'"


		**locals for placing bars for chart
		local wtp_count : word count ${wtp_comps_`program'}
		local cost_count: word count ${cost_comps_`program'}
		local bar_count = `wtp_count' + `cost_count'
		local cost_position = `bar_count' + 1 // leave a white space in between full WTP and total cost bars
		
		if "`mode'" == "baseline"{
			use "${bootstrap_files}/`program'_`mode'_estimates_${reps}_replications.dta", clear
		}
		else{
			use "${bootstrap_files}/`program'_`mode'_estimates_${reps}_replications.dta", clear 
			keep if program == "`program'"
		}

		keep if inlist(component_type, "${wtp_comps_`program'_commas}") | inlist(component_type, "${wtp_comps_`program'_commas2}") ///
			  | inlist(component_type, "${cost_comps_`program'_commas}") | component_type == "MVPF"
	
		
		sum component_value if component_type == "program_cost" & program == "`program'"
		local program_cost = r(mean)

		replace component_value = component_value / `program_cost' if component_type != "MVPF"
		
		** locals for placing bars for chart
		gen xaxis = .
		local i = 1
		foreach comp in ${wtp_comps_`program'}{
			replace xaxis = `i' if component_type == "`comp'"
			local ++ i
		}
		local j = 1
		foreach comp in ${cost_comps_`program'}{
			replace xaxis = `j' + `wtp_count' + 1 if component_type == "`comp'"
			local ++ j
		}

		sort xaxis
				
		local wtp_white_out_first = 2 // Observation first white out bar appears (always true)
		local wtp_white_out_last = `wtp_count' - 1 // Observation last white out bar appears
				
		local cost_white_out_first = `wtp_count' + 3
		local cost_white_out_last = `bar_count'
		local yupb = 30
		local profit_message = ""
		local spec = ""
		
		if "${grid_model}" == "mid" {
			local grid_model = "Post-IRA"
		}
		
		if "${grid_model}" == "frz" {
			local grid_model = "Pre-IRA"
		}
		
		if "${value_profits}" == "no" {
			local profit_message = "Not Including Corporate Profits"
		}
		
		if "`mode'" == "baseline" {
			local spec = "In-Context"
		}
		
		if inlist("`program'", "`weatherization_policies'"){
			local yscales = "0(0.5)2"
			global note_`program' = `"SCC: ${sc_CO2_2020}, Grid Model - `grid_model', `profit_message', `spec'"'
			local ylabs = "ylabel(`yscales' , nogrid)"
		}
		
		if inlist("`program'", "`marketing_policies1'") | inlist("`program'", "`marketing_policies2'") {			
			global note_`program'= `"SCC: ${sc_CO2_2020}, Grid Model - `grid_model', `profit_message', `spec'"'
			local ylabs = "ylabel( , nogrid)"
		}
		
		if inlist("`program'", "`rebates'") {
			local yscales = "0(1)2"
			global note_`program' = `"SCC: ${sc_CO2_2020}, Grid Model - `grid_model', `profit_message', `spec'"'
			local ylabs = "ylabel(`yscales' , nogrid)"
		}
		
		if inlist("`program'", "`vehicles_re'") {
			local yscales = "0(2)8"
			global note_`program' = `"SCC: ${sc_CO2_2020}, Grid Model - `grid_model', `profit_message', `spec'"'
			local ylabs = "ylabel(`yscales' , nogrid)"
		}
		
		if inlist("`program'", "`cap_trade'") {			
			global note_`program'= `"SCC: ${sc_CO2_2020}, Grid Model - `grid_model', `spec'"'
			local ylabs = "ylabel( , nogrid)"
			
			if "`program'" == "rggi" {
				local ylabs = "ylabel(-40(20)20 , nogrid)"
			}
		}
		
		*********************************************
				
		g value2 = component_value
		g white_out = value2
		g neg_color = .

		g value2_usp = .
		g value2_usf = .
		g value2_row = .
				
		recast double value2
		recast double white_out

		forv i = `wtp_white_out_first'/`wtp_white_out_last' {
			replace white_out = value2[`i'-1]  in `i' if component_value[`i'] >= 0 // postive component
			replace value2 = value2[`i'-1] + component_value  in `i' if component_value[`i'] >= 0 // 
				
			replace white_out = value2[`i'- 1]  + component_value in `i' if component_value[`i'] < 0 & component_value[`i'-1] >= 0 // negative component, previous component positive, bar positive
			replace value2 = value2[`i'-1] in `i' if component_value < 0 & component_value[`i'-1] >= 0 // 
				
			replace white_out = white_out[`i'- 1]  + component_value in `i' if component_value[`i'] < 0 & component_value[`i'-1] < 0 // negative component, previous component negative, bar positive
			replace value2 = white_out[`i'-1] in `i' if component_value < 0 & component_value[`i'-1] < 0 
					
			replace white_out = white_out[`i' - 1] in `i' if component_value > 0 & component_value[`i' - 1] < 0 // positive component, previous component negative, bar positive
			replace value2 = white_out[`i' - 1] + component_value in `i' if component_value > 0 & component_value[`i' - 1] < 0

			replace white_out = white_out[`i' - 3] in `i' if component_value > 0 & component_value[`i' - 3] < 0 & component_value[`i' - 1] == 0 // positive component, previous component zero, last nonzero component negative, bar positive
			replace value2 = white_out[`i' - 3] + component_value in `i' if component_value > 0 & component_value[`i' - 3] < 0 & component_value[`i' - 1] == 0

			replace neg_color = component_value[`i'] + neg_color[`i' - 1] in `i' if component_value[`i'] < 0 & (neg_color[`i' - 1] + component_value[`i']) <= 0 // negative component, previous component negative, bar negative
			replace white_out = 0 in `i' if component_value[`i'] < 0 & (value2[`i'] + component_value[`i']) < 0

			replace neg_color = value2[`i' - 1] + component_value[`i'] in `i' if (value2[`i' - 1] + component_value[`i']) < 0 & component_value[`i'] < 0 & component_value[`i' - 1] >= 0 // negative component, previous component positive, bar negative, previous bar positive
			replace white_out = . in `i' if (neg_color[`i' - 1] + component_value[`i']) < 0 & component_value[`i'] < 0 & component_value[`i' - 1] >= 0
			replace value2 = value2[`i' - 1] in `i' if (neg_color[`i' - 1] + component_value[`i']) < 0 & component_value[`i'] < 0 & component_value[`i' - 1] >= 0

			replace white_out = 0 in `i' if neg_color[`i' - 1] < 0 & component_value[`i'] > 0 & component_value[`i' - 1] < 0
			replace value2 = component_value + neg_color[`i' - 1] in `i' if neg_color[`i' - 1] < 0 & component_value[`i'] > 0 & component_value[`i' - 1] < 0 // positive component, previous component negative, previous bar was negative
			replace neg_color = neg_color[`i' - 1] in `i' if neg_color[`i' - 1] < 0 & component_value[`i'] > 0 & component_value[`i' - 1] < 0

		}

		local cost_start_bound = `cost_white_out_first' - 1
		local cost_end_bound = `cost_white_out_last' - 1

		forv i = `cost_start_bound'/`cost_end_bound' {
			replace white_out = value2[`i'-1]  in `i' if component_value >= 0
			replace value2 = value2[`i'-1] + component_value  in `i' if component_value>=0
				
			replace white_out = value2[`i'- 1]  + component_value in `i' if component_value<0 & component_value[`i'-1]>=0 
			replace value2 = value2[`i'-1] in `i' if component_value<0 & component_value[`i'-1]>=0 
				
			replace white_out = white_out[`i'- 1]  + component_value in `i' if component_value<0 & component_value[`i'-1]<0 
			replace value2 = white_out[`i'-1] in `i' if component_value<0 & component_value[`i'-1]<0 

			replace white_out = white_out[`i' - 1] in `i' if component_value > 0 & component_value[`i' - 1] < 0
			replace value2 = white_out[`i' - 1] + component_value in `i' if component_value > 0 & component_value[`i' - 1] < 0
		}
								
		local xaxis_total_wtp = `wtp_count'

				
		di "bar count is `bar_count'"
				
		* set y-axis label and figure name
		local ylab = "$ Per Subsidy"

		* set fig range (y-axis)
		local lb = 0
		local ub = component_value[`wtp_count']
		di "ub is `ub'"
		local int = 1
		local lb_f : di %02.1f `lb'
		local ub_f : di %02.1f `ub'
				
		* set y-coordinate for text/arrow
		
		if inlist("`program'", "ca_cnt_nm", "ca_cnt_ma", "ca_cnt_mgf", "rggi_nm", "rggi_ma", "rggi_mgf"){
			local y = (19/20)*abs(`ub')
		}

		else {
			local y = (19/20) * `ub'
		}
		else{
			local yscale "r(0 1.1)"
		}
		if "`manual'" == "yes" {
			insobs 1, after(`bar_count')
			replace component_type = "MVPF" if component_type == ""
			replace component_value = component_value[`wtp_count']/component_value[`bar_count'] if component_type == "MVPF"
		}
		local mvpf : di %5.4f component_value[`bar_count' + 1]
		if (`mvpf' == 1.0e+05) {
			local mvpf = "+Inf"
		}
		else if (`mvpf' == -1.0e+05) {set
			local mvpf = "-Inf"
		}
		
		local new_mode = "`mode'"
		if "`mode'" == "baseline"{
			local new_mode = "in-context"
		}
		
		local elas_message = "Using Elasticity of ${`program'_`mode'_ep}"
		if "${`program'_`mode'_ep}" == "" {
			local elas_message = ""
		}
		if "${value_profits}" == "yes"{
			local profits_message = "with profits"
		}
		else if "${value_profits}" == "no"{
			local profits_message = "without profits"
		}

		di in red "profits message is `profits_message'"
		local y_2 = 0.7 * `y'

		sum component_value if component_type == "WTP_USFut" & program == "`program'"
		local WTP_USFut = r(mean)

		sum component_value if component_type == "WTP_USPres" & program == "`program'"
		local WTP_USPres = r(mean)

		sum component_value if component_type == "cost" & program == "`program'"
		local cost = r(mean)

		local us_mvpf = round((`WTP_USFut' + `WTP_USPres') / `cost', 0.0001)

		di in red "y is `y'"
		di in red "program is `program'"
		
		*********************************************
		format component_value %9.3f

		tw ///
		(bar component_value xaxis if xaxis==`xaxis_total_wtp', barwidth(0.6)  lcolor(%0) color("181 184 191") mlabel(component_value) mlabc(black) mlabformat(%5.3f))  /// total  
		///
		(bar value2 xaxis if xaxis <= ${color_group1_`program'}, barwidth(0.6)  lcolor(white%0) color("`bar_light_orange'") mlabel(component_value) mlabc(black) mlabformat(%5.3f)) /// private WTP
		(bar neg_color xaxis if xaxis <= ${color_group1_`program'}, barwidth(0.6) lcolor(white%0) color("`bar_light_orange'")) /// private WTP, makes the whole thing go negative
		///
		(bar value2 xaxis if xaxis <= ${color_group2_`program'} & xaxis > ${color_group1_`program'}, barwidth(0.6)  lcolor(white%0) color("`bar_light_blue'") mlabel(component_value) mlabc(black) mlabformat(%5.3f)) /// society WTP
		(bar neg_color xaxis if xaxis <= ${color_group2_`program'} & xaxis > ${color_group1_`program'}, barwidth(0.6) lcolor(white%0) color("`bar_light_blue'")) /// society WTP, part of bar below zero
		///
		(bar value2 xaxis if xaxis <= ${color_group3_`program'} & xaxis > ${color_group2_`program'}, barwidth(0.6) lcolor(white%0) color("12 52 100") mlabel(component_value) mlabc(black) mlabformat(%5.3f)) /// cost curve
		(bar neg_color xaxis if xaxis <= ${color_group3_`program'} & xaxis > ${color_group2_`program'}, barwidth(0.6) lcolor(white%0) color("12 52 100") mlabc(black)) /// cost curve below zero
		///
		(bar value2 xaxis if xaxis <= ${color_group4_`program'} & xaxis > ${color_group3_`program'}, barwidth(0.6) lcolor(white%0) color("`bar_dark_orange'") mlabel(component_value) mlabc(black) mlabformat(%5.3f)) /// profits
		(bar neg_color xaxis if xaxis <= ${color_group4_`program'} & xaxis > ${color_group3_`program'}, barwidth(0.6) lcolor(white%0) color("`bar_dark_orange'") mlabc(black)) /// profits below zero
		///
		(bar value2 xaxis if xaxis <= ${color_group5_`program'} & xaxis > 2 + ${color_group4_`program'}, barwidth(0.6) lcolor(white%0) color("29 110 244") mlabel(component_value) mlabc(black)) /// cost components
		(bar neg_color xaxis if xaxis <= ${color_group5_`program'} & xaxis > 2 + ${color_group4_`program'}, barwidth(0.6) lcolor(white%0) color("29 110 244") mlabc(black) mlabformat(%5.3f)) /// cost components
		///
		(bar value2 xaxis if xaxis == `cost_position', barwidth(0.6) lcolor(white%0) color("52 76 116") mlabel(component_value) mlabc(black) mlabformat(%5.3f)) /// cost
		///
		(bar white_out xaxis if inrange(xaxis,`wtp_white_out_first',`wtp_white_out_last'), color(white) lcolor(white) lw(thick) barwidth(0.65)) ///
		(bar white_out xaxis if inrange(xaxis,`cost_white_out_first',`cost_white_out_last'), color(white) lcolor(white) lw(thick) barwidth(0.65)) ///
		///
		(pcarrowi `y' 1.0 `y' 1.3, color(black)) ///
		(function y =0, lcolor(white) lwidth(thin) lp(solid) range(0.3 `=6.5')), ///
		///
		text(`y' 3.2 "MVPF = `mvpf'", size(3.5)) ///
		legend(off) xtitle("") ytitle("") graphregion(color(white)) bgcolor(white) `ylabs' ///
		xlabel(${`program'_xlab}, labsize(vsmall) notick nogrid) ///
		ylabel(, nogrid format(%9.1f)) ///
		xsize(10)
		cap graph export "`output_path'/waterfall_`program'_`mode'.wmf", replace
		graph export "`output_path'/waterfall_`program'_`mode'.png", replace
	}
}

log close
