/************************************************************************
 *           Gas Tax Policies Bootstraps                   *
 ************************************************************************/

*To optimize run time, we run gas tax policies without learning by doing and then add the learning by doing component values to the willingness to pay and cost after the bootstraps since it is independent of the gas tax elasticity.

*For the in-context runs, we  
 
global scc = "`2'"
global lbd = "`3'"
global value_savings = "`4'"
global value_profits = "`5'"
 
local gas_tax = "dk_gas su_gas cog_gas manzan_gas small_gas_lr li_gas levin_gas sent_ch_gas park_gas k_gas_15_22 gelman_gas h_gas_01_06"

local categories = "gas_tax" 

local cc_policy = "cog_gas"
local in_context_cc_policies = "k_gas_15_22 gelman_gas"

if "`1'" == "current" {
	run_program `cc_policy', mode("`1'") folder("harmonized") scc(`2')
	
	foreach policy in `gas_tax' {
		local lbd_wtp_`policy' = ${wtp_lbd_`cc_policy'}
		local lbd_cost_`policy' = ${cost_lbd_`cc_policy'}
	}
}

if "`1'" == "baseline" {
	
	foreach policy in `gas_tax' {
		local lbd_wtp_`policy' = 0
		local lbd_cost_`policy' = 0
	}
	
	foreach policy in `in_context_cc_policies' {
		run_program `policy', mode("`1'") folder("harmonized") scc(`2')
		local lbd_wtp_`policy' = ${wtp_lbd_`policy'}
		local lbd_cost_`policy' = ${cost_lbd_`policy'}
	}
		
}

if "`3'" == "no" {
	
	foreach policy in `gas_tax' {
		local lbd_wtp_`policy' = 0
		local lbd_cost_`policy' = 0
	}
	
}


 do "${github}/wrapper/metafile.do" ///
    "`1'" /// 2020
    "`2'" /// SCC
    "no" /// learning-by-doing
    "`4'" /// savings
    "`5'" /// profits
	"`gas_tax'" /// policies
	`6' // reps
	

foreach policy in `gas_tax' {
	use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
	replace WTP_`policy' = WTP_`policy' + `lbd_wtp_`policy''
	replace cost_`policy' = cost_`policy' + `lbd_cost_`policy''
	replace MVPF_`policy' = WTP_`policy' / cost_`policy'
	
	sort MVPF_`policy'
	_pctile MVPF_`policy', p(2.5, 97.5)
	global `policy'_m_low = `r(r1)'
	global `policy'_m_high = `r(r2)'
}


	
foreach policy in `gas_tax' {
	use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
	
	gen WTP = (WTP_`policy' + `lbd_wtp_`policy'') / program_cost_`policy'
	gen cost = (cost_`policy' + `lbd_cost_`policy'') / program_cost_`policy'
	keep WTP cost draw_id
	gen policy = "`policy'"
	save "${bootstrap_files}/`policy'_`6'_cleaned", replace
}
clear

foreach policy in `gas_tax' {
	*Append each policy in the category
	append using "${bootstrap_files}/`policy'_`6'_cleaned"
}

*Calculatet the MVPF of each draw
collapse (mean) cost WTP, by(draw_id)
gen MVPF = WTP/cost

_pctile MVPF, p(2.5, 97.5)
global gas_tax_m_low = `r(r1)'
global gas_tax_m_high = `r(r2)'
	
