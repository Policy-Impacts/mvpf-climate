*Corr Plot for All Nudges
local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

*Setting the mode
local dollar_year = 2020
local mode = "baseline"
local profits = "yp"
local persistence = "`2'"
local same_grid = "no"
global make_plot = "`1'"

local discount = 0.02
local replacement = "marginal"

import excel "${output_fig}/figures_data/Nudge Estimates", first clear sheet("Compiled") // Metadata from HER RCTs manually compiled

*Clean Data
keep Utility State State_name Census_Region Type Utilitytype Baseline Nudges_per_year ATE YearStart Treatedyears Valid Treated Control SE 
keep if Valid == 1
destring Nudges_per_year ATE YearStart Treatedyears Treated Control, replace
replace Utilitytype = upper(Utilitytype)
replace Utilitytype = "NATURAL GAS" if Utilitytype == "GAS"

*Replace missing treatment and control group values with group means
foreach val in "MW" "NE" "W" "S"{
	qui sum Treated if Census_Region == "`val'"
	local treat_mean = `r(mean)'
	
	qui sum Control if Census_Region == "`val'"
	local control_mean = `r(mean)'
	
	replace Treated = `treat_mean' if Treated == . & Census_Region == "`val'"
	replace Control = `control_mean' if Control == . & Census_Region == "`val'"
}
rename YearStart policy_year
save "${output_fig}/figures_data/Nudge_inter_v1.dta", replace

*Get State weights by census region
import excel "${policy_assumptions}", first clear sheet("crosswalk_state_region")
gen state_weight = .
gen region_weight = .

qui sum Population
local US_pop = `r(sum)'
foreach val in "MW" "NE" "W" "S"{
	qui sum Population if Census_Region == "`val'"
	local region_sum = `r(sum)'
		
	replace state_weight = Population / `region_sum' if Census_Region == "`val'"
	replace region_weight = `region_sum' / `US_pop' if Census_Region == "`val'"
}
replace state_weight = 1 if State == "US"
drop Population Region

merge 1:m State using "${output_fig}/figures_data/Nudge_inter_v1.dta", keep(3) nogen

*Change therms to mmbtu for natural gas
replace Baseline = Baseline * 0.1 if Utilitytype == "NATURAL GAS"

rebound ${rebound}
local r = `r(r)'

gen reduced = Baseline * (ATE/100) 
gen index = _n
gen corporate_loss = 0
gen c_savings = 0
gen local_pollutants = 0 
gen global_pollutants = 0
gen fisc_ext_t = 0

qui sum index
forvalues i = `r(min)'(1)`r(max)' {
	local state = State[`i']
	local dollar_year = 2020
	
	if "`same_grid'" == "yes" {
		local state = "US"
	}
	
	if Utilitytype[`i'] == "ELECTRICITY" {
		replace corporate_loss = reduced * ${producer_surplus_`dollar_year'_`state'} * `r' if index == `i'
		replace c_savings = (reduced * ${kwh_price_`dollar_year'_`state'}) * 0.49 if "${value_savings}" == "yes" & index == `i'
		dynamic_split_grid reduced[`i'], starting_year(`dollar_year') ext_year(`dollar_year') discount_rate(`discount') ef("`replacement'") type("uniform") geo("`state'") grid_specify("yes") model("${grid_model}")
		replace local_pollutants = `r(local_enviro_ext)' if index == `i'
		replace global_pollutants = `r(global_enviro_ext)' if index == `i'
		replace fisc_ext_t = reduced * ${government_revenue_`dollar_year'_`state'} * `r' if index == `i'
		
		if "`persistence'" == "yes" {
			local next_year = `dollar_year' + 1
			local two_years = `dollar_year' + 2
			local kwh_reduced = reduced[`i'] * 0.514 // Technology percent from https://www.nber.org/papers/w23277
			
			dynamic_split_grid `kwh_reduced', starting_year(`dollar_year') ext_year(`next_year') discount_rate(`discount') ef("`replacement'") type("uniform") geo("`state'") grid_specify("yes") model("${grid_model}")
			replace local_pollutants = local_pollutants + `r(local_enviro_ext)' if index == `i'
			replace global_pollutants = global_pollutants + `r(global_enviro_ext)' if index == `i'
			
			dynamic_split_grid `kwh_reduced', starting_year(`dollar_year') ext_year(`two_years') discount_rate(`discount') ef("`replacement'") type("uniform") geo("`state'") grid_specify("yes") model("${grid_model}")
			replace local_pollutants = local_pollutants + `r(local_enviro_ext)' if index == `i'
			replace global_pollutants = global_pollutants + `r(global_enviro_ext)' if index == `i'
			
			replace fisc_ext_t = fisc_ext_t + (`kwh_reduced' * ${government_revenue_`dollar_year'_`state'} * `r')/(1+`discount')^2 + (`kwh_reduced' * ${government_revenue_`dollar_year'_`state'} * `r')/(1+`discount')^3 if index == `i'
			replace corporate_loss = corporate_loss + (`kwh_reduced' * ${producer_surplus_`dollar_year'_`state'} * `r')/(1+`discount')^2 + (`kwh_reduced' * ${producer_surplus_`dollar_year'_`state'} * `r')/(1+`discount')^3 if index == `i'
			replace c_savings = c_savings + (`kwh_reduced' * ${kwh_price_`dollar_year'_`state'} * `r')/(1+`discount')^2 + (`kwh_reduced' * ${kwh_price_`dollar_year'_`state'} * `r')/(1+`discount')^3 if "${value_savings}" == "yes" & index == `i'
		}
	}
	
	else {
		replace corporate_loss = reduced * ${psurplus_mmbtu_`dollar_year'_`state'}  if index == `i'
		replace c_savings = (reduced * ${ng_price_`dollar_year'_`state'}) * 0.49 if "${value_savings}" == "yes" & index == `i'
		replace local_pollutants = 0 if index == `i'
		replace global_pollutants = ${global_mmbtu_`dollar_year'} * reduced if index == `i'
		replace fisc_ext_t = reduced * ${govrev_mmbtu_`dollar_year'_`state'} if index == `i'
		
		if "`persistence'" == "yes" {
			replace corporate_loss = corporate_loss + (reduced * 0.514  * ${psurplus_mmbtu_`dollar_year'_`state'})/(1+`discount')^2 + (reduced * 0.514  * ${psurplus_mmbtu_`dollar_year'_`state'})/(1+`discount')^3 if index == `i'
			replace c_savings = c_savings + (reduced * 0.514 * ${ng_price_`dollar_year'_`state'})/(1+`discount')^2 + (reduced * 0.514 * ${ng_price_`dollar_year'_`state'})/(1+`discount')^3 if index == `i'
			replace global_pollutants = global_pollutants + (${global_mmbtu_`dollar_year'} * reduced * 0.514)/(1+`discount')^2 + (${global_mmbtu_`dollar_year'} * reduced * 0.514)/(1+`discount')^3 if index == `i'
			replace fisc_ext_t = fisc_ext_t + (${govrev_mmbtu_`dollar_year'_`state'}  * reduced * 0.514)/(1+`discount')^2 + (${govrev_mmbtu_`dollar_year'_`state'} * reduced * 0.514)/(1+`discount')^3 if index == `i'

		}
	}
}

if "${value_profits}" == "no" {
	replace corporate_loss = 0
	replace fisc_ext_t = 0
}

*Including Rebound (only for electricity)
gen rebound_local = local_pollutants * (1-`r')
gen rebound_global = global_pollutants * (1-`r')

replace rebound_local = 0 if Utilitytype == "NATURAL GAS"
replace rebound_global = 0 if Utilitytype == "NATURAL GAS"

gen wtp_society = global_pollutants + local_pollutants - rebound_global - rebound_local

gen WTP = wtp_society - corporate_loss + c_savings - ((global_pollutants - rebound_global) * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

// Quick decomposition
gen WTP_USPres = local_pollutants - corporate_loss - rebound_local + c_savings
gen WTP_USFut  =     ${USShareFutureSSC}  * ((global_pollutants - rebound_global) - ((global_pollutants - rebound_global) * ${USShareGovtFutureSCC}))
gen WTP_RoW    = (1 - ${USShareFutureSSC}) * (global_pollutants - rebound_global)

**Cost
gen program_cost = 1 * Nudges_per_year * (${cpi_`dollar_year'}/${cpi_2009}) // Alcott estimates that the cost of mailing and printing 1 HER is approximately $1 in 2009

if "${value_profits}" == "no" {
	replace fisc_ext_t = 0
}

gen fisc_ext_s = 0

gen fisc_ext_lr = -1 * (global_pollutants - rebound_global) * ${USShareFutureSSC} * ${USShareGovtFutureSCC} 

gen total_cost = program_cost + fisc_ext_s + fisc_ext_lr + fisc_ext_t
gen MVPF = WTP/total_cost

**********************************
*Electricity
**********************************

local utility = "ELECTRICITY"
keep if Utilitytype == "`utility'"

*Region Labels
gen region = 3 if State == "AR" | State == "MI" | State == "IL" | State == "IN"
replace region = 2 if State == "CA"
replace region = 1 if State == "CT" | State == "MA" | State == "RI"
replace region = 4 if State == "MD" | State == "OH"
replace region = 5 if State == "WA" 
gen WTP_scaled = WTP/program_cost
gen cost_scaled = total_cost/program_cost

keep Utilitytype MVPF WTP WTP_RoW WTP_USFut WTP_USPres total_cost index State region reduced Baseline ATE Treated WTP_scaled cost_scaled Type

preserve
collapse (mean) WTP_scaled cost_scaled (count) index [aw = Treated], by(region)
rename index obs
gen region_name = ""
replace region_name = "New England" if region == 1
replace region_name = "California" if region == 2
replace region_name = "Midwest" if region == 3
replace region_name = "Mid-Atlantic" if region == 4
replace region_name = "Northwest" if region == 5
gen MVPF = WTP_scaled/cost_scaled

forvalues r  = 1(1)5 {
	qui sum MVPF if region == `r'
	global her_MVPF_region`r' = `r(mean)'
}
restore


*Corr Plot
if "${make_plot}" == "yes" {
	local WTP_loop "USPres USFut RoW"
		foreach var of local WTP_loop {
			gen `var'_scaled = WTP_`var' / total_cost
			gen bar_`var' = .
		}

	replace MVPF = 0 if MVPF < 0 
	replace MVPF = 0 if MVPF == 99999

	replace bar_USPres = USPres_scaled 											
	replace bar_USFut = bar_USPres + USFut_scaled 									
	replace bar_RoW = bar_USFut + RoW_scaled 										

	** For policies with a negative WTP US Present. 
	replace bar_USPres = 0 if WTP_USPres < 0
	replace bar_USFut = 0 if bar_USFut < 0

	if bar_USPres/WTP > 5 | bar_USPres/WTP < 0 {
		replace bar_USPres = `censor_value'
		replace bar_RoW = 0
		replace bar_USFut = 0
	}

	** Censoring Data.
	local censor_value = 5
	replace bar_USPres = `censor_value' if bar_USPres > `censor_value' 
	replace bar_USFut = `censor_value' if bar_USFut > `censor_value' 
	replace bar_RoW = `censor_value' if bar_RoW > `censor_value'

	replace bar_USPres = 0 if WTP < 0
	replace bar_USFut = 0 if WTP < 0
	replace bar_RoW = 0 if WTP < 0

		
	replace MVPF = `censor_value' if MVPF > `censor_value'
	gen row = 1
	gen labels = ""

	labmask index, values(labels)
	drop index
	gsort region MVPF
	gen index = _n
	sum index if row == 1
	local ylabel_min = r(min)
	local ylabel_max = r(max)
	gen base = 0

	qui sum region
	local start = `r(min)'+1
	forvalues group = `start'(1)`r(max)' {				
		sum index if region == `group'
		local `group'_val = `r(mean)'
		insobs 1, before(`r(min)')
		
		replace labels = "— — — —" if State == ""
		
		sum index if State == ""
		local yline_list `yline_list' `r(max)'	
		
		replace index = _n
	}

	local yline_list `yline_list' 148 // Hard coding last dotted line	
	labmask index, values(labels)
	qui sum index
	di in red `yline_list'

	local y = _N

	gen avg_x = .
	forvalues reg = 1(1)5 {
		replace avg_x = ${her_MVPF_region`reg'} if region == `reg'
	}
	replace avg_x = `censor_value' if avg_x > `censor_value' & avg_x != .
	replace avg_x = 0 if avg_x < 0 & avg_x != .	

	replace bar_USPres = bar_USPres +  WTP_USFut + WTP_RoW if bar_USPres > 0 & WTP_USFut < 0 & WTP_RoW < 0 
	replace bar_RoW = 0 if bar_USPres > 0 & WTP_USFut < 0 & WTP_RoW < 0 
	replace bar_USFut = 0 if bar_USPres > 0 & WTP_USFut < 0 & WTP_RoW < 0 

	graph tw (rbar base bar_USPres index if row == 1, horizontal barw(0.15) color("`bar_blue'")) ///
			 (rbar bar_USPres bar_USFut index if row == 1, horizontal barw(0.15) color("`bar_blue'"))  ///
			 (rbar bar_USFut bar_RoW index if row == 1, horizontal barw(0.15) color("`bar_blue'")) ///
			 ///
			 (scatter index MVPF if row == 1, mcolor(black) msize(tiny) msymbol(circle) yline(`yline_list', lcolor(black) lw(0.15) lpattern(dash))) ///
			 (line index avg_x if region == 1, color("black") connect(stepstair)) ///
			 (line index avg_x if region == 2, color("black") connect(stepstair)) ///
			 (line index avg_x if region == 3, color("black") connect(stepstair)) ///
			 (line index avg_x if region == 4, color("black") connect(stepstair)) ///
			 (line index avg_x if region == 5, color("black") connect(stepstair)) ///
			 , ///
			 ///
			 plotregion(margin(b=0 l=0)) ///
			 graphregion(color(white)) ///
			 xtitle(" ") ///
			 xlab(0(1)`censor_value', nogrid format(%9.0f)) ///
			 xscale(titlegap(+4) outergap(0)) ///
			 xline(0, lcolor(black) lwidth(vthin)) ///
			 ytitle(" ", size(vvtiny)) ///
			 ylabel(0(100)`y' , nogrid) ///
			 yscale(r(0 `y')) ///
			 ysize(8) xsize(11) ///
			 legend(off)
			 graph display, scale(0.9) ysize(30)
			 cap graph export "${output_fig}/figures_main/corr_plot_nudges.wmf", replace
}

