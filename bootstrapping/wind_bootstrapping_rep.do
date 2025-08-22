********************************
*Wind Bootstrapping
********************************
clear
local policies = "metcalf_ptc shirmali_ptc hitaj_ptc"

**************************************
*Append the distribution of the draws
**************************************
global reps = `6'

foreach policy in `policies' {
	noi do "${github}/wrapper/prepare_causal_estimates.do" ///
	"`policy'" // programs to run / all_programs
}

clear
foreach policy in `policies' {
	append using "${causal_draws}/${ts_causal_draws}/`policy'.dta", gen(`policy')
}

gen policy = " "
replace policy = "metcalf_ptc" if metcalf_ptc == 1
replace policy = "shirmali_ptc" if shirmali_ptc == 1
replace policy = "hitaj_ptc" if hitaj_ptc == 1
drop metcalf_ptc hitaj_ptc shirmali_ptc

**************************************
*Convert draws to elasticities
**************************************
gen epsilon = .

preserve
	import excel "${policy_assumptions}", first clear sheet("Wind")
	
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		global `val' = `r(mean)'
	}
	
	local lifetime = ${lifetime}
	local capacity_factor = ${capacity_factor} // capacity factor for wind
	local average_size = ${average_size}
	local credit_life = ${credit_life}
	local current_ptc = ${current_ptc}
	local capacity_reduction = ${capacity_reduction}
	local hrs = 8760 // hours per year
	local lcoe = 0.0373 * (${cpi_2020}/${cpi_2022})
	local capacity_factor_context = 0.29
restore
	
*Get Shirmali PTC Elasticity
*****************************

preserve
	import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
	keep if Year >= 2000 & Year <= 2011 // Only have capacity additions data starting in 1999
	collapse (mean) LCOE [aw=capacity_additions]
	local avg_lcoe = (LCOE[1] * (${cpi_2020}/${cpi_2022}))/1000
	
	local ic_lcoe = (LCOE[1] * (${cpi_2011}/${cpi_2022}))/1000
restore
	
preserve
	import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
	
	gen ptc_real = .
	qui sum Year
	forvalues y = `r(min)'(1)`r(max)' {
		replace ptc_real = 15 * (${cpi_2020}/${cpi_1992}) if Year == `y'
	}
	replace ptc_real = 0 if Year == 2000 | Year == 2002 | Year == 2004 | Year == 2010 // expired in those years
	
	keep if Year >= 2000 & Year <= 2011 // Only have capacity additions data starting in 1999
	collapse (mean) capacity_additions ptc_real [aw=capacity_additions]
	local capacity_add = capacity_additions[1]
	local ptc_real = ptc_real[1]/1000
restore

*Discount the flow of LCOE and PTC to the present
local capital_discount = 0.0280
local ptc_discount_rate = 0.0280

*In-Context (for elasticity)
local lcoe_discounted_incontext = `avg_lcoe' + ((`avg_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
local ptc_discounted = 0.01 + ((0.01)/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))

local scale_factor_incontext = (`ptc_discounted' / 0.01) / (`lcoe_discounted_incontext'/`avg_lcoe')


*2020 (for Semie)
local lcoe_discounted = `lcoe' + ((`lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
local ratio = `ptc_discounted'/`lcoe_discounted'

local scale_factor = (`ptc_discounted' / 0.01) / (`lcoe_discounted'/`lcoe')

gen q_change = (semie * 50) / ((`capacity_add') - (semie * 50 * 0.5)) // percent change in capacity additions as a result of the PTC // using arc elasticity method

local p_change = (`ptc_real' * `scale_factor_incontext') / (`avg_lcoe' - (`ptc_real' * `scale_factor_incontext') * 0.5) // Average credit and average lcoe in 2020 dollars // using arc elasticity method

replace epsilon = - q_change / `p_change' if policy == "shirmali_ptc"
drop q_change

	
*Get Hitaj PTC Elasticity
*****************************
// Calculate weighted average over the sample period for the in-context LCOE
preserve
	import excel "${policy_assumptions}", first clear sheet("wind_lcoe")
	keep if Year >= 2000 & Year <= ${policy_year} // Only have capacity additions data starting in 1999
	gen ptc_nominal = .
	gen lcoe_nominal = LCOE
	gen lcoe_real = .
	gen ptc_real = .
	qui sum Year
	forvalues y = `r(min)'(1)`r(max)' {
		replace ptc_nominal = 15 * (${cpi_`y'}/${cpi_1992}) if Year == `y'
		replace lcoe_nominal = LCOE * (${cpi_`y'}/${cpi_2022}) if Year == `y'
		replace lcoe_real = LCOE * (${cpi_2020}/${cpi_2022}) if Year == `y'
		replace ptc_real = 15 * (${cpi_2020}/${cpi_1992}) if Year == `y'
		
	}
	replace ptc_nominal = 0 if Year == 2000 | Year == 2002 | Year == 2004 | Year == 2010 // expired in those years
	replace ptc_real = 0 if Year == 2000 | Year == 2002 | Year == 2004 | Year == 2010 // expired in those years
	
	collapse (mean) LCOE ptc_nominal lcoe_nominal ptc_real lcoe_real [aw=capacity_additions]
	local avg_lcoe = (LCOE[1] * (${cpi_2007}/${cpi_2022}))/1000
	local avg_ptc = ptc_nominal[1]/1000
	local avg_nominal_lcoe = lcoe_nominal[1]/1000
	
	local avg_ptc_real = ptc_real[1]/1000
	local avg_nominal_lcoe_real = lcoe_real[1]/1000
restore
	
local pos_cap = 612
local zero_cap = 20908
gen semie_paper = (-1 * lpm)/(`pos_cap'/(`pos_cap' + `zero_cap'))

*Discount the flow of LCOE and PTC to the present
local capital_discount = 0.0280
local ptc_discount_rate = 0.0280

*In-Context (for elasticity)
local lcoe_discounted_incontext = `avg_nominal_lcoe' + ((`avg_nominal_lcoe')/`capital_discount') * (1 - (1/(1+`capital_discount')^(`lifetime' - 1)))
local ptc_discounted = 0.01 + ((0.01)/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))
local ptc_incontext = `avg_ptc' + ((`avg_ptc')/`ptc_discount_rate') * (1 - (1/(1+`ptc_discount_rate')^(`credit_life' - 1)))

local ratio_incontext = `ptc_discounted' / (`lcoe_discounted_incontext' - `ptc_incontext')

*Get elasticity w.r.t cost using in-context ratio
replace epsilon = semie_paper / `ratio_incontext' if policy == "hitaj_ptc"
drop semie_paper

*Get Metcalf Elasticity
*****************************
replace epsilon = elas if policy == "metcalf_ptc"
drop farmer_theta *pe


****************************************************
*Create a crosswalk between elasticity and MVPF
****************************************************

// Only run once
global scc = "`2'"
global lbd = "`3'"
global value_savings = "`4'"
global value_profits = "`5'"

preserve
tempname wind_bootstrap
tempfile wind_bootstrap_data
postfile `wind_bootstrap' elasticity MVPF cost WTP_cc using `wind_bootstrap_data', replace


	forvalues elas = -3.7(0.1)0.2 {
		global feed_in_elas = `elas'
		qui run_program wind_testing_2, mode("`1'") folder("robustness") scc(`2')
		
		post `wind_bootstrap' (`elas') (${MVPF_wind_testing_2}) (${cost_wind_testing_2}) (${WTP_cc_wind_testing_2})
	}
	
postclose `wind_bootstrap'	
restore

preserve
use `wind_bootstrap_data', clear

replace elasticity = round(elasticity, 0.01)

qui sum elasticity if cost < 0
local mvpf_negative = round(`r(max)', 0.01) // elasticities above this value have infinite MVPF

forvalues elas = -5(0.1)0 {
	local elas = round(`elas', 0.1)
	local name = round(`elas' * -10) //names can't have negatives or decimals
	
	// Infinite MVPFs will be outside of the 95% confidence interval
	if `elas' <= `mvpf_negative' {
		local WTP_cc_`name' = 999999999999
		local cost_`name' = -999999999999 
	}
	
	if `elas' > `mvpf_negative' & `elas' < 0 {
		qui sum WTP_cc if abs(elasticity - `elas') < 0.04
		local WTP_cc_`name' = `r(mean)'
		
		qui sum cost if abs(elasticity - `elas') < 0.04
		local cost_`name' = `r(mean)'
	}
}

*Hard code values for positive elasticities
qui sum WTP_cc if elasticity == 0
local WTP_cc_0 = `r(mean)'
local cost_0 = `r(mean)'
restore

gen predicted_WTP_cc = .
gen predicted_cost = .

gen elas_name = epsilon * -10 // To be consistent with the local names

local elas_infinite = (-10 * `mvpf_negative') - 1 // Elasticities above this are infinite MVPFs

foreach policy in `policies' {
	forvalues draw = 1(1)${reps} {
		qui sum elas_name if draw_number == `draw' & policy == "`policy'"
		local elas_original = `r(mean)'
		
		if `elas_original' >= `elas_infinite' {
			replace predicted_WTP_cc = 9999999 if draw_number == `draw' & policy == "`policy'" // infinte MVPF
			replace predicted_cost = -99999999999 if draw_number == `draw' & policy == "`policy'" // infinte MVPF
		}
		
		if `elas_original' <= 0 {
				replace predicted_WTP_cc = `WTP_cc_0' if draw_number == `draw' & policy == "`policy'" // override elasticity to 0
				replace predicted_cost = `cost_0' if draw_number == `draw' & policy == "`policy'" // override elasticity to 0
		}
		
		if `elas_original' < `elas_infinite' &  `elas_original' > 0 {
			
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
save "${code_files}/3_bootstrap_draws/wind_bootstraps_${scc}", replace

*************************
*Category CIs
*************************
collapse (mean) predicted_cost predicted_WTP_cc, by(draw)
gen MVPF = predicted_WTP_cc/predicted_cost

replace MVPF = 99999 if MVPF < 0
_pctile MVPF, p(2.5, 97.5)
di `r(r1)'
di `r(r2)'
global wind_m_low = `r(r1)'
global wind_m_high = `r(r2)'
