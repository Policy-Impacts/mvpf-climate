/***************************************************************************
 *              METAFILE FOR MVPF ENVIRONMENTAL PROJECT                    *
 ***************************************************************************
    This file produces all MVPF estimates.
    It requires not only this code repository, but also the separate sets of
    policy-specific input files found in Dropbox. The GitHub READ ME file 
    provides more detail on the required file structure.
    
    To get started, 3 user-specific file paths must be set (cf. I.1. below).
****************************************************************************/
version 18
cap log close
clear all

********** Globals that come from masterfile *********

// List of modes or "all" 
global modes_to_run "`1'"
// Social cost of carbon in 2020
global scc = "`2'"
if "`2'" == "" global scc 193
// Learning by doing?
global lbd = "`3'"
// Value savings?
global value_savings = "`4'"
// Value profits?
global value_profits = "`5'"
// Which programs to run?
// List of programs or "all_programs"
global programs_to_run "`6'"
// No. of bootstrap replications
global reps `7'

// Name of this run/configuration (for output folder)
global nrun = "`8'"
// For running publication bias
if "`9'" == "yes"{
    global correction_modes = "uncorrected_vJK corrected"
    global programs_pb_exclude "bev_testing hev_testing hev_usa hybrid_de wind_testing_2" 
}
else{
    global correction_modes = "uncorrected_vJK"
}

// For changing the grid
if strpos("${nrun}" , "CA_grid") {
    global change_grid = "CA"
}

if strpos("${nrun}" , "EU_grid") {
    global change_grid = "EU"
}

if strpos("${nrun}" , "MI_grid") {
    global change_grid = "MI"
}

if strpos("${nrun}" , "clean_grid") {
    global change_grid = "clean"
}

if !strpos("${nrun}" , "_grid") {
    global change_grid = ""
}


*****************************************************


global usets = 1
global use_causal_draws = "redraw"
global use_bootstrap_draws = "redraw"
// Set seed
global welfare_seed 1280 // Massachusetts Avenue

// If you want to add/replace the results of an old run
// Set append to yes and put stamp of previous run in "original_stamp"
global append = "no"
global original_stamp = ""
// Set preferences - takes values "yes" or "no"
global make_waterfall = "no" // make waterfall chart?

* Toggles that only need to change for robustness, changes handled in run_program.ado *

// Select hybrid counterfactual: muehl, new_avg, new_car, or fleet_avg
global hev_cf muehl // muehl
// Select BEV counterfactual: 
global bev_cf clean_car // clean car
// Select EV VMT assumpption: car or avg
global ev_VMT_assumption car
// Including rebound effects?
global rebound yes
// EVs Drive X% as Many Miles as the Avg. Car / LDV
global EV_VMT_car_adjustment = 0.61544408 // From Zhao et al. 2023
global EV_VMT_avg_adjustment = 0.63983246 // From Zhao et al. 2023; weighted average.
// Should the numbers in Latex be updated?
global latex = "no"

if "${VMT_change_robustness}" == "yes" {
	global EV_VMT_car_adjustment = 1
}

***************************************************************************************


/* I.2. Automatic Settings */
// Set Figure preferences (in capture bc. no access for USC peeps?)
capture {
    set scheme "${github}/opp_insights_fb"
}
global tc = "gs4"

// What year do we want the current MVPF to be harmonized for?
global current_year = 2020
global today_year 2020
global dollar_year 2020


/* I.2. User-Invariant File Paths */

// timestamp
local date : display %tdCY-N-D date(c(current_date), "DMY")
local time : display %tcHH-MM-SS clock(c(current_time), "hms")
global timestamp = "`date'_`time'"
noi di "Timestamp of this run: ${timestamp}"
if $usets == 1 {
    global stamp = "${timestamp}__${nrun}"
}
else {
    global stamp = "${nrun}"
} 


global code_files                = "${dropbox}"
global assumptions               = "${code_files}/1_assumptions"
global user_specific_assumptions = "${assumptions}/user_specific_assumptions"
global bootstrap_folder          = "${code_files}/3_bootstrap_draws"
global results                   = "${code_files}/4_results/${stamp}"
global graphs                    = "${code_files}/5_graphs/${stamp}"
global tables 					 = "${code_files}/6_tables/${stamp}"
global pub_bias                  = "${code_files}/7_pub_bias"

global output_tab             = "${code_files}/6_tables"
global output_fig             = "${code_files}/5_graphs"


global program_folder            = "${github}/policies/harmonized"
global set_types 				 = "${github}/policies/set_types"
global calculation_files 		 = "${github}/calculations"
global ado_files                 = "${github}/ado"
global overleaf                  = "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy"

* Set main data sheets: defualt assumptions and policy-specific assumptions/data.
global default_assumptions		= "${assumptions}/default_assumptions_toggles_vMAIN.xlsx"
global policy_assumptions		= "${assumptions}/policy_category_assumptions_MASTER.xlsx"


// Log
log using "${code_files}/0_log/log_metafile_${stamp}", text replace
// create new folders
cap mkdir "${results}"


*-----------------------------------------------------------------------
* 0 - Define Macros.
*-----------------------------------------------------------------------

foreach correction_mode of global correction_modes {
    global correction_mode `correction_mode'
    global nrun = "${nrun}_`correction_mode'"
    global causal_ests = "${code_files}/2a_causal_estimates_papers/`correction_mode'"
    global causal_draws = "${code_files}/2b_causal_estimates_draws/`correction_mode'"

    if $usets == 1 {
        global stamp = "${timestamp}__${nrun}"
    }
    else {
        global stamp = "${nrun}"
    }
    // Set results to use
    if "$use_causal_draws" == "redraw" {
        global redraw_causal_estimates = "yes"
        global ts_causal_draws = "${stamp}"
        noi di "Create new causal draws: ${ts_causal_draws}"
        cap mkdir "${causal_draws}/${ts_causal_draws}"
    }
    else if "$use_causal_draws" == "latest" {
        global redraw_causal_estimates = "no"
        local folders : dir "${causal_draws}" dirs "*"
        global ts_causal_draws : word `:list sizeof folders' of `folders'
        noi di "Using latest causal draws: `ts_causal_draws'."
    }
    else {
        global redraw_causal_estimates = "no"
        global ts_causal_draws = "$use_causal_draws"
        noi di "Using specific causal draws: `ts_causal_draws'."
    }
    /* Note: There is no "redraw bootstrap draws" option at the moment. */
    if "$use_bootstrap_draws" == "redraw" {
        global redraw_bootstrap_estimates = "yes"
        global ts_bootstrap_draws = "${stamp}"
        noi di "Create new bootstrap draws: ${ts_bootstrap_draws}"
        cap mkdir "${bootstrap_folder}/${ts_bootstrap_draws}"
    }
    else if "$use_bootstrap_draws" == "latest" {
        global redraw_bootstrap_estimates = "no"
        local folders : dir "${bootstrap_folder}" dirs "*"
        global ts_bootstrap_draws : word `:list sizeof folders' of `folders'
        noi di "Using latest bootstrap draws: `ts_bootstrap_draws'."
    }
    else {
        global redraw_bootstrap_estimates = "no"
        global ts_bootstrap_draws = "$use_bootstrap_draws"
        noi di "Using specific bootstrap draws: `ts_bootstrap_draws'."
    }

    global bootstrap_files = "${bootstrap_folder}/${ts_bootstrap_draws}"
    global append_files = "${bootstrap_files}/all_policies_collated"
    cap mkdir "${bootstrap_files}"
    cap mkdir "${append_files}"


    local programs_to_run $programs_to_run
    local programs_pb_exclude $programs_pb_exclude
    if "`correction_mode'" == "corrected" global programs_to_run: list programs_to_run - programs_pb_exclude

    if "`correction_mode'" == "corrected"{
        di in red "the list of programs is ${programs_to_run}"
    }

    *-----------------------------------------------------------------------
    * 0 - Macros
    *-----------------------------------------------------------------------
    noi di "SECTION 0: MACROS"
    qui do "${github}/wrapper/macros.do" "yes"

    *-----------------------------------------------------------------------
    * 1 - Prepare causal estimates
    *-----------------------------------------------------------------------
    noi di "SECTION 1: PREPARE CAUSAL ESTIMATES"
    * 1 - prepare bootstrap draws of uncorrected causal estimates
    noi do "${github}/wrapper/prepare_causal_estimates.do" ///
           "$programs_to_run" // programs to run / all_programs

    *-----------------------------------------------------------------------
    * 2 - Estimate MVPFs and other statistics, bootstrap, and loop through global assumptions
    *-----------------------------------------------------------------------

    noi di "SECTION 2: ESTIMATION & BOOTSTRAPPING"
        
    do "${github}/wrapper/bootstrap_wrapper.do" ///
       "${programs_to_run}" /// programs to run
       "${modes_to_run}" // all_modes // baseline // modes to run

    if "${make_waterfall}" == "yes"{
        do "${github}/wrapper/waterfalls.do" ///
           "${programs_to_run}" /// programs to run
           "${modes_to_run}" // all_modes // baseline // modes to run
    }

    *-----------------------------------------------------------------------
    * 3 - Compile results.
    *-----------------------------------------------------------------------
    noi di "SECTION 3: COMPILE ESTIMATES & INFERENCE"
    clear

    di in red "compile programs is ${compile_programs}"
    di in red "compile loop modes is ${compile_loop_modes}"
    foreach program of global compile_programs {

        di "${compile_loop_modes}"		
        foreach mode of global compile_loop_modes {
            append using "${bootstrap_files}/`program'_`mode'_estimates_${replications}_replications"	
        }

    }
    save "${results}/compiled_results_all_`correction_mode'", replace 


    /*-----------------------------------------------------------------------
    * 4 - Append with Previous Run
    *-----------------------------------------------------------------------*/

    if "${append}" == "yes" {
        
        use "${code_files}/4_results/${original_stamp}/compiled_results_all_`correction_mode'", clear 

        foreach mode of global compile_loop_modes {
            foreach program of global compile_programs {
                drop if program == "`program'" & assumptions == "`mode'"	
        
            if "`mode'" == "baseline" {
                append using "${bootstrap_files}/`program'_`mode'_estimates_${replications}_replications"
                }
            else {
                append using "${bootstrap_files}/`program'_`mode'_estimates_${replications}_replications"	
                }	
            }
        }
        
        save "${code_files}/4_results/${original_stamp}/compiled_results_all_`correction_mode'", replace
    }



    *run publication bias metafile
    if "`9'" == "yes"{
        if "`correction_mode'" == "uncorrected_vJK" do "${github}/publication_bias/pub_bias_wrapper"
    }

}

noi di "== END OF SCRIPT =="
beep

