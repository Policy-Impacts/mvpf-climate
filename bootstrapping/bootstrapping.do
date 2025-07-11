/***************************************************************************
 *           BOOTSTRAPS FOR MVPFs ENVIRONMENTAL PROJECT                    *
 ***************************************************************************
 
    This file generates the confidence intervals for each individual policy
	as well as the confidence intervals for each policy category
	
****************************************************************************/
*--------------------------------------------
* 1 - Set Locals
*--------------------------------------------
local mode = "`1'"
local scc = "`2'"
local value_profits = "`3'"
local value_savings = "`4'"
local lbd = "`5'"
local reps = `6'

cap qui do "${github}/ado/run_program.ado"
qui do "${github}/ado/gas_tax.ado"
qui do "${github}/ado/vehicle_retirement.ado"
qui do "${github}/ado/wind_ado.ado"
qui do "${github}/ado/weatherization_ado.ado"
qui do "${github}/ado/solar.ado"
qui do "${github}/ado/dynamic_split_grid.ado"
qui do "${github}/ado/dynamic_grid.ado"
qui do "${github}/ado/dynamic_grid_v2.ado"
qui do "${github}/ado/rebound.ado"
qui do "${github}/ado/check_timepaths.ado"

*--------------------------------------------
* 2 - No Learning by Doing Policies
*--------------------------------------------

do "${github}/bootstrapping/no_lbd_bootstraps.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps'


*--------------------------------------------
* 3 - Wind PTC Policies
*--------------------------------------------

do "${github}/bootstrapping/wind_bootstrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps' 


*--------------------------------------------
* 4 - Solar ITC Policies
*--------------------------------------------

do "${github}/bootstrapping/solar_bootstrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps' 


*--------------------------------------------
* 5 - Electric Vehicle Policies
*--------------------------------------------

do "${github}/bootstrapping/ev_bootstrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps'


*--------------------------------------------
* 6 - Hybrid Vehicle Policies
*--------------------------------------------

do "${github}/bootstrapping/hev_bootstrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps'

*--------------------------------------------
* 7 - Gas Tax Policies
*--------------------------------------------

do "${github}/bootstrapping/gas_tax_boostrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps'

*--------------------------------------------
* 8 - International Policies
*--------------------------------------------
do "${github}/bootstrapping/international_bootstrapping_rep.do" `mode' `scc' `lbd' `value_savings' `value_profits' `reps'

*--------------------------------------------
* 9 - Compile CI bounds for Policies
*--------------------------------------------

local all_programs "wisc_rf ihwap_nb dorsey_itc hitaj_ptc solarize audit_nudge food_labels bev_state_i ne_solar pless_tpo bev_state pless_ho ct_solar muehl_efmp dk_gas su_gas cog_gas manzan_gas small_gas_lr li_gas levin_gas sent_ch_gas park_gas k_gas_15_22 gelman_gas h_gas_01_06 small_gas_sr k_gas_89_14 h_gas_75_80 bento_gas tiezzi_gas west_gas dahl_diesel jet_fuel bunker_fuel rao_crude ethanol bmm_crude CPP_pj care CPP_aj ca_cnt rggi cookstoves india_cs sl_offset ug_deforest redd_offset mx_deforest rice_in_st rice_in_up india_offset fridge_mex ac_mex wap_mexico nudge_ger nudge_qatar hughes_csi ets ets_c shirmali_ptc metcalf_ptc nicolini_eu bolk_UK hitaj_ger bolk_France bolk_Spain bolk_Germany federal_ev c4a_cw cw_datta rebate_es c4a_dw c4a_fridge dw_datta fridge_datta esa_fridge retrofit_res wap hancevic_rf hev_usa_s hybrid_cr hev_usa_i c4c_texas c4c_federal baaqmd russo_crp ca_electric PER opower_e her_compiled opower_ng wap_nudge ihwap_hb ihwap_lb es_incent"


tempname bootstraps

postfile `bootstraps' str18 policy l_MVPF h_MVPF using "${output_fig}/figures_data/bts_`mode'_`scc'_`value_profits'_`value_savings'_`lbd'_v3.dta", replace



foreach policy in `all_programs' {
	if "${`policy'_m_low}" != "" {
		post `bootstraps' ("`policy'") (${`policy'_m_low}) (${`policy'_m_high})
	}
	
	else {
		post `bootstraps' ("`policy'") (.) (.)
	}
	
}

postclose `bootstraps'

use "${output_fig}/figures_data/bts_`mode'_`scc'_`value_profits'_`value_savings'_`lbd'_v3.dta", clear // Make sure this name is the same as the name of the file being called in mvpf_plots


*--------------------------------------------
* 6 - Compile CI bounds for Category Averages
*--------------------------------------------
local categories = "appliance_rebates weatherization vehicle_retirements other_subsidies hers other_nudges other_fuel_taxes other_rev_raisers cap_and_trade gas_tax wind solar bev hev"

tempname bootstraps

postfile `bootstraps' str18 category l_MVPF h_MVPF using "${output_fig}/figures_data/avgs_`mode'_`scc'_`value_profits'_`value_savings'_`lbd'_v3.dta", replace



foreach cat in `categories' {
	if "${`cat'_m_low}" != "" {
		post `bootstraps' ("`cat'") (${`cat'_m_low}) (${`cat'_m_high})
	}
	
	else {
		post `bootstraps' ("`cat'") (.) (.)
	}
	
}

postclose `bootstraps'

use "${output_fig}/figures_data/avgs_`mode'_`scc'_`value_profits'_`value_savings'_`lbd'_v3.dta", clear // Make sure this name is the same as the name of the file being called in mvpf_plots


