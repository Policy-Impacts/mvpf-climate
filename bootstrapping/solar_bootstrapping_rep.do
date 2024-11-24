********************************
*Solar Bootstrapping
********************************
clear
local policies = "ne_solar ct_solar"

*************************************************
*Create and Append the distribution of the draws
*************************************************
global reps = `6'

foreach policy in `policies' {
	noi do "${github}/wrapper/prepare_causal_estimates.do" ///
	"`policy'" // programs to run / all_programs
}

clear
foreach policy in `policies' {
	append using "${causal_draws_uncorrected}/${ts_causal_draws}/`policy'.dta", gen(`policy')
}

gen policy = " "
replace policy = "ne_solar" if ne_solar == 1
replace policy = "ct_solar" if ct_solar == 1
drop ne_solar ct_solar

**************************************
*Convert draws to elasticities
**************************************
gen epsilon = .

*Get NE Solar Elasticity
*****************************
local cost_per_watt_context = (((8.70 * 667.40) + (7.66 * (975.20-667.40)) + (5.40 * (1472.90 - 975.20))) / (1472.90)) * (${cpi_2008} / ${cpi_2022})

local cost_in_context = `cost_per_watt_context' * (1-0.3) - (1.13)

replace epsilon = (semie * `cost_in_context') * (1/(1 - 0.156)) if policy == "ne_solar" // scale the elasticity by 1 over the in-context pass through rate


*Get CT Solar Elasticity
*****************************
replace epsilon = elas if policy == "ct_solar"


****************************************************
*Create a crosswalk between elasticity and MVPF
****************************************************
global scc = "`2'"
global lbd = "`3'"
global value_savings = "`4'"
global value_profits = "`5'"

// Only run once

tempname solar_bootstrap
tempfile solar_bootstrap_data
postfile `solar_bootstrap' elasticity MVPF cost WTP_cc using `solar_bootstrap_data', replace 
	forvalues elas = -3(0.1)0.2 {
		global feed_in_elas = `elas'
		qui run_program solar_testing, mode("`1'") folder("robustness") scc(`2')
		
		post `solar_bootstrap' (`elas') (${MVPF_solar_testing}) (${cost_solar_testing}) (${WTP_cc_solar_testing})
	}

postclose `solar_bootstrap'

preserve
use `solar_bootstrap_data', clear
	
replace elasticity = round(elasticity, 0.01)

	qui sum elasticity if cost < 0
	local mvpf_negative = `r(max)'

	forvalues elas = -5(0.1)0 {
		local elas = round(`elas', 0.1)
		local name = round(`elas' * -10) // get rid of negative signs and decimals for naming
		
		if `elas' < `mvpf_negative' {
			local WTP_cc_`name' = 999999999999
			local cost_`name' = -999999999999 
		}
		
		if `elas' >= `mvpf_negative' & `elas' < 0 {
			qui sum WTP_cc if abs(elasticity - `elas') < 0.04
			local WTP_cc_`name' = `r(mean)'
			
			qui sum cost if abs(elasticity - `elas') < 0.04
			local cost_`name' = `r(mean)'
		}
	}

	*Hard code values for positive elasticities
	qui sum cost if elasticity == 0
	local WTP_cc_0 = `r(mean)'
	local cost_0 = `r(mean)'

restore

gen predicted_WTP_cc = .
gen predicted_cost = .
local mvpf_negative = (`mvpf_negative' * -10) - 1 // elasticities above this is infinite
gen elas_name = epsilon * -10 // To be consistent with the local names

foreach policy in `policies' {
	forvalues draw = 1(1)${reps} {
		qui sum elas_name if draw_number == `draw' & policy == "`policy'"
		local elas_original = `r(mean)'
		
		if `elas_original' > `mvpf_negative' {
			replace predicted_WTP_cc = 9999999 if draw_number == `draw' & policy == "`policy'" // infinte MVPF
			replace predicted_cost = -99999999999 if draw_number == `draw' & policy == "`policy'" // infinte MVPF
		}
		
		if `elas_original' <= 0 {
				replace predicted_WTP_cc = `WTP_cc_0' if draw_number == `draw' & policy == "`policy'" // override elasticity to 0
				replace predicted_cost = `cost_0' if draw_number == `draw' & policy == "`policy'" // override elasticity to 0
		}
		
		if `elas_original' <= `mvpf_negative' &  `elas_original' > 0 {
			
			local elas_round = round(`elas_original')
			local elas_gap = `elas_round' - `elas_original'
			
			if `elas_gap' > 0 {
				local elas_bound = `elas_round' - 1
			}
			else {
				local elas_bound = `elas_round' + 1
			}
			
			local elas_weighting = abs(`elas_gap')
			
			
			
			replace predicted_WTP_cc = (`elas_weighting' * `WTP_cc_`elas_bound'') + ((1 - `elas_weighting') * `WTP_cc_`elas_round'') if draw_number == `draw' & policy == "`policy'"
			
			replace predicted_cost = (`elas_weighting' * `cost_`elas_bound'') + ((1 - `elas_weighting') * `cost_`elas_round'') if draw_number == `draw' & policy == "`policy'"
		}
		
	}
}

*************************
*Policy-Specific CIs
*************************
foreach policy in `policies' {
	preserve
	keep if policy == "`policy'"
	gen MVPF = predicted_WTP_cc/predicted_cost
	replace MVPF = 99999 if MVPF < 0
	_pctile MVPF, p(2.5, 97.5)
	global `policy'_m_low = `r(r1)'
	global `policy'_m_high = `r(r2)'
	restore
}


*************************
*Category CIs
*************************
collapse (mean) predicted_cost predicted_WTP_cc, by(draw)
gen MVPF = predicted_WTP_cc/predicted_cost

replace MVPF = 99999 if MVPF < 0
_pctile MVPF, p(2.5, 97.5)
global solar_m_low = `r(r1)'
global solar_m_high = `r(r2)'
