ssc install estout
ssc install outreg
local output_path ${output_tab}
import excel using "${output_tab}/tables_data/way_etal.xlsx", clear

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
*   Regressions     *
*********************



foreach tech in batt solar wind {

	gen ln_cost_`tech' = ln(cost_`tech')
	gen ln_cum_prod_`tech' = ln(cum_prod_`tech')

	gen marg_prod_`tech' = .
	local max = _N

	** Marginal Production **
	forvalues i = 1(1)`max' {
		replace marg_prod_`tech' = cum_prod_`tech'[`i'] - cum_prod_`tech'[`i' - 1] in `i'
	}

	** Cumulative production only up through t-1
	forvalues i = 1(1)`max' {
		replace cum_prod_`tech' = cum_prod_`tech'[`i'] - marg_prod_`tech'[`i'] in `i'
	}

	replace ln_cum_prod_`tech' = ln(cum_prod_`tech')
	gen ln_marg_prod_`tech' = ln(marg_prod_`tech')

	** preferred estimate & sample
	reg ln_cost_`tech' ln_cum_prod_`tech' if cum_prod_`tech' > 1
	est store `tech'1
	local `tech'_cum_1 = round(_b[ln_cum_prod_`tech'], 0.001)

	reg ln_cost_`tech' ln_cum_prod_`tech' ln_marg_prod_`tech' if cum_prod_`tech' > 1
	est store `tech'2
	local `tech'_cum_2 = round(_b[ln_cum_prod_`tech'], 0.001)
	local `tech'_marg_2 = round(_b[ln_marg_prod_`tech'], 0.001)

	reg ln_cost_`tech' ln_cum_prod_`tech' ln_marg_prod_`tech' year if cum_prod_`tech' > 1
	est store `tech'3
	local `tech'_cum_3 = round(_b[ln_cum_prod_`tech'], 0.001)
	local `tech'_marg_3 = round(_b[ln_marg_prod_`tech'], 0.001)
	local `tech'_year_3 = round(_b[year], 0.001)

}

esttab wind1 wind2 wind3 solar1 solar2 solar3 batt1 batt2 batt3 ///
    using "${output_tab}/tables_appendix/way_et_all_table.tex", ///
    keep(ln_cum_prod_wind ln_marg_prod_wind ln_cum_prod_solar ln_marg_prod_solar ln_cum_prod_batt ln_marg_prod_batt year) ///
    order(ln_cum_prod_wind ln_marg_prod_wind year) ///
    label ///
    varlabels(ln_cum_prod_wind "Log Cum. Sales" ln_marg_prod_wind "Log Marg. Sales" year "Year Effect") ///
    collabels(none) ///
    nonumber ///
	se ///
	nostar ///
	replace



mat results = (`wind_cum_1', `wind_cum_2', `wind_cum_3', `solar_cum_1', `solar_cum_2', `solar_cum_3', `batt_cum_1', `batt_cum_2', `batt_cum_3' \ ///
				0, `wind_marg_2', `wind_marg_3', 0, `solar_marg_2', `solar_marg_3', 0, `batt_marg_2', `batt_marg_3' \ ///
				0, 0, `wind_year_3', 0, 0, `solar_year_3', 0, 0, `batt_year_3')

mat li results


frmttable using "${output_tab}/tables_appendix/Appendix_Table1.tex", ///
			replay(results) ///
			statmat(results) /// 
			store(results) /// 
			sdec(3) ///
			sfmt(f,f,f,f,f,f,f,f,f,f,f,f) ///
			tex ///
			ctitles("", "(1)", "(2)", "(3)", "(4)", "(5)", "(6)", "(7)", "(8)", "(9)") ///
			rtitles("Log Cum. Sales"\ "Log Marg. Sales"\ "Year") ///
			spaceht(2) ///
			replace

