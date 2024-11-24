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

*** First using the 2011-2019 data from the DoE

import excel using "${code_files}/1_assumptions/evs/ev_sales_by_model.xlsx", clear first

drop if _n == 1
ren B vehicle
ren C type
ren D sales2011
ren E sales2012
ren F sales2013
ren G sales2014
ren H sales2015
ren I sales2016
ren J sales2017
ren K sales2018
ren L sales2019
ren M total_sales
drop if _n == 1

missings dropvars, force
drop if _n > 56

drop if type == "PHEV"
destring total_sales, replace
gen old_id = _n

tempfile evs201119
sa `evs201119'

*** Now pulling in the Q4 2021 KBB report that has 2020 sales by EV model

import excel using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.xlsx", sheet("Table 2") cellrange(A3:G29) first clear
ren A vehicle
ren B sales_q4_2021
ren C sales_q4_2020
ren YOY q4_diff_20_21
drop E 
ren F sales2021
ren G sales2020

replace sales2020 = "" if sales2020 == "-"
replace sales_q4_2020 = "" if sales_q4_2020 == "-"
replace q4_diff_20_21 = "" if q4_diff_20_21 == "-"
destring sales2020, replace
destring sales_q4_2020, replace
destring q4_diff_20_21, replace
drop if missing(sales_q4_2020)

gen new_id = _n

reclink vehicle using `evs201119', idmaster(new_id) idusing(old_id) gen(match)
order vehicle Uvehicle match _merge sales2011 sales2012 sales2013 sales2014 sales2015 sales2016 sales2017 sales2018 sales2019 sales2020 sales2021
replace Uvehicle = "" if match == 1

append using `evs201119', gen(source)
replace vehicle = Uvehicle if !missing(Uvehicle)
duplicates tag vehicle sales2019, gen(dup)
drop if dup == 1 & source == 1

drop Uvehicle
drop if vehicle == "Total"
drop match _merge new_id old_id type source dup

*** Manually entering energy consumption and MSRP data from fueleconomy.gov
* If there are multiple trims for a given model, I calculate a simple average of the energy consumption.
* For MSRP, fueleconomy.gov reports a range, so I take the mean of that range and if there are multiple trims, I calculate a simple average of those means.
* Assuming that the MSRPs on fueleconomy.gov are in nominal dollars (i.e. that the MSRP for a 2018 vehicle is in 2018$)


*** Also manually entering battery consumption from Edmunds

forvalues y = 2011(1)2020{
    gen kwh_per_mile`y' = .
    gen msrp`y' = .
    gen batt_cap`y' = .
}

order vehicle sales2011 kwh_per_mile2011 msrp2011 batt_cap2011
local i = 2011
forvalues y = 2012(1)2020{
    order sales`y' kwh_per_mile`y' msrp`y' batt_cap`y', after(batt_cap`i')
    local ++i
}

gsort -sales2011 -sales2012 -sales2013 -sales2014 -sales2015 -sales2016 -sales2017 -sales2018 -sales2019 -sales2020


replace kwh_per_mile2019 = (46 / 100) if vehicle == "Audi e-tron"
replace msrp2019 = ((74800 + 81800) / 2) if vehicle == "Audi e-tron"
replace batt_cap2019 = 95 if vehicle == "Audi e-tron"

replace kwh_per_mile2020 = (44 / 100) if vehicle == "Audi e-tron"
replace msrp2020 = ((77400 + 83400) / 2) if vehicle == "Audi e-tron"
replace batt_cap2020 = 95 if vehicle == "Audi e-tron"


replace kwh_per_mile2011 = (33 / 100) if vehicle == "BMW Active E"


replace kwh_per_mile2020 = (((30 + 30) / 2) / 100) if vehicle == "BMW i3"
replace msrp2020 = ((44450 + 48300 + 47650 + 51500) / 4) if vehicle == "BMW i3"
replace batt_cap2020 = 42 if vehicle == "BMW i3"

replace kwh_per_mile2019 = (((30 + 30) / 2) / 100) if vehicle == "BMW i3"
replace batt_cap2019 = 42 if vehicle == "BMW i3"

replace kwh_per_mile2018 = (((29 + 30) / 2) / 100) if vehicle == "BMW i3"
replace msrp2018 = (44450 + 47650) / 2 if vehicle == "BMW i3"
replace batt_cap2018 = 33 if vehicle == "BMW i3"

replace kwh_per_mile2017 = (((27 + 29) / 2) / 100) if vehicle == "BMW i3"
replace msrp2017 = (42400 + 44450) / 2 if vehicle == "BMW i3"

replace kwh_per_mile2016 = (27 / 100) if vehicle == "BMW i3"
replace msrp2016 = 42400 if vehicle == "BMW i3"
replace batt_cap2016 = 22 if vehicle == "BMW i3"

replace kwh_per_mile2015 = (27 / 100) if vehicle == "BMW i3"
replace msrp2015 = 42400 if vehicle == "BMW i3"
replace batt_cap2015 = 22 if vehicle == "BMW i3"

replace kwh_per_mile2014 = (27 / 100) if vehicle == "BMW i3"
replace msrp2014 = 41350 if vehicle == "BMW i3"
replace batt_cap2014 = 22 if vehicle == "BMW i3"


replace kwh_per_mile2020 = (29 / 100) if vehicle == "Chevy Bolt"
replace msrp2020 = (36620 + 41020) / 2 if vehicle == "Chevy Bolt"
replace batt_cap2020 = 66 if vehicle == "Chevy Bolt"

replace kwh_per_mile2019 = (28 / 100) if vehicle == "Chevy Bolt"
replace msrp2019 = (36620 + 41020) / 2 if vehicle == "Chevy Bolt"
replace batt_cap2019 = 60 if vehicle == "Chevy Bolt"

replace kwh_per_mile2018 = (28 / 100) if vehicle == "Chevy Bolt"
replace batt_cap2018 = 60 if vehicle == "Chevy Bolt"

replace kwh_per_mile2017 = (28 / 100) if vehicle == "Chevy Bolt"
replace msrp2017 = (36620 + 40905) / 2 if vehicle == "Chevy Bolt"
replace batt_cap2017 = 60 if vehicle == "Chevy Bolt"


replace kwh_per_mile2016 = (28 / 100) if vehicle == "Chevy Spark"
replace msrp2016 = (25120 + 25510) / 2 if vehicle == "Chevy Spark"
replace batt_cap2016 = 18.4 if vehicle == "Chevy Spark"

replace kwh_per_mile2015 = (28 / 100) if vehicle == "Chevy Spark"
replace msrp2015 = (25170 + 25560) / 2 if vehicle == "Chevy Spark"
replace batt_cap2015 = 18.4 if vehicle == "Chevy Spark"

replace kwh_per_mile2014 = (28 / 100) if vehicle == "Chevy Spark"
replace msrp2014 = (26685 + 27010) / 2 if vehicle == "Chevy Spark"


replace kwh_per_mile2019 = (30 / 100) if vehicle == "Fiat 500E"
replace msrp2019 = 33210 if vehicle == "Fiat 500E"
replace batt_cap2019 = 24 if vehicle == "Fiat 500E"

replace kwh_per_mile2018 = (30 / 100) if vehicle == "Fiat 500E"
replace msrp2018 = 32995 if vehicle == "Fiat 500E"
replace batt_cap2018 = 24 if vehicle == "Fiat 500E"

replace kwh_per_mile2017 = (30 / 100) if vehicle == "Fiat 500E"
replace msrp2017 = 31800 if vehicle == "Fiat 500E"
replace batt_cap2017 = 24 if vehicle == "Fiat 500E"

replace kwh_per_mile2016 = (30 / 100) if vehicle == "Fiat 500E"
replace msrp2016 = 31800 if vehicle == "Fiat 500E"
replace batt_cap2016 = 24 if vehicle == "Fiat 500E"

replace kwh_per_mile2015 = (29 / 100) if vehicle == "Fiat 500E"
replace msrp2015 = 31800 if vehicle == "Fiat 500E"

replace kwh_per_mile2014 = (29 / 100) if vehicle == "Fiat 500E"
replace msrp2014 = 31800 if vehicle == "Fiat 500E"
replace batt_cap2014 = 24 if vehicle == "Fiat 500E"

replace kwh_per_mile2013 = (29 / 100) if vehicle == "Fiat 500E"
replace msrp2013 = 31800 if vehicle == "Fiat 500E"
replace batt_cap2013 = 24 if vehicle == "Fiat 500E"


replace kwh_per_mile2018 = (31 / 100) if vehicle == "Ford Focus EV"
replace msrp2018 = 29120 if vehicle == "Ford Focus EV"

replace kwh_per_mile2017 = (31 / 100) if vehicle == "Ford Focus EV"
replace msrp2017 = 29120 if vehicle == "Ford Focus EV"

replace kwh_per_mile2016 = (32 / 100) if vehicle == "Ford Focus EV"
replace msrp2016 = 29170 if vehicle == "Ford Focus EV"

replace kwh_per_mile2015 = (32 / 100) if vehicle == "Ford Focus EV"
replace msrp2015 = 29170 if vehicle == "Ford Focus EV"

replace kwh_per_mile2014 = (32 / 100) if vehicle == "Ford Focus EV"
replace msrp2014 = 29170 if vehicle == "Ford Focus EV"

replace kwh_per_mile2013 = (32 / 100) if vehicle == "Ford Focus EV"
replace msrp2013 = 39200 if vehicle == "Ford Focus EV"

replace kwh_per_mile2012 = (32 / 100) if vehicle == "Ford Focus EV"
replace msrp2012 = 39200 if vehicle == "Ford Focus EV"


replace kwh_per_mile2019 = (30 / 100) if vehicle == "Honda Clarity BEV"
replace msrp2019 = 36620 if vehicle == "Honda Clarity BEV"

replace kwh_per_mile2018 = (30 / 100) if vehicle == "Honda Clarity BEV"
replace msrp2018 = 36620 if vehicle == "Honda Clarity BEV"

replace kwh_per_mile2017 = (30 / 100) if vehicle == "Honda Clarity BEV"


replace kwh_per_mile2014 = (29 / 100) if vehicle == "Honda Fit EV"
replace msrp2014 = 36625 if vehicle == "Honda Fit EV"

replace kwh_per_mile2013 = (29 / 100) if vehicle == "Honda Fit EV"
replace msrp2013 = 36625 if vehicle == "Honda Fit EV"
replace batt_cap2013 = 20 if vehicle == "Honda Fit EV"

replace kwh_per_mile2020 = (25 / 100) if vehicle == "Hyundai Ioniq EV"
replace msrp2020 = (33045 + 38615) / 2 if vehicle == "Hyundai Ioniq EV"
replace batt_cap2020 = 38.3 if vehicle == "Hyundai Ioniq EV"

replace kwh_per_mile2019 = (25 / 100) if vehicle == "Hyundai Ioniq EV"
replace msrp2019 = (30315 + 36815) / 2 if vehicle == "Hyundai Ioniq EV"
replace batt_cap2019 = 28 if vehicle == "Hyundai Ioniq EV"

replace kwh_per_mile2018 = (25 / 100) if vehicle == "Hyundai Ioniq EV"
replace msrp2018 = (29500 + 36000) / 2 if vehicle == "Hyundai Ioniq EV"
replace batt_cap2018 = 28 if vehicle == "Hyundai Ioniq EV"

replace kwh_per_mile2017 = (25 / 100) if vehicle == "Hyundai Ioniq EV"
replace msrp2017 = (29500 + 32500) / 2 if vehicle == "Hyundai Ioniq EV"
replace batt_cap2017 = 28 if vehicle == "Hyundai Ioniq EV"


replace kwh_per_mile2020 = (27 / 100) if vehicle == "Hyundai Kona Electric"
replace msrp2020 = (37190 + 45400) / 2 if vehicle == "Hyundai Kona Electric"
replace batt_cap2020 = 64 if vehicle == "Hyundai Kona Electric"

replace kwh_per_mile2019 = (28 / 100) if vehicle == "Hyundai Kona Electric"
replace msrp2019 = (36950 + 44900) / 2 if vehicle == "Hyundai Kona Electric"
replace batt_cap2019 = 64 if vehicle == "Hyundai Kona Electric"


replace kwh_per_mile2020 = (44 / 100) if vehicle == "Jaguar I-Pace"
replace msrp2020 = (69850 + 80900) / 2 if vehicle == "Jaguar I-Pace"
replace batt_cap2020 = 90 if vehicle == "Jaguar I-Pace"

replace kwh_per_mile2019 = (44 / 100) if vehicle == "Jaguar I-Pace"
replace msrp2019 = (69500 + 85900) / 2 if vehicle == "Jaguar I-Pace"
replace batt_cap2020 = 90 if vehicle == "Jaguar I-Pace"


replace kwh_per_mile2020 = (30 / 100) if vehicle == "Kia Niro EV"
replace msrp2020 = (39090 + 44590) / 2 if vehicle == "Kia Niro EV"
replace batt_cap2020 = 64 if vehicle == "Kia Niro EV"

replace kwh_per_mile2019 = (30 / 100) if vehicle == "Kia Niro EV"
replace msrp2019 = (38500 + 44000) / 2 if vehicle == "Kia Niro EV"
replace batt_cap2019 = 64 if vehicle == "Kia Niro EV"


replace kwh_per_mile2020 = (29 / 100) if vehicle == "Kia Soul EV"

replace kwh_per_mile2019 = (31 / 100) if vehicle == "Kia Soul EV"
replace msrp2019 = (33950 + 35950) / 2 if vehicle == "Kia Soul EV"
replace batt_cap2019 = 30 if vehicle == "Kia Soul EV"

replace kwh_per_mile2018 = (31 / 100) if vehicle == "Kia Soul EV"
replace batt_cap2018 = 30 if vehicle == "Kia Soul EV"

replace kwh_per_mile2017 = (32 / 100) if vehicle == "Kia Soul EV"
replace msrp2017 = (32250 + 35950) / 2 if vehicle == "Kia Soul EV"
replace batt_cap2017 = 27 if vehicle == "Kia Soul EV"

replace kwh_per_mile2016 = (32 / 100) if vehicle == "Kia Soul EV"
replace msrp2016 = (31950 + 35950) / 2 if vehicle == "Kia Soul EV"
replace batt_cap2016 = 27 if vehicle == "Kia Soul EV"

replace kwh_per_mile2015 = (32 / 100) if vehicle == "Kia Soul EV"
replace msrp2015 = (33700 + 35700) / 2 if vehicle == "Kia Soul EV"
replace batt_cap2015 = 27 if vehicle == "Kia Soul EV"


replace kwh_per_mile2017 = (40 / 100) if vehicle == "Mercedes B-Class (B250e)"
replace batt_cap2017 = 28 if vehicle == "Mercedes B-Class (B250e)"

replace kwh_per_mile2016 = (40 / 100) if vehicle == "Mercedes B-Class (B250e)"
replace msrp2016 = 41450 if vehicle == "Mercedes B-Class (B250e)"
replace batt_cap2016 = 28 if vehicle == "Mercedes B-Class (B250e)"

replace kwh_per_mile2015 = (40 / 100) if vehicle == "Mercedes B-Class (B250e)"
replace msrp2015 = 41450 if vehicle == "Mercedes B-Class (B250e)"
replace batt_cap2015 = 28 if vehicle == "Mercedes B-Class (B250e)"

replace kwh_per_mile2014 = (40 / 100) if vehicle == "Mercedes B-Class (B250e)"
replace msrp2014 = 41450 if vehicle == "Mercedes B-Class (B250e)"
replace batt_cap2017 = 28 if vehicle == "Mercedes B-Class (B250e)"


replace kwh_per_mile2020 = (31 / 100) if vehicle == "Mini Cooper"
replace msrp2020 = 29900 if vehicle == "Mini Cooper"


replace kwh_per_mile2017 = (30 / 100) if vehicle == "Mitsubishi I EV"
replace batt_cap2017 = 16 if vehicle == "Mitsubishi I EV"

replace kwh_per_mile2016 = (30 / 100) if vehicle == "Mitsubishi I EV"
replace msrp2016 = 22995 if vehicle == "Mitsubishi I EV"
replace batt_cap2016 = 16 if vehicle == "Mitsubishi I EV"

replace kwh_per_mile2014 = (30 / 100) if vehicle == "Mitsubishi I EV"
replace msrp2014 = 22995 if vehicle == "Mitsubishi I EV"
replace batt_cap2014 = 16 if vehicle == "Mitsubishi I EV"

replace kwh_per_mile2013 = (30 / 100) if vehicle == "Mitsubishi I EV"

replace kwh_per_mile2012 = (30 / 100) if vehicle == "Mitsubishi I EV"
replace msrp2012 = (29125 + 31125) / 2 if vehicle == "Mitsubishi I EV"
replace batt_cap2012 = 16 if vehicle == "Mitsubishi I EV"


replace kwh_per_mile2020 = (((30 + 31 + 32) / 3) / 100) if vehicle == "Nissan Leaf"
replace msrp2020 = (31600 + 38200 + 34190 + 43900) / 4 if vehicle == "Nissan Leaf"
replace batt_cap2020 = (40 + 60) / 2 if vehicle == "Nissan Leaf"

replace kwh_per_mile2019 = (((30 + 31 + 32) / 3) / 100) if vehicle == "Nissan Leaf"
replace msrp2019 = (29990 + 36200 + 36550 + 38510 + 42550) / 5 if vehicle == "Nissan Leaf"
replace batt_cap2019 = (40 + 60) / 2 if vehicle == "Nissan Leaf"

replace kwh_per_mile2018 = (30 / 100) if vehicle == "Nissan Leaf"
replace msrp2018 = (29990 + 36200) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2018 = 40 if vehicle == "Nissan Leaf"

replace kwh_per_mile2017 = (30 / 100) if vehicle == "Nissan Leaf"
replace msrp2017 = (30680 + 36790) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2017 = 30 if vehicle == "Nissan Leaf"

replace kwh_per_mile2016 = (((30 + 30) / 2) / 100) if vehicle == "Nissan Leaf"
replace msrp2016 = (29010 + 36790 + 29010 + 36790) / 4 if vehicle == "Nissan Leaf"
replace batt_cap2016 = (24 + 30 + 30) / 3 if vehicle == "Nissan Leaf"

replace kwh_per_mile2015 = (30 / 100) if vehicle == "Nissan Leaf"
replace msrp2015 = (29010 + 35120) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2015 = 24 if vehicle == "Nissan Leaf"

replace kwh_per_mile2014 = (30 / 100) if vehicle == "Nissan Leaf"
replace msrp2014 = (28980 + 35020) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2014 = 24 if vehicle == "Nissan Leaf"

replace kwh_per_mile2013 = (29 / 100) if vehicle == "Nissan Leaf"
replace msrp2013 = (28800 + 34840) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2013 = 24 if vehicle == "Nissan Leaf"

replace kwh_per_mile2012 = (34 / 100) if vehicle == "Nissan Leaf"
replace msrp2012 = (35200 + 37250) / 2 if vehicle == "Nissan Leaf"
replace batt_cap2012 = 24 if vehicle == "Nissan Leaf"

replace kwh_per_mile2011 = (34 / 100) if vehicle == "Nissan Leaf"
replace msrp2011 = 32780 if vehicle == "Nissan Leaf"
replace batt_cap2011 = 24 if vehicle == "Nissan Leaf"


replace kwh_per_mile2020 = (((49 + 49 + 50) / 3) / 100) if vehicle == "Porsche Taycan"
replace msrp2020 = (103800 + 150900 + 185000) / 3 if vehicle == "Porsche Taycan"
replace batt_cap2020 = (79 + 93 + 93) / 3 if vehicle == "Porsche Taycan"


replace kwh_per_mile2019 = (((33 + 31) / 2) / 100) if vehicle == "Smart ED"
replace msrp2019 = (23900 + 26740) / 2 if vehicle == "Smart ED"
replace batt_cap2019 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2018 = (((33 + 31) / 2) / 100) if vehicle == "Smart ED"
replace msrp2018 = (28100 + 29100 + 23800 + 26640) / 4 if vehicle == "Smart ED"
replace batt_cap2018 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2017 = (((33 + 31) / 2) / 100) if vehicle == "Smart ED"
replace batt_cap2017 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2016 = (((32 + 32) / 2) / 100) if vehicle == "Smart ED"
replace batt_cap2016 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2015 = (((32 + 32) / 2) / 100) if vehicle == "Smart ED"
replace msrp2015 = (28000 + 25000) / 2 if vehicle == "Smart ED"
replace batt_cap2015 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2014 = (((32 + 32) / 2) / 100) if vehicle == "Smart ED"
replace msrp2014 = (28000 + 25000) / 2 if vehicle == "Smart ED"
replace batt_cap2014 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2013 = (((32 + 32) / 2) / 100) if vehicle == "Smart ED"
replace msrp2013 = (28000 + 25000) / 2 if vehicle == "Smart ED"
replace batt_cap2015 = 17.6 if vehicle == "Smart ED"

replace kwh_per_mile2011 = (((39 + 39) / 2) / 100) if vehicle == "Smart ED"


replace kwh_per_mile2020 = (((26 + 28 + 28 + 29 + 30 + 27 + 26 + 24) / 8) / 100) if vehicle == "Tesla Model 3"
replace msrp2020 = (46990 + 54990 + 54990 + 54990 + 37990) / 5 if vehicle == "Tesla Model 3"

replace kwh_per_mile2019 = (((26 + 29 + 29 + 27 + 26 + 25) / 6) / 100) if vehicle == "Tesla Model 3"
replace msrp2019 = (43000 + 47990 + 56990 + 44000 + 35000 + 39490) / 6 if vehicle == "Tesla Model 3"

replace kwh_per_mile2018 = (((26 + 29 + 29 + 27) / 4) / 100) if vehicle == "Tesla Model 3"
replace msrp2018 = (49000 + 55000 + 64000) / 3 if vehicle == "Tesla Model 3"

replace kwh_per_mile2017 = (27 / 100) if vehicle == "Tesla Model 3"
replace msrp2017 = 44000 if vehicle == "Tesla Model 3"
replace batt_cap2017 = 80.5 if vehicle == "Tesla Model 3"


replace kwh_per_mile2020 = (((30 + 29 + 32 + 35 + 31) / 5) / 100) if vehicle == "Tesla Model S"
replace msrp2020 = (79990 + 69420 + 91990 + 91990) / 4 if vehicle == "Tesla Model S"
replace batt_cap2020 = 100 if vehicle == "Tesla Model S"

replace kwh_per_mile2019 = (((33 + 33 + 30 + 35 + 32 + 35 + 31) / 7) / 100) if vehicle == "Tesla Model S"
replace msrp2019 = (76000 + 79990 + 133000 + 99990 + 75000) / 5 if vehicle == "Tesla Model S"
replace batt_cap2019 = 100 if vehicle == "Tesla Model S"

replace kwh_per_mile2018 = (((33 + 33 + 34 + 35) / 4) / 100) if vehicle == "Tesla Model S"
replace msrp2018 = (94000 + 74500 + 74500 + 135000) / 4 if vehicle == "Tesla Model S"
replace batt_cap2018 = (75 + 100 + 100) / 3 if vehicle == "Tesla Model S"

replace kwh_per_mile2017 = (((34 + 34 + 33 + 32 + 33 + 32 + 35 + 35) / 8) / 100) if vehicle == "Tesla Model S"
replace msrp2017 = (68000 + 69500 + 92500 + 73000 + 74500 + 78200 + 134500 + 87500) / 8 if vehicle == "Tesla Model S"
replace batt_cap2017 = (60 + 60 + 75 + 75 + 90 + 100 + 100) / 7 if vehicle == "Tesla Model S"

replace kwh_per_mile2016 = (((34 + 38 + 34 + 38 + 38 + 32 + 33 + 33 + 34 + 33 + 35 + 36 + 35) / 13) / 100) if vehicle == "Tesla Model S"
replace msrp2016 = (66000 + 70000 + 74500 + 71000 + 79500 + 89500 + 134500 + 112000) / 8 if vehicle == "Tesla Model S"
replace batt_cap2016 = (60 + 75 + 60 + 75 + 90 + 90) / 6 if vehicle == "Tesla Model S"

replace kwh_per_mile2015 = (((35 + 38 + 38 + 33 + 34 + 34 + 36 + 36) / 7) / 100) if vehicle == "Tesla Model S"
replace msrp2015 = (69900 + 80000 + 75000 + 85000 + 105000) / 5 if vehicle == "Tesla Model S"
replace batt_cap2015 = (60 + 85 + 90 + 70 + 85 + 85 + 90 + 90) / 8 if vehicle == "Tesla Model S"

replace kwh_per_mile2014 = (((35 + 38 + 38) / 3) / 100) if vehicle == "Tesla Model S"
replace msrp2014 = (69900 + 79900 + 104500 + 79900) / 4 if vehicle == "Tesla Model S"
replace batt_cap2014 = (60 + 85 + 85 + 85) / 4 if vehicle == "Tesla Model S"

replace kwh_per_mile2013 = (((36 + 35 + 38) / 3) / 100) if vehicle == "Tesla Model S"
replace msrp2013 = (69900 + 94900) / 2 if vehicle == "Tesla Model S"
replace batt_cap2013 = (60 + 85) / 2 if vehicle == "Tesla Model S"

replace kwh_per_mile2012 = (38 / 100) if vehicle == "Tesla Model S"
replace msrp2012 = (59900 + 105400) / 2 if vehicle == "Tesla Model S"
replace batt_cap2012 = (40 + 60 + 85 + 85) / 4 if vehicle == "Tesla Model S"


replace kwh_per_mile2020 = (((35 + 32 + 38 + 43 + 33) / 5) / 100) if vehicle == "Tesla Model X"
replace msrp2020 = (84990 + 79990 + 99990 + 99990) / 4 if vehicle == "Tesla Model X"

replace kwh_per_mile2019 = (((39 + 36 + 35 + 40 + 43) / 5) / 100) if vehicle == "Tesla Model X"
replace msrp2019 = (97000 + 82000 + 84990 + 138000 + 104990) / 5 if vehicle == "Tesla Model X"

replace kwh_per_mile2018 = (((39 + 36 + 40) / 3) / 100) if vehicle == "Tesla Model X"
replace msrp2018 = (96000 + 79500 + 140000) / 3 if vehicle == "Tesla Model X"
replace batt_cap2018 = (75 + 100 + 100) / 3 if vehicle == "Tesla Model X"

replace kwh_per_mile2017 = (((39 + 36 + 36 + 37 + 39 + 38) / 6) / 100) if vehicle == "Tesla Model X"
replace msrp2017 = (100150 + 82500 + 93500 + 135500 + 117150 + 143950) / 6 if vehicle == "Tesla Model X"
replace batt_cap2017 = (75 + 90 + 100 + 100) / 4 if vehicle == "Tesla Model X"

replace kwh_per_mile2016 = (((36 + 36 + 37 + 39 + 38) / 5) / 100) if vehicle == "Tesla Model X"
replace msrp2016 = (83000 + 95500 + 136900 + 159000 + 115500) / 5 if vehicle == "Tesla Model X"
replace batt_cap2016 = (75 + 90 + 90) / 3 if vehicle == "Tesla Model X"


replace kwh_per_mile2020 = (((28 + 28 + 30) / 3) / 100) if vehicle == "Tesla Model Y"
replace msrp2020 = (48000 + 49990 + 59990) / 3 if vehicle == "Tesla Model Y"


replace kwh_per_mile2014 = (44 / 100) if vehicle == "Toyota RAV4 EV"
replace msrp2014 = 49800 if vehicle == "Toyota RAV4 EV"
replace batt_cap2014 = 41.8 if vehicle == "Toyota RAV4 EV"

replace kwh_per_mile2013 = (44 / 100) if vehicle == "Toyota RAV4 EV"
replace msrp2013 = 49800 if vehicle == "Toyota RAV4 EV"
replace batt_cap2013 = 41.8 if vehicle == "Toyota RAV4 EV"

replace kwh_per_mile2012 = (44 / 100) if vehicle == "Toyota RAV4 EV"
replace msrp2012 = 49800 if vehicle == "Toyota RAV4 EV"
replace batt_cap2012 = 41.8 if vehicle == "Toyota RAV4 EV"


replace kwh_per_mile2019 = (28 / 100) if vehicle == "VW e-Golf"
replace msrp2019 = (31895 + 38895) / 2 if vehicle == "VW e-Golf"
replace batt_cap2019 = 35.8 if vehicle == "VW e-Golf"

replace kwh_per_mile2018 = (28 / 100) if vehicle == "VW e-Golf"
replace msrp2018 = (30495 + 37345) / 2 if vehicle == "VW e-Golf"
replace batt_cap2018 = 35.8 if vehicle == "VW e-Golf"

replace kwh_per_mile2017 = (28 / 100) if vehicle == "VW e-Golf"
replace msrp2017 = (30495 + 36995) / 2 if vehicle == "VW e-Golf"
replace batt_cap2017 = 35.8 if vehicle == "VW e-Golf"

replace kwh_per_mile2016 = (29 / 100) if vehicle == "VW e-Golf"
replace msrp2016 = (28995 + 35595) / 2 if vehicle == "VW e-Golf"
replace batt_cap2016 = 24.2 if vehicle == "VW e-Golf"

replace kwh_per_mile2015 = (29 / 100) if vehicle == "VW e-Golf"
replace msrp2015 = (33450 + 35445) / 2 if vehicle == "VW e-Golf"
replace batt_cap2015 = 24.2 if vehicle == "VW e-Golf"

*****************************************
/* Calculating Sales-Weighted Averages */
*****************************************

forvalues y = 2011(1)2020{
    gen num`y' = sales`y' * kwh_per_mile`y'
    egen num2`y' = total(num`y')
    egen den`y' = total(sales`y') if !missing(kwh_per_mile`y') & kwh_per_mile`y' != 0
    gen avg_kwh_per_mile`y' = num2`y' / den`y'
    drop num`y' num2`y' den`y'
}

forvalues y = 2011(1)2020{
    gen num`y' = sales`y' * msrp`y'
    egen num2`y' = total(num`y')
    egen den`y' = total(sales`y') if !missing(msrp`y') & msrp`y' != 0
    gen avg_msrp`y' = num2`y' / den`y'
    drop num`y' num2`y' den`y'
}

forvalues y = 2011(1)2020{
    gen num`y' = sales`y' * batt_cap`y'
    egen num2`y' = total(num`y')
    egen den`y' = total(sales`y') if !missing(batt_cap`y') & batt_cap`y' != 0
    gen avg_batt_cap`y' = num2`y' / den`y'
    drop num`y' num2`y' den`y'
}

keep avg*
keep if _n == 1
gen n = _n
reshape long avg_kwh_per_mile avg_msrp avg_batt_cap, i(n) j(year)
drop n

save "${code_files}/1_assumptions/evs/processed/kwh_msrp_batt_cap", replace





































































