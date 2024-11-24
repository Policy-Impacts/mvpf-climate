/* 
PURPOSE: retrieve output from matlab program. merge back into files and resave the files from the command line so that the wrapper_ready sheet updates 
*/




global working "${code_files}/7_publication_bias"
global uncorrected "${working}/data/uncorrected"
global corrected "${working}/data/corrected"
global corrected_files "${code_files}/2a_causal_estimates_papers/corrected"
global uncorrected_files "${code_files}/2a_causal_estimates_papers/uncorrected_vJK" 
global policylist "${code_files}"


clear all 
* get list of policies
import excel using "${policylist}/policy_details_v3.xlsx", clear firstrow
tempfile programfile
save `programfile' 
* save to local
qui levelsof(program), local(programs) clean

* crossreference with the files that are prepped for publication bias correctioned
local filelist: dir "${uncorrected_files}" files "*.xlsx" , respectcase
foreach policy of local programs {
    local policy_list_xlsx `policy_list_xlsx' `policy'.xlsx // cut the JK eventually
}
* check all files in policy list were prepped 
local testlist: list policy_list_xlsx - filelist
assert `:word count `testlist''==0
* form the file final list for reading in


clear 

cd "${newinputs}"


* use masterlist as spine
import delimited using "${outdata}/policy_masterlist.csv", clear
keep if baseline  // only apply pub bias to baseline sample
gsort t_stat 
gen index = _n
tempfile tomerge
save `tomerge'
pause
import delimited using "${corrected}/output/MLE_corrected_estimates_RD_simple.csv", clear 
pause
ren v1 corrected
ren v2 uncorrected 
gsort uncorrected 
gen index = _n 
* matching on index because Matlab output is uninformative but is sorted by uncorrected t-stat
merge 1:1 index using `tomerge', assert(3)
* confirm the index matching works and the uncorrected t-stats line up (perhaps up to some rounding error)
corr uncorrected t_stat 
assert r(rho)>.99
tempfile dedupcorrected
save `dedupcorrected'
* now extend to deduplicated version
import delimited using "${uncorrected}/policy_masterlist_dedup.csv",    clear 
merge m:1 pe se using `dedupcorrected', assert(3) nogen // every PE/SE pair should have an exact match in the deduplicated version
* sub in new t_stats and PEs 

g t_stat_uncorrected = t_stat 
g pe_uncorrected = pe 
 
replace t_stat = t_stat * (corrected / uncorrected)
replace pe = pe * (corrected / uncorrected)

* masterfile of corrected estimates
save "${corrected}/corrected_masterfile.dta", replace
* get list of all programs with corrected estimates
qui levelsof(program), local(insample)

foreach word of local insample {
    local insample_final `insample_final' `word'.xlsx 
}
* copy over the original excel sheets
local _rc = 0 
cd "${uncorrected_files}"

foreach file of local insample_final {
    di "copying `file'"

    if "`c(os)'"=="MacOSX" {
        shell cp "`file'" "${corrected_files}/`file'" 
    } 
    else {
        shell copy "`file'" "${corrected_files}/`file'" /y

    }
    import excel using "${corrected_files}/`file'", sheet(raw_data) clear
    gen index = _n // allows us to sort at the end and make sure we get back to old order 
    cap rename A estimate 
    cap rename B pe
    cap rename C se 
    cap rename D t_stat
    cap rename H pub_bias
    cap rename I expected_sign
    destring  pe se t_stat pub_bias expected_sign, force replace // the force  kills the text 

    replace pub_bias = 0 if  strpos(estimate,"markup") + strpos(estimate,"passthrough")>0  
    * for merging
    g program = "`file'" if !mi(estimate)
    replace program = subinstr(program,".xlsx","",.)
    gen id = program + estimate if !mi(estimate)
    ren (pe t_stat) (pe_old t_stat_old)
    merge m:1 id using  "${corrected}/corrected_masterfile.dta",  assert( 1 2 3) keep (1 3) update replace keepusing(pe t_stat pe_uncorrected t_stat_uncorrected)
    * confirm no funny business happened when originally aggregating
    assert abs(1 - pe_old / pe_uncorrected) < 1e-4 if _merge == 3
    * confirm that everything that was supposed to get bias corrected did
    assert _merge == 3 if pub_bias == 1 & !mi(se)
    replace t_stat_old = t_stat if pub_bias == 1  & !mi(t_stat_old)
    replace pe_old = pe if pub_bias == 1
    drop pe t_stat *_uncorrected
    ren *_old *
    gsort index 
    drop _merge id index program
    export excel using "${corrected_files}/`file'", sheet(raw_data, modify) 

}
* resave the new excel sheets so that the formulas carry through
cd "${working}/code/"
if "`c(os)'"=="MacOSX" {
    cd "${corrected_files}"
    foreach file of local insample_final {
        shell osascript resave_excel.scpt `file'
        di in red "file is `file'"
        pause
    }
}
else {
    shell copy "resave_excel.ps1" "${corrected_data}"
    cd "${corrected_files}"
    foreach file of local insample_final {
        shell powershell -File resave_excel.ps1 `file' 
    }
}

global programs_to_run = subinstr("`insample_final'",".xlsx","",.)

