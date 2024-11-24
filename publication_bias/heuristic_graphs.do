global working "${code_files}/7_publication_bias"
global indata "${working}/data/corrected/MLE"
global masterdata "${working}/data/uncorrected"

global policylist "${code_files}/"
local bar_blue = "36 114 237"  
if "`c(os)'"=="MacOSX" local suf svg
else local suf wmf

local pe_threshold `1'
local t_threshold `2'
local cutoff `3'
local width_size `4'

import delimited using "${masterdata}/policy_masterlist.csv", clear


assert !mi(pe)
count if abs(pe) > `pe_threshold' 
local total_above = r(N)
count if abs(pe) > `pe_threshold' & abs(pe / se) > 1.96
local 5pct = r(N)

count if abs(pe) > `pe_threshold'  & abs(pe / se) > 1.64
local 10pct = r(N)

g t = abs(pe / se)
qui su t if abs(pe)>`pe_threshold'
di "`r(N)' estimates will be dropped"

qui su t if abs(pe)>`pe_threshold' & t>1.96
di "of which `r(N)' estimates are significant"

keep if  abs(pe)<`pe_threshold' 

tw (scatter  se pe, mcolor("`bar_blue'")) /// 
   (function y = 1 / 1.96 * x, range(0 `pe_threshold') lcolor(black) lpattern(dash)) ///
   (function y = -1 / 1.96 * x, range(-`pe_threshold'  0) lcolor(black) lpattern(dash)), /// 
   legend(off) ///   
   text(`=`pe_threshold'*.5*1/1.96+.5' `=`pe_threshold'*.5' "Slope=1/1.96") ///
   text(`=`pe_threshold'*.5*1/1.96+.5' -`=`pe_threshold'*.5' "Slope=-1/1.96") ///  
   yscale(range(0 3)) ///
   ylabel(0(1)3, nogrid) ///
   xlabel( , nogrid) ///
   xtitle(Point Estimate) /// 
   ytitle (Standard Error)

 
graph export "${code_files}/5_graphs/figures_appendix/funnel_plot_threshold_`pe_threshold'_5pct_sig.`suf'", replace
graph export "${code_files}/5_graphs/figures_appendix/funnel_plot_threshold_`pe_threshold'_5pct_sig.pdf", replace

********** HISTOGRAM **********
* read in data set with uncorrected t-stats
qui import delimited using "${masterdata}/policy_masterlist.csv", clear
qui replace t_stat = abs(t_stat) // do things in absolute values to have one cutoff

* create cells of nearby t-stats
qui gen group = ceil(t_stat/`width_size')
* confirm that 1.96 is a cutpoint with whatever bin width you use -- there's no bin that contains both observations above and below 1.96
su group if t_stat>1.96 
local minmax = r(min)
su group if t_stat<1.96
local maxmin = r(max)
if `width_size'<.5 assert `maxmin'<`minmax'
* generate an indicator for being above the cutoff
g above_threshold = group>`maxmin'
* collapse the dataset into counts with mean t-stat within group as the running variable
gcollapse (count) n_pub = t_stat (mean) mean_t = t_stat (first) above_threshold = above_threshold, by(group)
* generate higher-order polynomial terms
replace mean_t = (group-1)*(`width_size') + `width_size'/2
qui su n_pub if group ==`minmax'
local mean1 = r(mean)
qui su n_pub if group ==`maxmin'
local mean2 = r(mean)

su n_pub if !inrange(mean_t,0,`cutoff') 
di r(N)*r(mean)
di _N

tw (bar n_pub mean_t if inrange(mean_t,0,`cutoff'), barw(`width_sizes') col("`bar_blue'")), ///
   xline(1.96, lcolor(black) lpattern(dash)) ///
   xtitle("t-stat (Abs. value, averaged within groups of `width_size')") ///
   ytitle("Number of Published Studies") ///
   ylabel( , nogrid) ///
   xlabel( , nogrid) ///
   legend(off) /// 
   text(25 1.95 "Implied pub. bias: `: di %4.3f `=`mean1'/`mean2'''", placement(west))
*** get p-value***
keep if  group ==`maxmin' | group == `minmax'
* get pooled prob after normalizing N to number published sig 
su n_pub if group == `minmax'
local N = r(mean)
su n_pub if group == `maxmin'
local N_insig = r(mean)
local p_pooled =  (`N_insig' + `N')/(2*`N')
di `p_pooled'
local test_statistic = (`N'-`N_insig')/(sqrt((`N'+`N_insig')*(1-`p_pooled')))
di `test_statistic'
di "p_value = `=(1-normal(`test_statistic'))/2'"
***
graph export "${code_files}/5_graphs/figures_appendix/RD_thresh.`suf'", replace
graph export "${code_files}/5_graphs/figures_appendix/RD_thresh.pdf", replace

