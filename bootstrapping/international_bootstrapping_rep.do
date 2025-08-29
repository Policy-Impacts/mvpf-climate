/************************************************************************
 *           No Learning by Doing Policies Bootstraps                   *
 ************************************************************************/
  
local cookstoves = "cookstoves india_cs"
local deforestation = "ug_deforest"
local rice_burning = "rice_in_st rice_in_up"
local international_rebates = "wap_mexico ac_mex fridge_mex"

local categories = "cookstoves deforestation rice_burning international_rebates" 

 do "${github}/wrapper/metafile.do" ///
    "`1'" /// 2020
    "`2'" /// SCC
    "`3'" /// learning-by-doing
    "`4'" /// savings
    "`5'" /// profits
	"`cookstoves' `deforestation' `rice_burning' `international_rebates'" /// policies
	`6' /// reps
	"international_bootstraps" // name of run

foreach policy in `cookstoves' `deforestation' `rice_burning' `international_rebates' {
	use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
	sort MVPF_`policy'
	_pctile MVPF_`policy', p(2.5, 97.5)
	global `policy'_m_low_`2' = `r(r1)'
	global `policy'_m_high_`2' = `r(r2)'
}

foreach category in `categories' {
	
	
	foreach policy in ``category'' {
		use  "${bootstrap_files}/`policy'_`1'_`6'_draws_corr_1.dta", clear
		
		gen WTP = WTP_`policy' / program_cost_`policy'
		gen cost = cost_`policy' / program_cost_`policy'
		
		*For rice burning, cannot scale by program cost
		replace WTP = WTP_`policy' if "`category'" == "rice_burning"
		replace cost = cost_`policy' if "`category'" == "rice_burning"
		
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
	global `category'_m_low_`2' = `r(r1)'
	global `category'_m_high_`2' = `r(r2)'
	
}
	
