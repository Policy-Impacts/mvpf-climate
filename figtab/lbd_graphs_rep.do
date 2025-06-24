

local output_path ${output_fig}

import excel using "${output_tab}/tables_data/way_etal.xlsx", clear // Data downloaded from Way et al replication package

local bar_dark_blue = "8 51 97"


*********************
* Cleaning the data *
*********************

drop if !regexm(A, "^[0-9]{4}$")
ren A year
destring year, replace

ren B cum_prod_solar
ren C cost_solar
ren D cum_prod_wind
ren E cost_wind
ren F cum_prod_batt
ren G cost_batt 

drop H I J K L M

destring cum_prod_solar cost_solar cum_prod_wind cost_wind cum_prod_batt cost_batt, replace 

missings dropvars, force  
missings dropobs cum_prod_solar cost_solar cum_prod_wind cost_wind cum_prod_batt cost_batt, force 

*********************
*   Scatterplots    *
*********************

tw scatter cost_solar cum_prod_solar if year > 1975, ///
		   mcolor("`bar_dark_blue'") ///
		   xtitle("Cumulative Electricity Generated, TWh") ///
		   ytitle("LCOE, $/MWh") ///
		   yscale(log range(10 10000)) ///
		   xscale(log) ///
		   ylabel(10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}" 10000 "10{superscript:4}") ///
		   xlabel(0.001 "10{superscript:-3}" 0.01 "10{superscript:-2}" 0.1 "10{superscript:-1}" 1 "10{superscript:0}" 10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}" ///
		   		  10000 "10{superscript:4}")
		   
graph export "${output_fig}/figures_appendix/lbd_solar.png", replace 
cap graph export "${output_fig}/figures_appendix/lbd_solar.wmf", replace

tw scatter cost_wind cum_prod_wind if year > 1983, ///
		   mcolor("`bar_dark_blue'") ///
		   xtitle("Cumulative Electricity Generated, TWh") ///
		   ytitle("LCOE, $/MWh") ///
		   yscale(log) ///
		   xscale(log) ///
		   ylabel(10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}" 10000 "10{superscript:4}") ///
		   xlabel(1 "10{superscript:0}" 10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}" ///
		   		  10000 "10{superscript:4}")

graph export "${output_fig}/figures_appendix/lbd_wind.png", replace
cap graph export "${output_fig}/figures_appendix/lbd_wind.wmf", replace


tw scatter cost_batt cum_prod_batt if year > 1995, ///
		   mcolor("`bar_dark_blue'") ///
		   xtitle("Cumulative Production, GWh") ///
		   ytitle("Cost, $/kWh") ///
		   yscale(log) ///
		   xscale(log) ///
		   ylabel(10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}" 10000 "10{superscript:4}") ///
		   xlabel(1 "10{superscript:0}" 10 "10{superscript:1}" 100 "10{superscript:2}" 1000 "10{superscript:3}")

graph export "${output_fig}/figures_appendix/lbd_batt.png", replace
cap graph export "${output_fig}/figures_appendix/lbd_batt.wmf", replace
