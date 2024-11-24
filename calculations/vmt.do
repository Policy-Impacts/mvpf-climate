*************************************************************
/* Purpose: Produce Two VMT Datasets (Avg. LDV and Car). */
*************************************************************

*************************************************************
/*          1.   VMT for Avg. Light-duty Vehicle.          */
*************************************************************
import excel "${policy_assumptions}", first clear sheet("vmt_by_age_ICE")

local namelist
ds vmt*
foreach var in `r(varlist)' {
	
	local newname = substr("`var'", 9, .)
	local namelist `namelist' `newname'
		
}

foreach type of local namelist {
	
	gen weighted_`type' = vmt_avg_`type' * sample_`type'
	
}

ds sample*
egen sample_total = rowtotal(`r(varlist)')
ds weighted*
egen vmt_avg_total = rowtotal(`r(varlist)')
gen fleet_avg_vmt = vmt_avg_total/sample_total
drop vmt_avg* weighted*

egen fleet_size_total = total(sample_total)
gen age_share = sample_total / fleet_size
keep age fleet_avg_vmt age_share

sort age
keep age age_share fleet_avg_vmt

split age, parse("-")
gen str_replace = substr(age1, 1, 2)
replace age1 = str_replace

destring age1, replace
qui sum age1
local age_max = r(max)

tempfile vmt_temp 
save "`vmt_temp.dta'", replace

clear
insobs `age_max'

gen age1 = .
forval val = 1(1)`age_max' {
	replace age1 = `val' if `val' == _n
}

merge 1:1 age using "`vmt_temp.dta'", nogen noreport

qui sum fleet_avg_vmt if age1 == 20
replace fleet_avg_vmt = r(mean) if inrange(age1, 20, 24)
qui sum age_share if age1 == 20
replace age_share = (r(mean))/5 if inrange(age1, 20, 24)

qui sum fleet_avg_vmt if age1 == 25
replace fleet_avg_vmt = r(mean) if inrange(age1, 25, 29)
qui sum age_share if age1 == 25
replace age_share = (r(mean))/5 if inrange(age1, 25, 29)
	
qui sum fleet_avg_vmt if age1 == 30
replace fleet_avg_vmt = r(mean) if inrange(age1, 30, 32)
qui sum age_share if age1 == 30
replace age_share = (r(mean))/3 if inrange(age1, 30, 32)
	
keep age1 age_share fleet_avg_vmt
rename age1 age
replace age = age 		
egen age_share_check = total(age_share)
assert age_share_check == 1
drop age_share_check	
		
save "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_avg.dta", replace 

*************************************************************
/*            2.   VMT for Avg. Light-duty Car.            */
*************************************************************
import excel "${policy_assumptions}", first clear sheet("vmt_by_age_ICE")
keep age *car
egen total_sample = total(sample_car)
gen age_share = sample_car / total_sample
drop total_sample

sort age
keep age age_share vmt_avg_car

split age, parse("-")
gen str_replace = substr(age1, 1, 2)
replace age1 = str_replace

destring age1, replace
qui sum age1
local age_max = r(max)	
		
tempfile vmt_temp 
save "`vmt_temp.dta'", replace

clear
insobs `age_max'

gen age1 = .
forval val = 1(1)`age_max' {
	replace age1 = `val' if `val' == _n
}

merge 1:1 age using "`vmt_temp.dta'", nogen noreport		
			
	
qui sum vmt_avg_car if age1 == 20
replace vmt_avg_car = r(mean) if inrange(age1, 20, 24)
qui sum age_share if age1 == 20
replace age_share = (r(mean))/5 if inrange(age1, 20, 24)

qui sum vmt_avg_car if age1 == 25
replace vmt_avg_car = r(mean) if inrange(age1, 25, 29)
qui sum age_share if age1 == 25
replace age_share = (r(mean))/5 if inrange(age1, 25, 29)
	
qui sum vmt_avg_car if age1 == 30
replace vmt_avg_car = r(mean) if inrange(age1, 30, 32)
qui sum age_share if age1 == 30
replace age_share = (r(mean))/3 if inrange(age1, 30, 32)
	
keep age1 age_share vmt_avg_car
rename age1 age
replace age = age 	
		
egen age_share_check = total(age_share)
assert age_share_check == 1
drop age_share_check	
		
save "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_car.dta", replace 