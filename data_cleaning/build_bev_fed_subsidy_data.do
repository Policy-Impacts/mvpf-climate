*****************************************************
/* Cleans data from Ziegler and Trancik and Statista
on the sales of batteries over time */
*****************************************************

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

** Pull in previously gathered data on the sales, energy consumption, MSRP, and battery capacity of BEV models from 2010 through 2020

import excel using "${code_files}/1_assumptions/policy_category_assumptions_MASTER.xlsx", clear first sheet("ev_kwh_calcs")
keep if Type == "EV"
ren C sales2011
ren kWhpermile eff2011
ren msrp msrp2011
ren batterykWh batt_cap2011
ren G sales2012
ren H eff2012
ren I msrp2012
ren J batt_cap2012
ren K sales2013
ren L eff2013
ren M msrp2013
ren N batt_cap2013
ren O sales2014
ren P eff2014
ren Q msrp2014
ren R batt_cap2014
ren S sales2015
ren T eff2015
ren U msrp2015
ren V batt_cap2015
ren W sales2016
ren X eff2016
ren Y msrp2016
ren Z batt_cap2016
ren AA sales2017
ren AB eff2017
ren AC msrp2017
ren AD batt_cap2017
ren AE sales2018
ren AF eff2018
ren AG msrp2018
ren AH batt_cap2018
ren AI sales2019
ren AJ eff2019
ren AK msrp2019
ren AL batt_cap2019
ren AM sales2020
ren AN eff2020
ren AO msrp2020
ren AP batt_cap2020
ren AQ sales2021
ren AR eff2021
ren AS msrp2021
ren AT batt_cap2021
ren AU sales2022
ren AV eff2022
ren AW msrp2022
ren AX batt_cap2022

foreach v of var *{
	di "variable is `v'"
	capture confirm string variable `v'
	if !_rc{
		replace `v' = "" if `v' == "-"
		destring `v', replace
	}
}

drop Total

gsort  -sales2011 -sales2012 -sales2013 -sales2014 -sales2015 -sales2016 -sales2017 -sales2018 -sales2019 -sales2020 -sales2021 -sales2022

** Fill in subsidy data from fueleconomy.gov, average within model if there are different numbers for trims

forvalues i = 2011(1)2022{
	gen subsidy`i' = .
}

forvalues i = 2011(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Nissan Leaf"
}

forvalues i = 2012(1)2018{
	replace subsidy`i' = 7500 if Vehicle == "Ford Focus EV"
}

foreach i of numlist 2012 2014 2016 2017{
	replace subsidy`i' = 7500 if Vehicle == "Mitsubishi I EV"
}

forvalues i = 2012(1)2018{
	replace subsidy`i' = 7500 if Vehicle == "Tesla Model S"
}

replace subsidy2019 = (3750 + 1875) / 2 if Vehicle == "Tesla Model S"
replace subsidy2020 = 0 if Vehicle == "Tesla Model S"

forvalues i = 2012(1)2014{
	replace subsidy`i' = 7500 if Vehicle == "Toyota RAV4 EV"
}

order Vehicle subsidy2011 subsidy2012 subsidy2013 subsidy2014 subsidy2015 subsidy2016 subsidy2017 subsidy2018 subsidy2019 subsidy2020 subsidy2021 subsidy2022

forvalues i = 2012(1)2019{
	replace subsidy`i' = 7500 if Vehicle == "Fiat 500E"
}

forvalues i = 2013(1)2019{
	replace subsidy`i' = 7500 if Vehicle == "Smart ED"
}

forvalues i = 2014(1)2012{
	replace subsidy`i' = 7500 if Vehicle == "BMW i3"
}

forvalues i = 2014(1)2016{
	replace subsidy`i' = 7500 if Vehicle == "Chevy Spark"
}

forvalues i = 2014(1)2017{
	replace subsidy`i' = 7500 if Vehicle == "Mercedes B-Class (B250e)"
}

forvalues i = 2015(1)2020{
	replace subsidy`i' = 7500 if Vehicle == "Kia Soul EV"
}

forvalues i = 2015(1)2019{
	replace subsidy`i' = 7500 if Vehicle == "VW e-Golf"
}

forvalues i = 2016(1)2018{
	replace subsidy`i' = 7500 if Vehicle == "Tesla Model X"
}
replace subsidy2019 = (3750 + 1875) / 2 if Vehicle == "Tesla Model X"
replace subsidy2020 = 0 if Vehicle == "Tesla Model X"

forvalues i = 2017(1)2018{
	replace subsidy`i' = 7500 if Vehicle == "Chevy Bolt"
}

replace subsidy2019 = (7500 * 3 + 3750 * 7 + 1875 * 3) / 12 if Vehicle == "Chevy Bolt"
replace subsidy2020 = (1875 * 3) / 12 if Vehicle == "Chevy Bolt"

forvalues i = 2017(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Hyundai Ioniq EV"
}

forvalues i = 2017(1)2018{
	replace subsidy`i' = 7500 if Vehicle == "Tesla Model 3"
}
replace subsidy2019 = (3750 * 6 + 1875 * 6) / 12 if Vehicle == "Tesla Model X"
replace subsidy2020 = 0 if Vehicle == "Tesla Model X"

forvalues i = 2019(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Audi e-tron"
}
forvalues i = 2019(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Hundai Kona Electric"
	replace subsidy`i' = 7500 if Vehicle == "Kia Niro EV"
}
forvalues i = 2019(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Jaguar I-Pace"
}
forvalues i = 2021(1)2022{
	replace subsidy`i' = 7500 if Vehicle == "Ford Mustang Mach-E"
}
replace subsidy2021 = 7500 if Vehicle == "VW ID.4"
replace subsidy2022 = 7500 if Vehicle == "BMW i4" | Vehicle == "Ford F-150 Lightning" | Vehicle == "Mercedes EQS1" | Vehicle == "Rivian R1T" | Vehicle == "VW ID.4"

order Vehicle sales2011 subsidy2011 sales2012 subsidy2012 sales2013 subsidy2013 sales2014 subsidy2014 sales2015 subsidy2015 sales2016 subsidy2016 sales2017 subsidy2017 sales2018 subsidy2018 sales2019 subsidy2019 sales2020 subsidy2020 sales2021 subsidy2021 sales2022 subsidy2022

forv i = 2011(1)2022{
	gen sales_subsidy`i' = sales`i'
	replace sales_subsidy`i' = 0 if missing(batt_cap`i')
}

order Vehicle sales2011 sales_subsidy2011 subsidy2011 sales2012 sales_subsidy2012 subsidy2012 sales2013 sales_subsidy2013 subsidy2013 sales2014 sales_subsidy2014 subsidy2014 sales2015 sales_subsidy2015 subsidy2015 sales2016 subsidy2016 sales2017 subsidy2017 sales2018 subsidy2018 sales2019 subsidy2019 sales2020 subsidy2020 sales2021 subsidy2021 sales2022 subsidy2022

merge 1:1 Vehicle using "${code_files}/1_assumptions/evs/processed/kbb_ev_sales2023"

*** Adding in 2023 IRA subsidies ***
gen subsidy2023 = .
replace subsidy2023 = 7500 if Vehicle == "Cadillac Lyric" | Vehicle = "Chevy Bolt" | Vehicle == "Ford E-Transit" | Vehicle == "Ford F-150 Lightning" | Vehicle == "Ford Mustang Mach-E" | Vehicle == "Genesis GV70" | Vehicle == "Mercedes EQE" | Vehicle == "Nissan Leaf" | Vehicle == "Rivian R1S" | Vehicle == "Rivian R1T" | Vehicle == "Tesla Model 3" | Vehicle == "Tesla Model Y" | Vehicle == "VW ID.4"

*** Adding in 2023 model battery capacities
gen batt_cap2023 = .
replace batt_cap2023 = 82 if Vehicle == "Audi Q4 e-tron"
replace batt_cap2023 = 95 if Vehicle == "Audi e-tron"
replace batt_cap2023 = (113 + 109 + 105 + 99 + 96) / 5 if Vehicle == "BMW i4"
replace batt_cap2023 = 105.7 if Vehicle == "BMW i7"
replace batt_cap2023 = (86 + 86 + 83) / 3 if Vehicle == "BMW iX"
replace batt_cap2023 = 89 if Vehicle == "Cadillac Lyric"
replace batt_cap2023 = (120 + 115) / 2 if Vehicle == "Chevrolet Bolt"
replace batt_cap2023 = 92 if Vehicle == "Fisker Ocean"
replace batt_cap2023 = (70) / 5 if Vehicle == "BMW i4"






forv i = 2011(1)2022{
	egen subsidy_N`i' = total(sales_subsidy`i')
	egen subsidy_weighted_avg`i' = total(sales_subsidy`i' * subsidy`i')
	replace subsidy_weighted_avg`i' = subsidy_weighted_avg`i' / subsidy_N`i'
	egen total_sales`i' = total(sales`i')
}

reshape long subsidy_weighted_avg subsidy_N total_sales, i(Vehicle) j(year)
keep Vehicle year subsidy_weighted_avg subsidy_N total_sales
sort year
duplicates drop year subsidy_weighted_avg, force
drop Vehicle

gen cf_mpg = .
replace cf_mpg = 34.14553791 if year == 2011
replace cf_mpg = 36.1435982 if year == 2012
replace cf_mpg = 37.18641938 if year == 2013
replace cf_mpg = 37.15545901 if year == 2014
replace cf_mpg = 37.98032025 if year == 2015
replace cf_mpg = 38.36676002 if year == 2016
replace cf_mpg = 39.25534422 if year == 2017
replace cf_mpg = 40.19405409 if year == 2018
replace cf_mpg = 40.22276842 if year == 2019
replace cf_mpg = 41.23347259 if year == 2020
replace cf_mpg = 42.83519439 if year == 2021
replace cf_mpg = 44.74198748 if year == 2022

save "${code_files}/1_assumptions/evs/processed/bev_fed_subsidy_data.dta", replace

