cap log close
clear all

ssc install filelist
ssc install missings
ssc install maptile
ssc install spmap 
ssc install gtools


*------
* Specs
*------
global rerun_data = "yes"
global bootstraps = "yes"
global pub_bias = "yes"

*------
* Paths
*------

/* I.1. User-Specific File Paths

Instructions: Use either your username ("`c(username)'") or a substring of
your working directory "`c(pwd)'" to identify your machine and set your
personal directories.

Example username (tested on Windows):
if ("`c(username)'" == "lukas") {...}
Example working directory (should also work on Mac):
if (substr("`c(pwd)'", 10, 5) == "lukas") {...}

User-specific paths are:
- user: path to user directory
- dropbox: path to all files
- github: path to all code

*/

*Replace the XX, YY, and XX with the relevant directories
if ("`c(username)'" == "beatrice") {
	global user = "/Users/beatrice"
	global dropbox = "${user}/Documents/GitHub/mvpf-climate/data"
	global github = "${user}/Documents/GitHub/mvpf-climate"
	global user_name = "Beatrice"
}

noi di "Set user path to: ${user}"
noi di "Set dropbox path to: ${dropbox}"
noi di "Set github path to: ${github}"


* Create list of all programs to run.
filelist, pattern("*.do") dir("${github}/policies/harmonized/") save(temp_filelist.txt) replace
preserve

	use temp_filelist.txt, clear
	
	levelsof(filename), local(file_loop)
	foreach program of local file_loop {
		
		local program_entry = substr("`program'", 1, strlen("`program'") - 3)
		local all_programs "`all_programs' `program_entry'" 
		
	}
	
	cap erase temp_filelist.txt
	
restore 

*------------------------------
* 0 - Prepare Data Inputs
*------------------------------

do "${github}/wrapper/clean_data.do"

*------------------------------
* 1 - All of the different runs
*------------------------------

if "${rerun_data}" == "yes" {

	*Main Run
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193" // nrun

	*Run using $76 SCC
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"76" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_76" // nrun
			
	*Run using $337 SCC
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"337" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_337" // nrun

		
		*Run using $1367 SCC
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"1367" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_1367" // nrun
		
		*Run with EU grid
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193_EU_grid" // nrun
	
	*Reset back to original
	global change_grid = ""
	global ev_grid = "US"
		
	*Run using in-context externalities
	do "${github}/wrapper/metafile.do" ///
		"baseline" ///
		"193" ///
		"yes" ///
		"no" ///
		"yes" ///
		"`all_programs'" ///
		0 /// reps
		"full_incontext"

	*Run without learning-by-doing
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"no" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_no_lbd" // nrun
		
	*Run including energy savings
	do "${github}/wrapper/metafile.do" ///
		"current" ///
		"193" ///
		"yes" ///
		"yes" ///
		"yes" ///
		"`all_programs'" /// programs to run
		0 /// reps    
		"full_current_savings"

	*Run without including profits
	do "${github}/wrapper/metafile.do" ///
		"current" ///
		"193" ///
		"yes" ///
		"no" ///
		"no" ///
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_noprofits" */
}
*---------------
* 2 - Bootstrapping
*------------------

if "${bootstraps}" == "yes" & "${rerun_data}" == "yes" {
	
	foreach scc in "193" "76" "337" {
		do "${github}/bootstrapping/bootstrapping" ///
			"current" /// mode
			`scc' /// scc
			"yes" /// value prorfits
			"no" /// value savings
			"yes" /// lbd
			1000 // reps
	}
}


*---------------------
* 3 - Publication Bias
*---------------------

if "${pub_bias}" == "yes" & "${rerun_data}" == "yes" {
    do "${github}/wrapper/metafile.do" ///
       "current" ///
       "193" /// SCC
       "yes" /// learning-by-doing
       "no" /// savings
       "yes" /// profits
       "`all_programs'" ///
       0 ///
       "full_current_193_pub_bias_and_lbd" ///
       "yes" // to run pub bias
}

*Create necessary globals if user did not run all the results
if "${rerun_data}" == "no" {

	*Since the without learning by doing spec is the fastest to run, run this spec to get the necessary globals
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"no" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"ct_solar" /// programs to run
		0 /// reps
		"full_current_no_lbd" // nrun
}

*---------------
* 4 - Robustness
*---------------

do "${github}/wrapper/robustness.do"

*-----------------------
* 5 - Figures and Tables
*-----------------------

do "${github}/wrapper/figures.do"

do "${github}/wrapper/tables.do"

do "${github}/wrapper/appendix_figures.do"

do "${github}/wrapper/appendix_tables.do"
