
if ("`c(username)'" == "sarahaa") { // Sarah
    global user = "C:/Users/sarahaa"
    global dropbox = "${user}/Dropbox (MIT)/Regulation"
    global github = "${user}/Documents/GitHub/mvpf-enviro"
}

if ("`c(username)'" == "sarah") { // Sarah's personal computer
	global user = "/Users/sarah"
	global dropbox = "${user}/Dropbox (MIT)/Regulation"
	global github = "${user}/Documents/GitHub/mvpf-enviro"
}

***************************
/*    State-level VMT    */
***************************
** Calculating a sample-weighted average across vehicle types for the state-level VMT
import excel "${code_files}/1_assumptions/evs/vmt_by_state_2017_survey.xlsx", sheet("AVG_BESTMILE_Gas") first clear

ren VEHTYPE vmt
ren A state
keep vmt state

drop if missing(state) | missing(vmt)
drop if state == "TOTAL"

destring vmt, replace

save "${code_files}/1_assumptions/evs/processed/ice_vmt_by_state", replace

** Calculating a sample-weighted average across vehicle types for the age-level VMT
import excel "${code_files}/1_assumptions/evs/vmt_by_age_2017_survey", sheet("AVG_BESTMILE_Gas") first clear

ren VEHTYPE vmt
ren A age
keep vmt age

drop if missing(age) | missing(vmt)
drop if age == "I don't know"
drop if age == "I prefer not to answer"
drop if age == "TOTAL"

destring vmt, replace

tempfile vmt
sa `vmt'

import excel "${code_files}/1_assumptions/evs/vmt_by_age_2017_survey", sheet("Sample Size_Gas") first clear

keep A D
ren A age
ren D count

drop if missing(age) | missing(count)
drop if age == "I don't know"
drop if age == "I prefer not to answer"
drop if age == "TOTAL"

destring count, replace

merge 1:1 age using `vmt'

drop _merge

expand 5 if age == "20-24"
expand 5 if age == "25-29"
expand 3 if age == "30-32"

sort age

replace count = count/5 if age == "20-24"
replace count = count/5 if age == "25-29"
replace count = count/3 if age == "30-32"

replace age = "20" if _n == 13 & age == "20-24"
replace age = "21" if _n == 14 & age == "20-24"
replace age = "22" if _n == 15 & age == "20-24"
replace age = "23" if _n == 16 & age == "20-24"
replace age = "24" if _n == 17 & age == "20-24"

replace age = "25" if _n == 18 & age == "25-29"
replace age = "26" if _n == 19 & age == "25-29"
replace age = "27" if _n == 20 & age == "25-29"
replace age = "28" if _n == 21 & age == "25-29"
replace age = "29" if _n == 22 & age == "25-29"

replace age = "30" if _n == 24 & age == "30-32"
replace age = "31" if _n == 25 & age == "30-32"
replace age = "32" if _n == 26 & age == "30-32"

replace age = "33" if age == "33+"

destring age, replace
sort age

save "${code_files}/1_assumptions/evs/processed/ice_vmt_by_age", replace

egen N_fleet = total(count)
egen weighted_avg_fleet = total(vmt * count)
replace weighted_avg_fleet = weighted_avg_fleet / N_fleet

gen age_diff = (weighted_avg_fleet - vmt) / weighted_avg_fleet

keep age age_diff


tempfile age_change
sa `age_change'

use "${code_files}/1_assumptions/evs/processed/ice_vmt_by_state", clear

expand 33
gen age = .
bysort state: replace age = _n

merge m:1 age using `age_change'
drop _merge

gen vmt_by_state_age = vmt - age_diff * vmt
sort state age

save "${code_files}/1_assumptions/evs/processed/ice_vmt_by_state_by_age", replace



