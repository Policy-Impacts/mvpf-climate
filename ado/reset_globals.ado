*-----------------------------------------------------------------------
* Check if Timepaths Should Re-run
*-----------------------------------------------------------------------
cap prog drop reset_globals
prog def reset_globals, rclass

syntax [anything], /// yes or no 
		[scc_reset(real 193)] ///
		
*Temporarily storing paths as locals
scalar dropbox = "${dropbox}"
scalar github = "${github}"
scalar user_name = "${user_name}"
scalar mac_wolfram_path = "${mac_wolfram_path}"
scalar rerun_data = "${rerun_data}"
scalar bootstraps = "${bootstraps}"
scalar pub_bias = "${pub_bias}"
scalar scc_reset = `scc_reset'

*Dropping all globals
macro drop _all

*Resaving all paths as globals
global dropbox = scalar(dropbox)
global github = scalar(github)
global user_name = scalar(user_name)
global mac_wolfram_path = scalar(mac_wolfram_path)
global rerun_data = scalar(rerun_data)
global bootstraps = scalar(bootstraps)
global pub_bias = scalar(pub_bias)
local scc_reset = scalar(scc_reset)

*Preparing inputs
do "${github}/wrapper/clean_data.do"

*Reset Globals by running one program
do "${github}/wrapper/metafile.do" ///
	"current" /// 2020
	"`scc_reset'" /// SCC
	"yes" /// learning-by-doing
	"no" /// savings
	"yes" /// profits
	"retrofit_res" /// programs to run
	0 /// reps
	"resetting_globals" // nrun

		
end
