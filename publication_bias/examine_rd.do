* PATHS 
global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"
global indata "${dropbox_me}/Regulation/publication_bias/data/uncorrected"
global masterdata "${working}/data/uncorrected"
global policylist "${maindir}/code_files/"
*** GRAPH COLORS*** 
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_orange = "237 170 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"
*****

***OPTIONS ***
local cutoff 5 // up to what abs value of the t-stat to visualize?
local width_size .98 // how big to make the bins? best if a divisor of 1.96




* read in data set with uncorrected t-stats
qui import delimited using   "${indata}/policy_masterlist_symm.csv", clear
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

su n_pub   if !inrange(mean_t,0,`cutoff') 
di r(N)*r(mean)
di _N


tw (bar n_pub mean_t  if inrange(mean_t,0,`cutoff') ,barw(`width_sizes') col("`bar_blue'")), ///
  xline(1.96, lcolor(black) lpattern(dash)) xtitle("t-stat (Abs. value, averaged within groups of `width_size')") ytitle("Number of Published Studies") legend(off) /// 
  text(25 1.97 "Implied pub. bias: `: di %4.3f `=`mean1'/`mean2'''", placement(east))
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

graph export "${working}/graphs/RD_thresh`cutoff'.pdf", replace
graph export "${dropbox_me}/Apps/Overleaf/MVPF Climate Policy/Figures/Publication_Bias/RD_thresh`cutoff'.pdf", replace

qui import delimited using   "${outdata}/policy_masterlist_symm.csv", clear
gen rd_pub_bias = `mean1'/`mean2'
qui export delimited using   "${outdata}/policy_masterlist_symm_matlab_ready.csv", replace

 
e



*** graveyard *** 

/*
local width_sizes .49 //  .02 .03 .04 .14 .28
foreach width_size of local width_sizes {
* read in data set with uncorrected t-stats
qui import delimited using   "${outdata}/policy_masterlist_symm.csv", clear
qui replace t_stat = abs(t_stat) // do things in absolute values to have one cutoff
* loop over bandwidths 

* create cells of nearby t-stats
qui gen group = ceil(t_stat/`width_size')
* confirm that 1.96 is a cutpoint with whatever bin width you use -- there's no bin that contains both observations above and below 1.96
qui su group if t_stat>1.96 
local minmax = r(min)
qui su group if t_stat<1.96
local maxmin = r(max)
if `width_size'<.5 assert `maxmin'<`minmax'
* generate an indicator for being above the cutoff
g above_threshold = group>`maxmin'
* collapse the dataset into counts with mean t-stat within group as the running variable
gcollapse (count) n_pub = t_stat (mean) mean_t = t_stat (first) above_threshold = above_threshold, by(group)
* generate higher-order polynomial terms
g mean_t_sq = mean_t^2

*PLOT 

*loop over different cutoffs for t-values to reduce influence of outliers 

foreach cutoff in 3  5 10 15 {
* spec 1: OLS 
qui reg n_pub c.mean_t#i.above_threshold  above_threshold  if inrange(mean_t,0,`cutoff'), r
*predicted # of counts : limit from above at the threshold
local predicted_unpub_at_thresh = _b[_cons] + 1.96*_b[0b.above_threshold#c.mean_t]
*predicted # of counts : limit from below at the threshold
local predicted_published_at_thresh = _b[_cons] + 1.96*_b[1.above_threshold#c.mean_t]+_b[above_threshold]
* the ratio is the ratio of the expected # of pub'd studies but if publication is binomial with different probabilities for sig. and insig. and the # of trials is the same (because underlying distribution of the t-stats is smooth and we're taking limits) this also identifies the ratio of the publication probabilities since E[Bin(n,p)=np]
local expectation_ratio = `predicted_published_at_thresh'/`predicted_unpub_at_thresh'
tw (bar n_pub mean_t  if inrange(mean_t,0,`cutoff') , barw(`width_size')) ///
  (function y=  _b[_cons] + x*_b[0b.above_threshold#c.mean_t]*(x<1.96) /// 
  + x*_b[1.above_threshold#c.mean_t]*(x>=1.96) + _b[above_threshold]*(x>=1.96), range(0 `cutoff')) , ///
  xline(1.96) xtitle("T_stat (averaged within groups of `width_size')") ytitle("Number of Published Studies") legend(off)


graph export "${working}/graphs/RD_linear_thresh`cutoff'.pdf", replace

di " ratio of pub. probabilities with bin width `width_size' and cutoff `cutoff', OLS: `expectation_ratio'"

* spec 2: OLS with quadratic
qui reg n_pub  c.mean_t#i.above_threshold  c.mean_t_sq#i.above_threshold  above_threshold  if inrange(mean_t,0,`cutoff'), r
local predicted_unpub_at_thresh = _b[_cons] + 1.96*_b[0b.above_threshold#c.mean_t] + 1.96^2*_b[0b.above_threshold#c.mean_t_sq]
local predicted_published_at_thresh = _b[_cons] + 1.96*_b[1.above_threshold#c.mean_t] + 1.96^2*_b[1.above_threshold#c.mean_t_sq] + _b[above_threshold]
local expectation_ratio = `predicted_published_at_thresh'/`predicted_unpub_at_thresh'
tw (bar n_pub mean_t  if inrange(mean_t,0,`cutoff') , barw(`width_size')) ///
  (function y=  _b[_cons] + x*_b[0b.above_threshold#c.mean_t]*(x<1.96) + (x^2)*_b[0b.above_threshold#c.mean_t_sq]*(x<1.96) /// 
  + x*_b[1.above_threshold#c.mean_t]*(x>=1.96) + (x^2)*_b[1.above_threshold#c.mean_t_sq]*(x>=1.96) +  _b[above_threshold]*(x>=1.96), range(0 `cutoff')) , ///
  xline(1.96) xtitle("T_stat (averaged within groups of `width_size')") ytitle("Number of Published Studies") legend(off)
graph export "${working}/graphs/RD_quadratic_thresh`cutoff'.pdf", replace

di " ratio of pub. probabilities with bin width `width_size' and cutoff `cutoff', OLS with quadratic: `expectation_ratio'"
* spec 3: poisson
qui poisson n_pub mean_t above_threshold if inrange(mean_t,0,`cutoff')
local predicted_unpub_at_thresh = exp(_b[_cons] + 1.96*_b[mean_t]) // now we have to do things in exponents bc poisson
local predicted_published_at_thresh = exp(_b[_cons] + 1.96*_b[mean_t]+_b[above_threshold])
local expectation_ratio = `predicted_published_at_thresh'/`predicted_unpub_at_thresh'
di " ratio of pub. probabilities with bin width `width_size' and cutoff `cutoff', Poisson: `expectation_ratio'"




* lowess 


tw (bar n_pub mean_t  if inrange(mean_t,0,`cutoff') , barw(.1)) ///
   (lowess n_pub mean_t if inrange(mean_t,0,`cutoff') & mean_t< 1.96) ///
     (lowess n_pub mean_t if inrange(mean_t,0,`cutoff') & mean_t>= 1.96) , ///
  xline(1.96) xtitle("T_stat (averaged within groups of `width_size')") ytitle("Number of Published Studies") legend(off)
graph export "${working}/graphs/RD_lowess_thresh`cutoff'.pdf", replace

}
}
*/

