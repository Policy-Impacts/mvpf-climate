
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

import excel using "${code_files}/1_assumptions/evs/10301_hev_sale_2-28-20.xlsx", clear first

ren B sales1999
ren C sales2000
ren D sales2001
ren E sales2002
ren F sales2003
ren G sales2004
ren H sales2005
ren I sales2006
ren J sales2007
ren K sales2008
ren L sales2009
ren M sales2010
ren N sales2011
ren O sales2012
ren P sales2013
ren Q sales2014
ren R sales2015
ren S sales2016
ren T sales2017
ren U sales2018
ren V sales2019

forv i = 1999(1)2019{
	gen price`i' = .
	gen batt_cap`i' = .
	gen msrp`i' = .
	gen mpg`i' = .
}

replace batt_cap2000 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2001 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2002 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2003 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2004 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2005 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2006 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"

replace batt_cap2001 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2002 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2003 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2004 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2005 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2006 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius"

replace batt_cap2003 = 6.5 * 144 / 1000 if Vehicle == "Honda Civic"
replace batt_cap2004 = 6.5 * 144 / 1000 if Vehicle == "Honda Civic"
replace batt_cap2005 = 6 * 144 / 1000 if Vehicle == "Honda Civic"
replace batt_cap2006 = 5.5 * 158 / 1000 if Vehicle == "Honda Civic"

replace batt_cap2005 = 6 * 330 / 1000 if Vehicle == "Ford Escape/Mercury Mariner"
replace batt_cap2006 = 6 * 330 / 1000 if Vehicle == "Ford Escape/Mercury Mariner"

replace batt_cap2005 = 6 * 144 / 1000 if Vehicle == "Honda Accord"
replace batt_cap2006 = 6 * 144 / 1000 if Vehicle == "Honda Accord"

replace batt_cap2006 = 6.5 * 288 / 1000 if Vehicle == "Toyota Highlander"

replace batt_cap2006 = 6.5 * 288 / 1000 if Vehicle == "Lexus RX 450h"

preserve
	import excel using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.xlsx", clear first
	save "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.dta", replace
restore

append using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.dta", gen(source)

order Vehicle sales2020
sort Vehicle

bys Vehicle: egen newsales2020 = min(sales2020)
order Vehicle sales2020 newsales2020
drop sales2020
ren newsales2020 sales2020

drop if Vehicle == "Total"

replace sales2020 = sales2020[2] if Vehicle == "Acura MDX Hybrid"
replace sales2020 = sales2020[4] if Vehicle == "Acura NSX"
replace sales2020 = sales2020[18] if Vehicle == "Ford Escape/Mercury Mariner"
replace sales2020 = sales2020[21] if Vehicle == "Ford Fusion & Milan"
replace sales2020 = sales2020[30] if Vehicle == "Hyundai Ioniq Hybrid"
replace sales2020 = sales2020[41] if Vehicle == "Kia Optima"
replace sales2020 = sales2020[48] if Vehicle == "Lexus LC500h"
replace sales2020 = sales2020[50] if Vehicle == "Lexus LS 500h"
replace sales2020 = sales2020[53] if Vehicle == "Lexus NX Hybrid"
replace sales2020 = sales2020[55] if Vehicle == "Lexus RX 450h"
replace sales2020 = sales2020[85] if Vehicle == "Toyota Prius"

sort Vehicle source
order Vehicle sales2020 sales2000 sales2001 source

drop if Vehicle == "Acura MDX"
drop if Vehicle == "Acura NS-X"
drop if Vehicle == "Acura RLX" & source == 1
drop if Vehicle == "Ford Escape"
drop if Vehicle == "Ford Fusion"
drop if Vehicle == "Honda Accord" & source == 1
drop if Vehicle == "Honda Insight" & source == 1
drop if Vehicle == "Hyundai Ioniq"
drop if Vehicle == "Hyundai Sonata" & source == 1
drop if Vehicle == "Kia Niro" & source == 1
drop if Vehicle == "Kia Optima/K5"
drop if Vehicle == "Lexus LC"
drop if Vehicle == "Lexus LS"
drop if Vehicle == "Lexus NX"
drop if Vehicle == "Lexus RX"
drop if Vehicle == "Lexus UX" & source == 1
drop if Vehicle == "Lincoln MKZ" & source == 1
drop if Vehicle == "Toyota Avalon" & source == 1
drop if Vehicle == "Toyota Camry" & source == 1
drop if Vehicle == "Toyota Corolla" & source == 1
drop if Vehicle == "Toyota Highlander" & source == 1
drop if Vehicle == "Toyota Prius / Prius Prime" & source == 1
drop if Vehicle == "Toyota RAV4" & source == 1

gen batt_cap2020 = .
gen mpg2020 = .

replace batt_cap2020 = 1.3 if Vehicle == "Acura RLX" | Vehicle == "Acura NS-X" // Google
replace batt_cap2020 = 1.1 if Vehicle == "Ford Escape" // Google
replace batt_cap2020 = 1.1 if Vehicle == "Ford Explorer" // Google
replace batt_cap2020 = 1.4 if Vehicle == "Ford Fusion" // Google
replace batt_cap2020 = 1.3 if Vehicle == "Honda Accord" // Google
replace batt_cap2020 = 1.2 if Vehicle == "Honda Insight" // Wikipedia
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Toyota RAV4" // manual
replace batt_cap2020 = 6.5 * 288 / 1000 if Vehicle == "Toyota Highlander" // manual
replace batt_cap2020 = ((4  * 207.2 + 6.5 * 201.6) / 1000) / 2 if Vehicle == "Toyota Prius" // manual, avg of 2WD and AWD
replace batt_cap2020 = ((4  * 259 + 6.5 * 244.8) / 1000) / 2 if Vehicle == "Toyota Camry" // manual, avg of AXVH70 and AXVH71 models
replace batt_cap2020 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Corolla" // manual
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Toyota Avalon" // manual
replace batt_cap2020 = 6.5 * 240 / 1000 if Vehicle == "Kia Niro" // Kia news release
replace batt_cap2020 = 6.5 * 270 / 1000 if Vehicle == "Kia Optima" // Kia news release
replace batt_cap2020 = 6.5 * 288 / 1000 if Vehicle == "Lexus RX" // manual
replace batt_cap2020 = 6.5 * 216 / 1000 if Vehicle == "Lexus UX" // manual
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Lexus NX" | Vehicle == "Lexus ES" // manual
replace batt_cap2020 = 3.6 * 310.8 / 1000 if Vehicle == "Lexus LS" | Vehicle == "Lexus LC" // manual
replace batt_cap2020 = 1.56 if Vehicle == "Hyundai Ioniq" // Wikipedia
replace batt_cap2020 = 1.62 if Vehicle == "Hyundai Sonata" // Google
replace batt_cap2020 = 1 if Vehicle == "Lincoln MKZ" // cars.com

*** All msrp info is from edmunds unless otherwise noted

gen msrp2020 = .
replace msrp2020 = (36750 + 42500) / 2 if Vehicle == "Lincoln MKZ"
replace msrp2020 = (24325 + 25535 + 26935 + 28375 + 29375 + 32500) / 6 if Vehicle == "Toyota Prius"
replace msrp2020 = 52530 if Vehicle == "Ford Explorer"
replace msrp2020 = (28265 + 33550) / 2 if Vehicle == "Ford Escape"
replace msrp2020 = 97510 if Vehicle == "Lexus LC"
replace msrp2020 = 80010 if Vehicle == "Lexus LS"
replace msrp2020 = (22930 + 24310 + 28340) / 3 if Vehicle == "Honda Insight"
replace msrp2020 = 157500 if Vehicle == "Acura NS-X"
replace msrp2020 = 61900 if Vehicle == "Acura RLX"
replace msrp2020 = (25470 + 29370 + 31870 + 35140) / 4  if Vehicle == "Honda Accord"
replace msrp2020 = 23100 if Vehicle == "Toyota Corolla"
replace msrp2020 = (28430 + 30130 + 32730) / 3 if Vehicle == "Toyota Camry"
replace msrp2020 = (28000 + 31630 + 34595) / 3 if Vehicle == "Ford Fusion"
replace msrp2020 = (34500 + 36500 + 39700) / 3 if Vehicle == "Lexus UX"
replace msrp2020 = (23200 + 25150 + 28400 + 31200) / 4 if Vehicle == "Hyundai Ioniq"
replace msrp2020 = (24590 + 25990 + 28290 + 30790 + 32790) / 5 if Vehicle == "Kia Niro"
replace msrp2020 = (37000 + 39500 + 43300) / 3  if Vehicle == "Toyota Avalon"
replace msrp2020 = (41810 + 44665 + 45660) / 3 if Vehicle == "Lexus ES"
replace msrp2020 = (39070 + 46160) / 2 if Vehicle == "Lexus NX"
replace msrp2020 = (28350 + 29645 + 34300 + 36880) / 4 if Vehicle == "Toyota RAV4"
replace msrp2020 = (27750 + 29900 + 35300) / 3 if Vehicle == "Hyundai Sonata"
replace msrp2020 = 29310 if Vehicle == "Kia Optima"
replace msrp2020 = (50510 + 56510) / 2 if Vehicle == "Lexus RX"
replace msrp2020 = (38200 + 41000 + 45050 + 48250) / 4 if Vehicle == "Toyota Highlander"
replace msrp2020 = (69000 + 73600 + 79700) / 3 if Vehicle == "Audi A7"
replace msrp2020 = (43450 + 44465 + 46950 + 49750) / 4 if Vehicle == "Jeep Wrangler"
replace msrp2020 = 85200 if Vehicle == "Audi A8"
replace msrp2020 = 52530 if Vehicle == "Ford Explorer"
replace msrp2020 = (90900 + 96150) / 2 if Vehicle == "Land Rover Range Rover"
replace msrp2020 = 53000 if Vehicle == "Acura MDX"

order Vehicle msrp2000 batt_cap2000 sales2000 msrp2001 batt_cap2001 sales2001 msrp2002 batt_cap2002 sales2002 msrp2003 sales2003 msrp2004 sales2004 msrp2005 sales2005 msrp2006 sales2006
gsort sales2000 sales2001 sales2002 sales2003 sales2004 sales2005 sales2006

replace msrp2000 = 20495 if Vehicle == "Honda Insight" // kbb
replace msrp2001 = 18980 if Vehicle == "Honda Insight"
replace msrp2001 = 19995 if Vehicle == "Toyota Prius"
replace msrp2002 = 19080 if Vehicle == "Honda Insight"
replace msrp2002 = 19995 if Vehicle == "Toyota Prius"
replace msrp2003 = 19080 if Vehicle == "Honda Insight"
replace msrp2003 = 19995 if Vehicle == "Toyota Prius"
replace msrp2004 = 19650 if Vehicle == "Honda Civic"
replace msrp2004 = 19180 if Vehicle == "Honda Insight"
replace msrp2004 = 20295 if Vehicle == "Toyota Prius"
replace msrp2005 = 26830 if Vehicle == "Ford Escape/Mercury Mariner"
replace msrp2005 = 19900 if Vehicle == "Honda Civic"
replace msrp2005 = 19330 if Vehicle == "Honda Insight"
replace msrp2005 = 21275 if Vehicle == "Toyota Prius"
replace msrp2006 = 44660 if Vehicle == "Lexus RX 450h"
replace msrp2006 = 30990 if Vehicle == "Honda Accord"
replace msrp2006 = 26900 if Vehicle == "Ford Escape/Mercury Mariner"
replace msrp2006 = 19330 if Vehicle == "Honda Insight"
replace msrp2006 = 21725 if Vehicle == "Toyota Prius"

order Vehicle sales2000 mpg2000 sales2001 mpg2001 sales2002 mpg2002 sales2003 mpg2003 sales2004 mpg2004 sales2005 mpg2005 sales2006 mpg2006
sort sales2006 sales2005 sales2004 sales2003 sales2002 sales2001 sales2000
drop if Vehicle == "Total"

order Vehicle sales2000 mpg2000 sales2001 mpg2001 sales2002 mpg2002 sales2003 mpg2003 sales2004 mpg2004 sales2005 mpg2005 sales2006 mpg2006 sales2020 mpg2020 source

replace mpg2000 = 53 if Vehicle == "Honda Insight"

replace mpg2001 = (53 + 47 + 47) / 3 if Vehicle == "Honda Insight"
replace mpg2001 = 41 if Vehicle == "Toyota Prius"

replace mpg2002 = (53 + 47) / 2 if Vehicle == "Honda Insight"
replace mpg2002 = 41 if Vehicle == "Toyota Prius"

replace mpg2003 = (53 + 47) / 2 if Vehicle == "Honda Insight"
replace mpg2003 = (41 + 41 + 40 + 40) / 4 if Vehicle == "Honda Civic"
replace mpg2003 = 41 if Vehicle == "Toyota Prius"

replace mpg2004 = (52 + 47) / 2 if Vehicle == "Honda Insight"
replace mpg2004 = (41 + 41 + 40 + 40) / 4 if Vehicle == "Honda Civic"
replace mpg2004 = 46 if Vehicle == "Toyota Prius"

order Vehicle sales2005 mpg2005 sales2006 mpg2006 sales2020 mpg2020 source 

replace mpg2005 = (52 + 47) / 2 if Vehicle == "Honda Insight"
replace mpg2005 = 28 if Vehicle == "Honda Accord"
replace mpg2005 = (29 + 27) / 2 if Vehicle == "Ford Escape/Mercury Mariner"
replace mpg2005 = (41 + 41 + 40 + 40) / 4 if Vehicle == "Honda Civic"
replace mpg2005 = 46 if Vehicle == "Toyota Prius"

replace mpg2006 = (52 + 47) / 2 if Vehicle == "Honda Insight"
replace mpg2006 = 25 if Vehicle == "Honda Accord"
replace mpg2006 = (27 + 26) / 2 if Vehicle == "Lexus RX 450h"
replace mpg2006 = (29 + 27) / 2 if Vehicle == "Ford Escape/Mercury Mariner"
replace mpg2006 = 42 if Vehicle == "Honda Civic"
replace mpg2006 = (27 + 26) / 2 if Vehicle == "Toyota Highlander"
replace mpg2006 = 46 if Vehicle == "Toyota Prius"

sort sales2020

replace mpg2020 = 24 if Vehicle == "Audi A7"
replace mpg2020 = 30 if Vehicle == "Lexus LC500h"
replace mpg2020 = (28 + 26) / 2 if Vehicle == "Lexus LS 500h"
replace mpg2020 = (21 + 21 + 20) / 3 if Vehicle == "Jeep Wrangler"
replace mpg2020 = (21 + 18) / 2 if Vehicle == "Audi A8"
replace mpg2020 = 21 if Vehicle == "Acura NSX"
replace mpg2020 = 28 if Vehicle == "Acura RLX"
replace mpg2020 = 42 if Vehicle == "Kia Optima"
replace mpg2020 = (21 + 21) / 2 if Vehicle == "Land Rover Range Rover"
replace mpg2020 = 27 if Vehicle == "Acura MDX Hybrid"
replace mpg2020 = (28 + 26) / 2 if Vehicle == "Lexus LS 500h"
replace mpg2020 = 41 if Vehicle == "Lincoln MKZ"
replace mpg2020 = (52 + 47) / 2 if Vehicle == "Hyundai Sonata"
replace mpg2020 = (44 + 43) / 2 if Vehicle == "Toyota Avalon"
replace mpg2020 = 44 if Vehicle == "Lexus ES"
replace mpg2020 = (28 + 25) / 2 if Vehicle == "Ford Explorer"
replace mpg2020 = 31 if Vehicle == "Lexus NX Hybrid"
replace mpg2020 = (42 + 39) / 2 if Vehicle == "Lexus UX"
replace mpg2020 = (58 + 55) / 2 if Vehicle == "Hyundai Ioniq Hybrid"
replace mpg2020 = (30 + 29) / 2 if Vehicle == "Lexus RX 450h"
replace mpg2020 = (50 + 49 + 43) / 3 if Vehicle == "Kia Niro"
replace mpg2020 = (52 + 48) / 2 if Vehicle == "Honda Insight"
replace mpg2020 = 52 if Vehicle == "Toyota Corolla"
replace mpg2020 = 48 if Vehicle == "Honda Accord"
replace mpg2020 = (42 + 41) / 2 if Vehicle == "Ford Fusion & Milan"
replace mpg2020 = (41 + 40) / 2 if Vehicle == "Ford Escape/Mercury Mariner"
replace mpg2020 = (52 + 46) / 2 if Vehicle == "Toyota Camry"
replace mpg2020 = (56 + 52 + 50 + 46) / 4 if Vehicle == "Toyota Prius"
replace mpg2020 = (36 + 35 + 35) / 3 if Vehicle == "Toyota Highlander"
replace mpg2020 = 40 if Vehicle == "Toyota RAV4"


forv i = 1999(1)2020{
	gen sales_msrp`i' = sales`i'
	gen sales_mpg`i' = sales`i'
	ren sales`i' sales_batt_cap`i'
	replace sales_msrp`i' = 0 if missing(msrp`i')
	replace sales_mpg`i' = 0 if missing(mpg`i')
	replace sales_batt_cap`i' = 0 if missing(batt_cap`i')
}

drop if Vehicle == "Total"

forv i = 1999(1)2020{
	egen msrp_N`i' = total(sales_msrp`i')
	egen batt_cap_N`i' = total(sales_batt_cap`i')
	egen mpg_N`i' = total(sales_mpg`i')
	egen msrp_weighted_avg`i' = total(sales_msrp`i' * msrp`i')
	replace msrp_weighted_avg`i' = msrp_weighted_avg`i' / msrp_N`i'
	egen batt_cap_weighted_avg`i' = total(sales_batt_cap`i' * batt_cap`i')
	replace batt_cap_weighted_avg`i' = batt_cap_weighted_avg`i' / batt_cap_N`i'
	egen mpg_weighted_avg`i' = total(sales_mpg`i' * mpg`i')
	replace mpg_weighted_avg`i' = mpg_weighted_avg`i' / mpg_N`i'
}

duplicates drop batt_cap_weighted_avg2001 batt_cap_weighted_avg2002, force

reshape long batt_cap_weighted_avg msrp_weighted_avg mpg_weighted_avg, i(Vehicle) j(year)
keep year batt_cap_weighted* msrp_weighted* mpg_weighted*

ren msrp_weighted_avg msrp
ren batt_cap_weighted_avg batt_cap 
ren mpg_weighted_avg mpg 
gen mpg_cf = 1 / ((1 / mpg) - -0.000011 * 100) // formula and -0.000011 come from Muehlegger & Rapson (2023), assuming difference between HEV mpg and counterfactual mpg is the same over time

save "${code_files}/1_assumptions/evs/processed/hev_data.dta", replace


















