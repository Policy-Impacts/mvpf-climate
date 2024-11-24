


global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"
global indata "${working}/data/corrected/MLE"
global masterdata "${working}/data/uncorrected"

global policylist "${maindir}/code_files/"


local mode 4
local sample baseline
local threshold 5

forv mode = 2/4{
    foreach sample in baseline{
        foreach threshold in 3 5 10 15 50 {
            forv neg = 0/1{
                import delimited using "${masterdata}/policy_masterlist.csv", clear
                gsort t_stat 
                gen index = _n

                tempfile tomerge
                save `tomerge'
                import delimited using "${indata}/mode_`mode'/MLE_corrected_estimates_`sample'_sample_threshold_`threshold'neg`neg'.csv", clear 

                ren v1 corrected
                ren v2 uncorrected 
                gsort uncorrected 
                gen index = _n 
                merge 1:1 index using `tomerge', assert(3) nogen
                corr uncorrected t_stat 
                assert r(rho)>.99
                keep if `sample' ==1 

                local mode2 " xline(1.64)"
                local mode3 "xline(1.96)"
                local mode4 " xline(1.96)  xline(1.64)"

                local threshold3 "0(1)`threshold'"
                local threshold5 "0(1)`threshold'"
                local threshold10 "0(5)`threshold'"
                local threshold15 "0(5)`threshold'"
                local threshold50 "0(10)`threshold'"
                drop if uncorrected<0
                tw (lfit corrected uncorrected, lpattern(dash)) ///
                   (function y = x , range(-`threshold' `threshold')  lpattern(dash)) ///
                   (scatter corrected uncorrected, msize(small) mcolor(black)), ///
                   `mode`mode'' legend(order(1 "Line of Best Fit" 2 "45 degree line")  pos(4) ring(0) rows(2 )) ///
                   xtitle("Uncorrected t-stat") ytitle("Corrected t-stat") xscale(range(-`threshold' `threshold')) xlabel(`threshold`threshold'')
                
                graph export  "${working}/graphs/corrected_estimates_`sample'_`threshold'_`mode'_neg`neg'.wmf", replace

                keep if inrange(uncorrected,-3,3)
                tw (lfit corrected uncorrected, lpattern(dash)) ///
                   (function y = x , range(0 3)  lpattern(dash)) ///
                   (scatter corrected uncorrected, msize(small) mcolor(black)), ///
                   `mode`mode'' legend(order(1 "Line of Best Fit" 2 "45 degree line")  pos(4) ring(0) rows(2 )) ///
                   xtitle("Uncorrected t-stat") ytitle("Corrected t-stat") xscale(range(0 3)) xlabel(0(1)3)
                
                graph export  "${working}/graphs/corrected_estimates_`sample'_`threshold'_`mode'_3cap_neg`neg'.wmf", replace

            }
        }
    }
}