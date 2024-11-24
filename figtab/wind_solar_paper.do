***** WIND FIGURE *****

*Set toggles for figure
local elasticity_censor 	2.5
local mvpf_max 				10.0
local bar_dark_orange = "214 118 72"
local bar_blue = "36 114 237"
local bar_dark_blue = "8 51 97"

import excel "${output_fig}/figures_data/wind_papers.xlsx", first clear
tostring year_publishe, replace

gen label_name = country + " " + "(" + authors + " " +  year_published + ")"

gen paper_ind = _n 
levelsof(ind_name), local(wind_paper_loop)
foreach n of local wind_paper_loop {

	qui sum elasticity if ind_name == "`n'"
	local `n'_e = r(mean)
		
	qui sum paper_ind if ind_name == "`n'"
	local `n'_lab = label_name[r(mean)]
	
}

******Create dataset*******
tempname wind_mvpfs
tempfile wind_elasticity_data
postfile `wind_mvpfs' str18 specification str18 policy str18 cost_curve str18 US_only elasticity mvpf scc using `wind_elasticity_data', replace 
local i = 0

foreach lbd in "no" "yes" {
	global lbd = "`lbd'"
	forvalues y = 0.1(0.1)3.0 {
		local i = `i' + 1
		global feed_in_elas = `y' * -1
		if `i' == 10 {
			global feed_in_elas = -0.999
		}
		qui do "${github}/ado/wind_ado.ado"
		foreach policy in "wind_testing_2" {
			qui run_program `policy', folder("robustness")
			local MVPF_US = (${WTP_USPres_`policy'} + ${WTP_USFut_`policy'})/${cost_`policy'}
			post `wind_mvpfs' ("current") ("`policy'") ("${lbd}") ("no") (`y') ( ${MVPF_`policy'}) (193)
			post `wind_mvpfs' ("current") ("`policy'") ("${lbd}") ("yes") (`y') (`MVPF_US') (193)		
		}
	}
}
postclose `wind_mvpfs'
use `wind_elasticity_data', clear
sort mvpf

** Addressing "w/ Cost Curve" vs. "w/o Cost Curve"
drop if US_only == "yes"

gen mvpf_cc_yes = .
gen mvpf_cc_no = .

local yn_loop yes no
foreach v of local yn_loop {
	
	bysort elasticity : replace mvpf_cc_`v' = mvpf if cost_curve == "`v'"
	
}
collapse (mean) mvpf_*, by(elasticity)

insobs 1, before(1)
ds mvpf*
foreach var in `r(varlist)' {
	
	replace `var' = 1 if `var' == .
	replace elasticity = 0 if elasticity == .
	
}
	

** Want to Censor MVPF
drop if elasticity > `elasticity_censor'

ds mvpf*
foreach var in `r(varlist)' {
	
	replace `var' = . if `var' > `mvpf_max'
	
}


local mvpf_max_text = `mvpf_max'



local eu_line_color = "black"
drop if elasticity > 2.0
drop if elasticity == 1

 

tw ///
	(line mvpf_cc_yes elasticity, msize(tiny) lcolor("`bar_blue'")) ///
	(line mvpf_cc_no elasticity, msize(tiny) lcolor("`bar_dark_orange'")) ///
	, ///
	graphregion(color(white)) ///
	plotregion(margin(b=0 l=0)) ///
	xtitle("Elasticity") ///
		xsize(8) ///	
		xlab(0(0.5)2, nogrid ) ///
	ytitle("MVPF") ///
	ylab(0(2.0)10, nogrid  format(%9.1f)) ///
	/// (European Wind)
	xline(`hitaj_germany_e', noextend lcolor("`eu_line_color'") lpattern(shortdash)) ///
		text(`mvpf_max_text' `hitaj_germany_e' "`hitaj_germany_lab'", size(vsmall) orient(vertical)) /// 
	xline(`bolksejo_uk_e', noextend lcolor("`eu_line_color'") lpattern(shortdash)) ///
		text(`mvpf_max_text' `bolksejo_uk_e' "`bolksejo_uk_lab'", size(vsmall) orient(vertical)) /// 			
	xline(`bolksejo_france_e', noextend lcolor("`eu_line_color'") lpattern(shortdash)) ///
		text(`mvpf_max_text' `bolksejo_france_e' "`bolksejo_france_lab'", size(vsmall) orient(vertical)) /// 		
	xline(`bolksejo_spain_e', noextend lcolor("`eu_line_color'") lpattern(shortdash)) ///
		text(`mvpf_max_text' `bolksejo_spain_e' "`bolksejo_spain_lab'", size(vsmall) orient(vertical)) /// 		
	xline(`bolksejo_germany_e', noextend lcolor("`eu_line_color'") lpattern(shortdash)) ///
		text(`mvpf_max_text' `bolksejo_germany_e' "`bolksejo_germany_lab'", size(vsmall) orient(vertical)) /// 
	/// (US Wind)	
	xline(`shirmali_us_e', noextend lcolor(black)) ///
		text(`mvpf_max_text' `shirmali_us_e' "`shirmali_us_lab'", size(vsmall) orient(vertical)) /// 	
	xline(`hitaj_us_e', noextend lcolor(black)) ///
		text(`mvpf_max_text' `hitaj_us_e' "`hitaj_us_lab'", size(vsmall) orient(vertical)) /// 	
	xline(`metcalf_us_e', noextend lcolor(black)) ///
		text(`mvpf_max_text' `metcalf_us_e' "`metcalf_us_lab'", size(vsmall) orient(vertical)) ///
	legend(off) 

	
cap graph export "${output_fig}/figures_main/Fig_2b_wind_elasticities.wmf", replace
graph export "${output_fig}/figures_main/Fig_2b_wind_elasticities.png", replace


***** SOLAR FIGURE

******Solar***************
tempname solar_mvpfs
tempfile solar_elasticity_data
postfile `solar_mvpfs' str18 specification str18 policy str18 cost_curve elasticity mvpf scc using `solar_elasticity_data', replace 
local i = 0
foreach lbd in "no" "yes" {
	global lbd = "`lbd'"
	foreach spec_type in "current"{
		forvalues y = .1(0.1)2.5 {
			local i = `i' + 1
			global feed_in_elas = `y' * -1
			if `i' == 10 {
				global feed_in_elas = 0.99 * -1
			}
			qui do "${github}/ado/solar.ado"
			foreach policy in "solar_testing" {
				di ${feed_in_elas}
				qui run_program `policy', folder("robustness")
				local MVPF_US = (${WTP_USPres_`policy'} + ${WTP_USFut_`policy'})/${cost_`policy'}
				post `solar_mvpfs' ("`spec_type'") ("`policy'") ("${lbd}") (`y') ( ${MVPF_`policy'}) (193)

				post `solar_mvpfs' ("`spec_type'") ("`policy'") ("US") (`y') (`MVPF_US') (193)
				
			}
		}
	}

}
postclose `solar_mvpfs'	
use `solar_elasticity_data', clear
sort mvpf


** Addressing "w/ Cost Curve" vs. "w/o Cost Curve"
drop if cost_curve == "US"

gen mvpf_cc_yes = .
gen mvpf_cc_no = .

local yn_loop yes no
foreach v of local yn_loop {
	
	bysort elasticity : replace mvpf_cc_`v' = mvpf if cost_curve == "`v'"
	
}
collapse (mean) mvpf_*, by(elasticity)

insobs 1, before(1)
ds mvpf*
foreach var in `r(varlist)' {
	
	replace `var' = 1 if `var' == .
	replace elasticity = 0 if elasticity == .
	
}
	
** Want to Censor MVPF
drop if elasticity > 2.0
drop if elasticity < 0
	
local solar_sensor = 7.5

ds mvpf*
foreach var in `r(varlist)' {
	
	replace `var' = 7.5 if `var' > `solar_sensor'
	
}

replace mvpf_cc_yes = . if elasticity > 1.71

local mvpf_max_text = `solar_sensor'



tw ///
	(line mvpf_cc_yes elasticity, msize(tiny) lcolor("`bar_blue'")) ///
	(line mvpf_cc_no elasticity, msize(tiny) lcolor("`bar_dark_orange'")) ///
	, ///
	graphregion(color(white)) ///
	plotregion(margin(b=0 l=0)) ///
	xtitle("Elasticity") ///
		xsize(8) ///	
		xlab(0(0.5)2.0, nogrid  ) ///
	ytitle("MVPF") ///
	ylab(0 (1.5)7.5, nogrid format(%9.2f) ) ///
	xline(1.59, noextend lcolor(black)) ///
			text(`mvpf_max_text' 1.59 "Dorsey (2022)", size(vsmall) orient(vertical)) /// 		
	xline(1.138091, noextend lcolor(black)) ///
		text(`mvpf_max_text' 1.138091 "Pless and van Benthem - HO (2019)", size(vsmall) orient(vertical)) /// 	
	xline(1.04, noextend lcolor(black)) ///
		text(`mvpf_max_text' 1.04 "Pless and van Benthem - TPO (2019)", size(vsmall) orient(vertical)) /// 	 
	xline(0.651, noextend lcolor(black)) ///
		text(`mvpf_max_text' 0.651 "Gillingham and Tsvetanov (2019)", size(vsmall) orient(vertical)) /// 		
	xline(1.4896797, noextend lcolor(black)) ///
		text(`mvpf_max_text' 1.4896797 "Crago and Chernyakhovskiy (2017)", size(vsmall) orient(vertical)) /// 			
	legend(off) 

cap graph export "${output_fig}/figures_main/Fig_3b_solar_elasticities.wmf", replace
graph export "${output_fig}/figures_main/Fig_3b_solar_elasticities.png", replace
