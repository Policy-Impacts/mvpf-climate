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

import excel using "${code_files}/1_assumptions/evs/battery_costs_zt.xlsx", clear first sheet("RepreSeries_MarketSize_All_MWh")

ren IndependentAxisData year
ren DependentAxisData marg_sales
label variable marg_sales "MWh"

keep year marg_sales

save "${code_files}/1_assumptions/evs/processed/battery_marg_sales_zt", replace

import excel using "${code_files}/1_assumptions/evs/marg_batt_sales_2016_2022_statista", clear first sheet("Data")

ren EVlithiumionbatterydemandwo year
ren C china
ren D europe
ren E us
ren F other

drop if strpos(year,"from")
drop if missing(year)

destring year, replace
destring china, replace
destring europe, replace
destring us, replace
destring other, replace

egen marg_sales = rowtotal(china europe us other)
keep year marg_sales

replace marg_sales = marg_sales * 1000 // converting to MWh

append using "${code_files}/1_assumptions/evs/processed/battery_marg_sales_zt", gen(source)

sort year source
by year: gen diff = marg_sales[1] - marg_sales[2]

drop if year == 2016 & source == 0

sort year

gen cum_sales = sum(marg_sales)

save "${code_files}/1_assumptions/evs/processed/battery_sales_combined", replace