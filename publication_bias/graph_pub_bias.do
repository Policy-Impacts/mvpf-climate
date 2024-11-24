


global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"
global indata "${working}/data/corrected/MLE"
global policylist "${maindir}/code_files/"


local thresholds 3 5 10 15 50 
foreach sample in  baseline{
    foreach threshold of local thresholds{
        forv neg = 0/1{
            clear

            forv mode = 2/4{
                preserve
                    import delimited using "${indata}/mode_`mode'/MLE_model_parameters_`sample'_sample_threshold_`threshold'neg`neg'.csv", clear 
                    drop v1 v2 
                    keep in 1 
                    tempfile toappend 
                    save `toappend'
                restore 
                append using `toappend'
            }

            ren v* region*
            forv i=3/4{
                ren *`i' *`=`i'-2'
            }
            g spec = "1.64" in 1 
            replace spec = "1.96" in 2 
            replace spec = "mixed" in 3 

            local max 0 
            forv i = 1/2{
                qui su region`i'
                local newmax = `r(max)'
                local max = max(`newmax',`max')
            }

            tw (function y= (x<1.64)+ region1[1]*(x>1.64),range(-3 3 )) ///
               (function y= (x<1.96) + region1[2]*(x>1.96) ,range(-3 3 )) ///
               (function y= (x<1.64) + region1[3]*(x>1.64)*(x<1.96) + region2[3]*(x>1.96),range(-3 3 )), ///
               xscale(range(-3 3 )) xlabel(-3(1)3) legend(off) xtitle("T-statistic") ytitle("Estimated Publication Probability") ///
               yline(1, lstyle(dot)) text(`=1+`max'*.1' 0 "Pub. prob. of insig. result normalized to 1")

            graph export  "${working}/graphs/pub_bias_estimates_`sample'_`threshold'_neg`neg'.wmf", replace
        }
    }
}
