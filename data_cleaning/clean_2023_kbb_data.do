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

import excel using "${code_files}/1_assumptions/evs/kbb_ev_sales_q12023.xlsx", clear first sheet("Table 3")
ren ELECTRICVEHICLEMODEL vehicle

ren B sales2023q1
keep vehicle sales2023q1
drop if missing(vehicle)

drop if vehicle == "Total (Estimates)"
drop if vehicle == "Toyota Mirai"
drop if vehicle == "Hyundia Nexo"
drop if vehicle == "Honda Clarity"
drop if vehicle == "Total EV & FCEV (Estimates)"

tempfile q1
sa `q1'

import excel using "${code_files}/1_assumptions/evs/kbb_ev_sales_q22023.xlsx", clear first sheet("Table 3")
ren ELECTRICVEHICLEMODEL vehicle

ren B sales2023q2
keep vehicle sales2023q2
drop if missing(vehicle)

drop if vehicle == "Total (Estimates)"
drop if vehicle == "Toyota Mirai"
drop if vehicle == "Hyundia Nexo"
drop if vehicle == "Honda Clarity"
drop if vehicle == "Total EV & FCEV (Estimates)"

tempfile q2
sa `q2'

import excel using "${code_files}/1_assumptions/evs/kbb_ev_sales_q32023.xlsx", clear first sheet("Table 3")
ren ELECTRICVEHICLEMODEL vehicle

ren B sales2023q3
keep vehicle sales2023q3
drop if missing(vehicle)

drop if vehicle == "Total (Estimates)"
drop if vehicle == "Toyota Mirai"
drop if vehicle == "Hyundia Nexo"
drop if vehicle == "Honda Clarity"
drop if vehicle == "Total EV & FCEV (Estimates)"

tempfile q3
sa `q3'

import excel using "${code_files}/1_assumptions/evs/kbb_ev_sales_q42023.xlsx", clear first sheet("Table 3")
ren ELECTRICVEHICLEMODEL vehicle

ren B sales2023q4
keep vehicle sales2023q4
drop if missing(vehicle)

drop if vehicle == "Total (Estimates)"
drop if vehicle == "Toyota Mirai"
drop if vehicle == "Hyundai Nexo"
drop if vehicle == "Honda Clarity"
drop if vehicle == "Total EV & FCEV (Estimates)"

merge 1:1 vehicle using `q1'
drop _merge

merge 1:1 vehicle using `q2'
drop _merge

merge 1:1 vehicle using `q3'

replace sales2023q1 = "" if sales2023q1 == "-"
replace sales2023q2 = "" if sales2023q2 == "-"
replace sales2023q3 = "" if sales2023q3 == "-"
replace sales2023q4 = "" if sales2023q4 == "-"

destring(sales2023q1), replace
destring(sales2023q2), replace
destring(sales2023q3), replace
destring(sales2023q4), replace

egen sales2023 = rowtotal(sales2023q1 sales2023q2 sales2023q3 sales2023q4)
sort sales2023

ren vehicle Vehicle
drop _merge

replace Vehicle = "Chevy Bolt" if Vehicle == "Chevy Bolt EV/EUV"
replace Vehicle = "Hyundai Ioniq EV" if Vehicle == "Hyundai Ioniq"
replace Vehicle = "Hyundai Kona Electric" if Vehicle == "Hyundai Kona"
replace Vehicle = "Kia Niro EV" if Vehicle == "Kia Niro"
replace Vehicle = "Rivian EDV500" if Vehicle == "Rivian EDV500/700"

save "${code_files}/1_assumptions/evs/processed/kbb_ev_sales2023", replace