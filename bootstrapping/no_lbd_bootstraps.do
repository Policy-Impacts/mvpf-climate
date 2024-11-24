/************************************************************************
 *           No Learning by Doing Policies Bootstraps                   *
 ************************************************************************/
  
local appliance_rebates = "fridge_datta cw_datta rebate_es esa_fridge dw_datta"
local weatherization = "retrofit_res hancevic_rf ihwap_nb wap"
local vehicle_retirements = "c4c_texas c4c_federal baaqmd"
local other_subsidies = "ca_electric russo_crp"
local hers = "her_compiled PER"
local other_nudges = "solarize audit_nudge es_incent ihwap_hb ihwap_lb wap_nudge"
local other_fuel_taxes = "jet_fuel dahl_diesel"
local other_rev_raisers = "CPP_aj CPP_pj care"
local cap_and_trade = "rggi"

local categories = "appliance_rebates weatherization vehicle_retirements other_subsidies hers other_nudges other_fuel_taxes other_rev_raisers cap_and_trade" 
	
 do "${github}/wrapper/metafile.do" ///
    "`1'" /// 2020
    "`2'" /// SCC
    "`3'" /// learning-by-doing
    "`4'" /// savings
    "`5'" /// profits
	"`appliance_rebates' `weatherization' `vehicle_retirements' `other_subsidies' `hers' `other_nudges' `other_fuel_taxes' `other_rev_raisers' `cap_and_trade'" /// policies
	`6' /// reps
	"no_lbd_bootstraps" // name of run
	

foreach policy in `appliance_rebates' `weatherization' `vehicle_retirements' `other_subsidies' `hers' `other_nudges' `other_fuel_taxes' `other_rev_raisers' `cap_and_trade' {
	use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
	sort MVPF_`policy'
	_pctile MVPF_`policy', p(2.5, 97.5)
	global `policy'_m_low = `r(r1)'
	global `policy'_m_high = `r(r2)'
}


foreach category in `categories' {
	
	
	foreach policy in ``category'' {
		use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
		
		gen WTP = WTP_`policy' / program_cost_`policy'
		gen cost = cost_`policy' / program_cost_`policy'
		keep WTP cost draw_id
		gen policy = "`policy'"
		save "${bootstrap_files}/`policy'_`6'_cleaned", replace
	}
	
	clear
	
	foreach policy in ``category'' {
		
		*Append each policy in the category
		append using "${bootstrap_files}/`policy'_`6'_cleaned"
	}
	
	*Calculatet the MVPF of each draw
	collapse (mean) cost WTP, by(draw_id)
	gen MVPF = WTP/cost
	
	*Deal with infinite MVPFs
	replace MVPF = 99999 if MVPF < 0 & cost < 0
	replace MVPF = -9999 if MVPF < 0 & cost > 0
	
	_pctile MVPF, p(2.5, 97.5)
	global `category'_m_low = `r(r1)'
	global `category'_m_high = `r(r2)'
	
}
	
