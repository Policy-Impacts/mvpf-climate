import delimited using   "${outdata}/policy_masterlist_symm.csv", clear
keep pe se 
expand 15
g true_effect = rgamma(.18036,1.304)
g rademacher = runiformint(0 , 1)
replace rademacher = rademacher -1
replace true_effect = true_effect*rademacher
forv i=1/`=_N' {
    qui su true_effect in `i'
    local mean = r(mean)
    qui su se in `i'
    local sd = r(mean)
    replace pe = rnormal(`mean',1) in `i'
}

g t = pe
count if  abs(t)>1.64
sample `=100/10.573' if abs(t)<1.64
count if  abs(t)>1.64

hist t , xline(1.64)  xline(-1.64) bins(30)
e
replace pe = t*se 
keep if abs(pe)<3
tw (scatter  se pe ) ///
   (function y = 1/1.64*x, range(0 10) lcolor(black) lpattern(dash)) ///
   (function y = -1/1.96*x, range(-10 0) lcolor(black) lpattern(dash)), ///
   legend(off) note("`total_above' estimates droppped, of which `5pct' significant")  yscale(range(0 3)) ylabel(0(1)3)


import delimited using   "${outdata}/policy_masterlist_symm.csv", clear
replace t_stat = abs(t_stat)
local width_size = .02
gen group = ceil(t_stat/`width_size')
* confirm that 1.96 is a cutpoint with whatever bin width you use
su group if t_stat>1.96 
local minmax = r(min)
su group if t_stat<1.96
local maxmin = r(max)
assert `maxmin'<`minmax'
g above_threshold = group>`maxmin'
gcollapse (count) n_pub = t_stat (mean) mean_t = t_stat (first) above_threshold = above_threshold, by(group)
reg n_pub mean_t above_threshold 
g mean_t_sq = mean_t^2
poisson n_pub mean_t above_threshold if inrange(mean_t,0,5)
poisson n_pub  mean_t mean_t_sq above_threshold

rdrobust n_pub mean_t, c(1.96) masspoints(check)


poisson n_pub mean_t above_threshold if inrange(mean_t,0,5)
local predicted_unpub_at_thresh = exp(_b[_cons] + 1.96*_b[mean_t])
local predicted_published_at_thresh = exp(_b[_cons] + 1.96*_b[mean_t]+_b[above_threshold])
local expectation_ratio = `predicted_published_at_thresh'/`predicted_unpub_at_thresh'
di `expectation_ratio'

reg n_pub mean_t above_threshold  if inrange(mean_t,0,5)
local predicted_unpub_at_thresh = _b[_cons] + 1.96*_b[mean_t]
local predicted_published_at_thresh = _b[_cons] + 1.96*_b[mean_t]+_b[above_threshold]
local expectation_ratio = `predicted_published_at_thresh'/`predicted_unpub_at_thresh'
di `expectation_ratio'

poisson n_pub mean_t above_threshold if inrange(mean_t,0,10)
poisson n_pub mean_t above_threshold if inrange(mean_t,0,15)
