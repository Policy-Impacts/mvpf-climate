/* 
PURPOSE: retrieve files for pub bias correcting, clean , combine, and run the matlab program
*/


**** GLOBALS FOR FILEPATHS*****

global pubbiascode "${github}/publication_bias"
global outdata "${code_files}/7_publication_bias/data/uncorrected"
global corrected_data "${code_files}/2a_causal_estimates_papers/corrected"
global inputs "${code_files}/2a_causal_estimates_papers/uncorrected_vJK" // hard coded for now but perhaps change after discussing with team
global policylist "${code_files}/" 

*** Colors
local bar_blue = "36 114 237"  
local light_gray = "181 184 191"

*** USER SPECIFIED OPTIONS*** 
local sample baseline
local width_size `1' // for RD /pub bias estimation
local cutoff `2' // for RD 
* for Mac Users: Specify Matlab Options
local matlabpre `3'
local matlabversion `4'
if "`c(os)'" == "MacOSX" {
    global matlabpath "`matlabpre'/MATLAB_`matlabversion'.app/bin/"
}
else {
    global matlabpath
}
**#1. Get files
* get list of policies
import excel using "${policylist}/policy_details_v3.xlsx", clear firstrow

tempfile programfile
save `programfile' 
* save list of policies to local
levelsof(program), local(programs) clean

di in red "inputs is ${inputs}"

* crossreference with input files and check that all are available
di in red "inputs is $inputs"

local filelist: dir "$inputs" files "*.xlsx" , respectcase
foreach policy of local programs {
    local policy_list_xlsx `policy_list_xlsx' `policy'.xlsx // 
}

di in red "policy list is `policy_list_xlsx'"
di in red "file list is " `filelist'

* figure out which files are not prepped for publication_bias but are in the masterlist. These should correspond to those missing SEs  
local testlist: list policy_list_xlsx - filelist
assert `:word count `testlist''==0


* form the file final list for reading in

clear 

**#2. Prep the individual files
foreach file of local filelist {
    di "`file'"
    * uscale_solar is in the folder for robustness purposes but shouldn't be included in pub bias
    if "`file'" == "uscale_solar.xlsx"{
        continue
    }
    preserve
        import excel using "${inputs}/`file'", clear sheet(raw_data) firstrow // use sheet w raw data subject to pub. bias 
        qui ds *, v(32)
        local vars `r(varlist)'
        cap destring B, force replace
        cap destring pe, force replace 
        * some cleaning to deal with how stata reads in excel for the various files
        cap keep if "`:word 1 of `vars''"=="estimate" | !mi(B) // we want to keep only rows with point estimates + the top row with names

        local renamevars estimate pe se t_stat p_value ci_lo ci_hi pub_bias expected_sign source notes

        forv i=1/`:word count `renamevars'' {
            cap ren `:word `i' of `vars'' `:word `i' of `renamevars'' 
        }


        cap keep if !mi(estimate)| !mi(pe) // cap is to deal with cases where there are strings
        destring se t_stat p_value ci_lo ci_hi pub_bias expected_sign ,  replace
        cap destring notes, force replace
        cap destring M, force replace
        cap drop L
        g program = "`file'" // for ID
        tempfile toappend
        save `toappend'
    restore 
    append using `toappend' // making one big file with all the sheets
}
* destring numeric variables
destring pe se t_stat p_value ci_lo ci_hi , replace
destring pub_bias expected_sign, replace force
replace program = subinstr(program,".xlsx","",.)
* merge back with the list of policies 
merge m:1 program using `programfile' 

drop if mi(t_stat) & (mi(se)|se==0) & mi(p_value) & mi(ci_lo) & mi(ci_hi) // these are the ones for which we definitely can't pub bias

** Fill in missing t-stats 
* back out t-stats from p-values 
replace t_stat = sign(pe)*invnormal(1-(p_value/2)) if mi(t_stat) & (mi(se)|se==0) & mi(ci_hi) & mi(ci_lo)
* back out SEs from CIs 
replace se = (ci_hi-ci_lo)/(1.96*2) if mi(t_stat) & (mi(se)|se==0) & mi(p_value) & program !="hybrid_de"
replace se = (ci_hi-ci_lo)/(1.64*2) if mi(t_stat) & (mi(se)|se==0) & mi(p_value) & program =="hybrid_de" // this paper reports a 90% CI
replace t_stat = pe/se if mi(t_stat)
assert !mi(t_stat)
replace se = abs(pe/t_stat) if mi(se) 
encode program, gen(clusterid) // for pub bias standard error computation. TO CHECK: how does this interact with dedup.


*** form indicators for different sample***
foreach var of varlist international extended regulation { 
    replace `var'  = 0 if mi(`var')
    assert inlist(`var',0,1)
}
g baseline =  international + extended + regulation == 0 
assert inlist(baseline,0,1)
foreach var of varlist international extended regulation { 
    replace `var'  = `var'  + baseline
}
g extended_international = extended | international
g extended_regulation = extended | regulation
g international_regulation = international | regulation 
g complete_sample = 1  

* keep only necessary variables
keep pe se t_stat  estimate program clusterid baseline extended international regulation extended_international extended_regulation international_regulation complete_sample p_value ci_lo ci_hi pub_bias expected_sign
replace program = subinstr(program,".xlsx","_",.)
 
* restrict to sample
keep if `sample' & pub_bias
* do everything in abs value space
g abs_t_stat = abs(t_stat)
* drop markups and passthroughs from pub bias sample 
drop if strpos(estimate,"markup") + strpos(estimate,"passthrough")>0 

gen id = program + estimate

cd "$pubbiascode/code_and_data_2019/Matlab"
* save with duplicates
export delimited using   "${outdata}/policy_masterlist_dedup.csv", replace  nolab
duplicates drop pe se , force
*save deduplicated
export delimited using   "${outdata}/policy_masterlist.csv", replace  nolab
preserve
    *** MAKE RD PLOT AND GET ESTIMATE OF PUB BIAS *** 
    * loop over bandwidths 
    * create cells of nearby t-stats
    import delimited using   "${outdata}/policy_masterlist.csv", clear

    qui gen group = ceil(abs_t_stat/`width_size')
    * confirm that 1.96 is a cutpoint with whatever bin width you use -- there's no bin that contains both observations above and below 1.96
    qui su group if abs_t_stat>1.96 
    local minmax = r(min)
    qui su group if abs_t_stat<1.96
    local maxmin = r(max)
    assert `maxmin'<`minmax'
    * generate an indicator for being above the cutoff
    g above_threshold = group>`maxmin' & ~mi(group)
    * collapse the dataset into counts with mean t-stat within group as the running variable
    qui levelsof(abs_t_stat), local(abs_t)
    gcollapse (count) n_pub = abs_t_stat  (first) above_threshold = above_threshold, by(group)
    * generate mean
    g mean_t = (group-1)*(`width_size') + `width_size'/2
    qui su n_pub if group == `maxmin'
    local mean1 = r(mean)
    qui su n_pub if group == `minmax' 
    local mean2 = r(mean)
  
restore 
gen estimated_bias = `mean2'/`mean1'
*resave with the pub bias estimate
export delimited using   "${outdata}/policy_masterlist.csv", replace  nolab

* run matlab 
shell ${matlabpath}matlab -nodesktop -nosplash -nodisplay -r "selection_welfare_simple('${pubbiascode}','${code_files}/7_publication_bias', 5, 3)"

