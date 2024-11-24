
******************************************************
/* Cleans data from Ziegler and Trancik on the cost of 
two different types of batteries over time */
******************************************************


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

import excel using "${code_files}/1_assumptions/evs/battery_costs_zt.xlsx", clear first sheet("RepreSeries_Price_cy")
ren IndependentAxisData year
ren DependentAxisData prod_cost_2018
label variable prod_cost "2018 dollars, per kWh"

keep year prod_cost_2018

save "${code_files}/1_assumptions/evs/processed/cyl_batt_costs_zt", replace

import excel using "${code_files}/1_assumptions/evs/battery_costs_doe", clear first 

ren USDepartmentofEnergyVehic year
ren B prod_cost_current
ren C prod_cost_2021
drop if strpos(year,"Fact")
drop if missing(year)
drop if strpos(year,"Estimated")
drop if strpos(year,"Year")
drop if strpos(year,"Note")
drop if strpos(year,"Sources")
drop if strpos(year,"estimation")
drop if strpos(year,"Merit")
drop if strpos(year,"merit")
drop if strpos(year,"node")
drop if strpos(year,"Medicine")
drop if strpos(year,"doi")

destring year, replace
destring prod_cost_current, replace
destring prod_cost_2021, replace

gen prod_cost_2018 = prod_cost_2021 * (${cpi_2018} / ${cpi_2021})

save "${code_files}/1_assumptions/evs/processed/clean_battery_costs_doe", replace

append using "${code_files}/1_assumptions/evs/processed/cyl_batt_costs_zt", gen(source)

sort year source
by year: gen diff = prod_cost_2018[1] - prod_cost_2018[2]

drop if year >= 2008 & year <= 2016 & source == 0

save "${code_files}/1_assumptions/evs/processed/cyl_batt_costs_combined", replace

import excel using "${code_files}/1_assumptions/evs/battery_costs_zt.xlsx", clear first sheet("RepreSeries_Price_All_Cells")
ren IndependentAxisData year
ren DependentAxisData prod_cost_2018
label variable prod_cost "2018 dollars, per kWh"

keep year prod_cost_2018

save "${code_files}/1_assumptions/evs/processed/all_cells_batt_costs_zt", replace

append using "${code_files}/1_assumptions/evs/processed/clean_battery_costs_doe", gen(source)

sort year source
by year: gen diff = prod_cost_2018[1] - prod_cost_2018[2]
drop if year >= 2008 & year <= 2018 & source == 0

save "${code_files}/1_assumptions/evs/processed/all_cells_batt_costs_combined", replace
