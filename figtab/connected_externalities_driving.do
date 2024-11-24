****************************************************
/* Purpose: Calculate and Append Vehicle Externalities (All $/Gal Terms) */
****************************************************
local output_path "${output_fig}/figures_appendix"
local output_path_table "${output_tab}/tables_appendix"

use "${user_specific_assumptions}/files_v${user_name}/Gasoline Externalities/gasoline_vehicle_externalities_${scc_ind_name}_${dr_ind_name}.dta", clear

levelsof year, local(year_loop)
foreach y of local year_loop {
	
	ds year mpg, not
	foreach var in `r(varlist)' {
		
		replace `var' = `var' * (${cpi_2020}/${cpi_`y'}) if year == `y'
		
	}
} 

gen base = 0
gen global_pollution = wtp_global
gen local_driving = wtp_global + wtp_congestion + wtp_accidents
gen local_pollution = wtp_total

merge 1:1 year using "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", keep(3) nogen

preserve

	keep year base local_pollution local_driving global_pollution wtp_total avg_tax_rate
		
	foreach y of local year_loop {
		
		replace avg_tax_rate = avg_tax_rate * (${cpi_2020}/${cpi_`y'}) if year == `y'
		
	}

	tw /// 
		(rarea base global_pollution year, color("214 118 72")) ///
		(rarea global_pollution local_driving year, color("115 175 235%50")) ///
		(rarea local_driving local_pollution year, color("115 175 235")) /// 
		(line wtp_total year, color("21 26 33") lwidth(medium)) ///
		(line avg_tax_rate year, color("8 51 97") lwidth(medium) lpattern(shortdash)) ///
		, ///
			ytitle("Externality Value ($/Gallon)", size(medsmall)) ///
				ylab(0(1)4, nogrid format(%9.2f)) ///
				yscale(titlegap(+1) outergap(0)) ///
			xtitle("Year", size(medsmall)) ///
				xlab(1990(10)2020) ///
				xscale(titlegap(+4) outergap(0)) ///
				xsize(6) ///
			plotregion(margin(b=0 l=0)) ///
			graphregion(color(white)) ///
			legend(off)
	graph display, xsize(6) ysize(4)
	graph export "`output_path'/vehicle_externalities.png", replace

restore


* pull into a different file for Appendix Figure 12
* Generate Table A1 (Driving Externality Breakdown for Current Year) 
drop *local* *global*
keep year wtp*
keep if year == ${today_year}

reshape long wtp_ , i(year) j(component) str
rename wtp_ Estimate
rename component Externality


gen upstream_ind = 1 if substr(Externality, 1, 9) == "upstream_"
preserve	
	keep if upstream_ind == 1
	replace Externality = substr(Externality, 10, .)
	drop upstream_ind
	rename Estimate Estimate_Upstream
	
	tempfile upstream_remerge
	save "`upstream_remerge.dta'", replace
restore

drop if upstream_ind == 1
merge 1:1 Externality using "`upstream_remerge.dta'", nogen
drop upstream_ind

gen PM25_ind = 1 if substr(Externality, 1, 5) == "PM25_"
egen PM25_onroad = total(Estimate) if PM25_ind==1
sum PM25_onroad
local PM25_onroad_replace = r(mean)
replace Estimate = `PM25_onroad_replace' if Externality == "PM25"
drop PM25*

drop if inlist(Externality, "PM25_exhaust", "PM25_TBW")
drop year

insobs 1
replace Externality = "Pollution Total" if Externality == ""
insobs 1	
replace Externality = "Driving Total" if Externality == ""
	
replace Externality = "Accidents" if Externality == "accidents"	
replace Externality = "Congestion" if Externality == "congestion"	
replace Externality = "Total Vehicle Externality" if Externality == "total"	
replace Externality = "HC" if Externality == "VOC"	


gen table_order = .
replace table_order = 1 if Externality == "NH3"
replace table_order = 2 if Externality == "CO2"
replace table_order = 3 if Externality == "CO"
replace table_order = 4 if Externality == "HC"
replace table_order = 5 if Externality == "CH4"
replace table_order = 6 if Externality == "N2O"
replace table_order = 7 if Externality == "NOx"
replace table_order = 8 if Externality == "PM25"
replace table_order = 9 if Externality == "SO2"
replace table_order = 10 if Externality == "Pollution Total"

replace table_order = 11 if Externality == "Accidents"
replace table_order = 12 if Externality == "Congestion"
replace table_order = 13 if Externality == "Driving Total"

replace table_order = 14 if Externality	== "Total Vehicle Externality"
sort table_order
order Externality Estimate_Upstream Estimate


egen upstream_total = total(Estimate_Upstream) if inrange(table_order, 1, 9)
qui sum upstream_total
replace Estimate_Upstream = r(mean) if Externality == "Pollution Total"
drop upstream_total

egen onroad_total = total(Estimate) if inrange(table_order, 1, 9)
qui sum onroad_total
replace Estimate = r(mean) if Externality == "Pollution Total"
drop onroad_total

egen driving_total = total(Estimate) if inlist(Externality, "Accidents", "Congestion")
qui sum driving_total
replace Estimate = r(mean) if Externality == "Driving Total"
drop driving_total

rename Estimate Estimate_Onroad
egen Estimate_Total = rowtotal(Estimate_Onroad Estimate_Upstream)

egen total_check = total(Estimate_Total) if substr(Externality, -5, .) == "Total"
qui sum total_check
assert round(r(mean), 0.00001) == round(r(mean), 0.00001) if Externality == "Total Vehicle Externality"
drop total_check 

egen replace_onroad = total(Estimate_Onroad) if inlist(Externality, "Pollution Total", "Driving Total")  
qui sum replace_onroad 
replace Estimate_Onroad = r(mean) if Externality == "Total Vehicle Externality"
drop replace_onroad

qui sum Estimate_Upstream if Externality == "Pollution Total"
replace Estimate_Upstream = r(mean) if Externality == "Total Vehicle Externality"
	
egen total_row_check = rowtotal(Estimate_Onroad Estimate_Upstream)	
assert round(total_row_check, 0.0001) == round(Estimate_Total, 0.0001)
drop total_row_check

sort table_order
drop table_order	
		
export excel "`output_path_table'/Appendix Table Gas Externalities", first(var) sheet("data_export", replace) keepcellfmt