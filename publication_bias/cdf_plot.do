* PATHS 
global working "${code_files}/7_publication_bias"
global indata "${code_files}/7_publication_bias/data/uncorrected"
global policylist "${code_files}/"

if "`c(os)'"=="MacOSX" local suf svg
else local suf wmf

*** GRAPH COLORS*** 
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_orange = "237 170 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"
*****

*** OPTIONS ***
local cutoff `1' // up to what abs value of the t-stat to visualize?
local width_size `2' // how big to make the bins? best if a divisor of 1.96


* read in data set with uncorrected t-stats
qui import delimited using "${indata}/policy_masterlist.csv", clear
qui replace t_stat = abs(t_stat) // do things in absolute values to have one cutoff


qui gen group = ceil(abs_t_stat/`width_size')
keep if abs_t_stat <`cutoff'
* confirm that 1.96 is a cutpoint with whatever bin width you use -- there's no bin that contains both observations above and below 1.96
qui su group if abs_t_stat > 1.96 
local minmax = r(min)
qui su group if abs_t_stat < 1.96
local maxmin = r(max)
assert `maxmin' < `minmax'
* generate an indicator for being above the cutoff
g above_threshold = group > `maxmin'
* collapse the dataset into counts with mean t-stat within group as the running variable
bys group: gegen max_t = max(abs_t_stat)
di r(mean) * r(N)
bys group: gegen tot_n = count(abs_t_stat)
replace tot_n = tot_n / (_N)

cumul  abs_t_stat, gen(cum)
gsort cum
qui levelsof group, local(group_levels)

foreach lev of local group_levels {
    di in red "level is `lev'"
    su tot_n if group == `lev'
    assert round(r(sd), 0.000000000001) == 0 | r(sd)== .
    local group_slope_`lev' = r(mean)
    if `lev' == 1 local graphcmd  = "`group_slope_`lev''*min(x,`width_size')"
    else local graphcmd  =  "`graphcmd'" + "+`group_slope_`lev''*min(max(x-`=`width_size'*(`lev'-1)',0),`=`width_size'*`lev'') "
}

tw (line cum abs_t_stat, lcolor("`bar_blue'"))  ///
   (function y = `group_slope_1'*x, range(0 .98) lcolor(gray)) ///
   (function y =  `group_slope_1'*.98 + `group_slope_2'*(x-.98), range(.98 1.96) lcolor(gray)) ///
   (function y =  `group_slope_1'*.98 + `group_slope_2'*(.98) + `group_slope_3'*(x-1.96), range(1.96 2.94) lcolor(gray))   ///
   (function y =  `group_slope_1'*.98 + `group_slope_2'*(.98) +  `group_slope_3'*(.98) + `group_slope_4'*(x-2.94), range(2.94 3.92) lcolor(gray))    ///
   (function y =  `group_slope_1'*.98 + `group_slope_2'*(.98) +  `group_slope_3'*(.98) + `group_slope_4'*(.98) + `group_slope_5'*(x-3.92), range(3.92 4.9) lcolor(gray)) , ///
   text(`=`group_slope_1'*.49 + .1' .49 "Slope =`: di %4.3f `group_slope_1''") ///
   text(`=`group_slope_1'*.98 + `group_slope_2'*.49 + .2' 1.47 "Slope =`: di %4.3f `group_slope_2''") ///
   text(`=`group_slope_1'*.98 + `group_slope_2'*.98 + `group_slope_3'*.49  + .2' 2.45 "Slope =`: di %4.3f `group_slope_3''") ///
   text(`=`group_slope_1'*.98 + `group_slope_2'*.98 + `group_slope_3'*.98  + `group_slope_4'*.49 + .1' 3.43 "Slope =`: di %4.3f `group_slope_4''") ///
   text(`=`group_slope_1'*.98 + `group_slope_2'*.98 + `group_slope_3'*.98  + `group_slope_4'*.98  + `group_slope_5'*.49 + .1' 4.41 "Slope =`: di %4.3f `group_slope_5''") ///
   legend(order(1 "Empirical CDF" 2 "Fit using our method")) ///
   xtitle(T-stat (abs. val.)) ///
   ytitle (Cumulative Probability) ///
   ylabel( , nogrid) ///
   xlabel( , nogrid)

graph export "${code_files}/5_graphs/figures_appendix/cdf_plot.`suf'", replace
graph export "${code_files}/5_graphs/figures_appendix/cdf_plot.pdf", replace
graph export "${dropbox_me}/Apps/Overleaf/MVPF Climate Policy/Figures/Publication_Bias/cdf_plot.pdf", replace
keep abs_t_stat 
g sample = "actual"
preserve
    *** fit using Andrews & Kasy
    * use spec 

    import delimited using "${working}/data/corrected/output/MLE_model_parameters_threshold_5_mode_3.csv", clear

    qui su v1 in 1 
    local mean = r(mean)
    qui su v2 in 1 
    local sd = r(mean)
    qui su v3 in 1 
    local pub_bias = r(mean)

    import delimited using "${outdata}/policy_masterlist.csv", clear
    keep pe se 
    expand 15
    g true_effect = rnormal(`mean',`sd')
    forv i=1/`=_N' {
        qui su true_effect in `i'
        local mean = r(mean)
        qui su se in `i'
        local sd = r(mean)
        replace pe = rnormal(`mean',1) in `i'
    }

    g t = pe / se 
    sample `=100*`pub_bias'' if abs(t)<1.96

    g abs_t_stat = abs(t)
    keep if abs_t_stat < `cutoff'
    g sample = "AK simulated"
    tempfile toappend
    save `toappend'
    keep abs_t_stat sample
restore

append using `toappend'
cumul  abs_t_stat if sample == "actual", gen(cum)
cumul  abs_t_stat if sample == "AK simulated", gen(cum2)
gsort cum cum2 

tw (line cum abs_t_stat, lcolor("`bar_blue'"))  ///
   (line cum2 abs_t_stat, lcolor("`bar_light_orange'") ylabel( , nogrid))  , ///
   xtitle(T-stat (abs. val.)) /// 
   ytitle(Cumulative Probability) /// 
   legend(order(1 "Empirical CDF" 2 "Fit using AK (2019) method")) ///
   xlabel( , nogrid) ///
   ylabel( , nogrid)
 
graph export "${code_files}/5_graphs/figures_appendix/cdf_plot_AK.`suf'", replace
graph export "${code_files}/5_graphs/figures_appendix/cdf_plot_AK.pdf", replace
