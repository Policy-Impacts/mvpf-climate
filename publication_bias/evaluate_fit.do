

global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"
global indata "${dropbox_me}/Regulation/publication_bias/data/uncorrected"
global corrected "${dropbox_me}/Regulation/publication_bias/data/corrected/MLE"

global masterdata "${working}/data/uncorrected"
global policylist "${maindir}/code_files/"
ssc install distplot

local cutoff2 = 1.64 
local cutoff3 = 1.96
* import data to get CDF
forv mode = 2/3 {
   foreach thresh in 5 6 7 8 9 10 {
      qui {
         import delimited using   "${indata}/policy_masterlist_symm.csv", clear
         gsort t_stat
         replace t_stat = abs(t_stat)
         distplot t_stat if t_stat<5
         twstairstep t_cdf
         keep if abs(t_stat)<`thresh'
         gegen cdf = rank(t_stat)
         qui su cdf 
         replace cdf = cdf/(_N)

         keep cdf t_stat
         local count_total = _N
         g spec = "actual"
         tempfile toappend
         save `toappend'


         * get pub bias CDF 
         import delimited "${corrected}/mode_`mode'/MLE_model_parameters_baseline_symmetric_sample_threshold_`thresh'neg1", clear
         su v1 in 1 
         local true_mean = r(mean)
         su v2 in 1 
         local true_sd = r(mean)
         local overall_sd = sqrt(`true_sd'^2+1)
         su v3 in 1 
         local pub_bias = r(mean)
         if `mode' == 4 {
            su v4 in 1 
            local pub_bias2 = r(mean)
         } 
         local count_to_make = 10000 // ceil(`count_total'/(2*normal(-abs((`cutoff`mode''-`true_mean')/`overall_sd')) + `pub_bias'*(1-2*normal(-abs((`cutoff`mode''-`true_mean')/`overall_sd')))))
         clear 
         set obs `count_to_make'

         g theta = rnormal(`true_mean',`true_sd')
         gen t_stat = .
         forv i=1/`=_N' {
            qui su theta in `i'
            local mean = r(mean)
            replace t_stat = rnormal(`mean',1) in `i'
         }

         if `mode'==4 {
            sample `=100*`pub_bias'' if   abs(t_stat)<1.96 & abs(t_stat)>1.64 
            sample `=100*`pub_bias2'' if abs(t_stat)<1.64

         }
         else {
            sample `=100*`pub_bias'' if abs(t_stat)<`cutoff`mode''
            sample `=100*`pub_bias'' if abs(t_stat)<`cutoff`mode''
         }
         gsort t_stat
         keep if abs(t_stat)<`thresh'
         gegen cdf = rank(t_stat)
         qui su cdf 
         replace cdf = cdf/(_N)
         keep cdf t_stat
         g spec = "simulated"

         append using `toappend'
         su t_stat 
         local diff = r(max)-r(min)
         local startcount = _N
         set obs `=1000+`startcount'+1'
         g smoothing_grid = r(min)+`diff'*(_n-`startcount'-1)/(1000) if _n>`startcount'

         tw (lpoly cdf t_stat if spec == "simulated") (lpoly cdf t_stat if spec == "actual") ///
            (scatter cdf t_stat if spec == "simulated") (scatter cdf t_stat if spec == "actual") , legend(order (3 "Simulated" 4 "Actual"))
            
         graph export "${working}/graphs/CDF_comparison_mode`mode'_thresh`thresh'.pdf", replace
         lpoly cdf t_stat if spec == "simulated", at(smoothing_grid) gen(smoothed_sim)  nograph
         lpoly cdf t_stat if spec == "actual", at(smoothing_grid) gen(smoothed_act)  nograph

         *tw (scatter smoothed_sim smoothing_grid) (scatter smoothed_act smoothing_grid)
         gen cdf_diff = abs(smoothed_sim-smoothed_act)
         integ smoothed_act smoothing_grid

         integ cdf_diff smoothing_grid
      }
      di "integral with threshold `thresh' and mode `mode' is `r(integral)'"
   }
}