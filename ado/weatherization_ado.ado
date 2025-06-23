*Weatherization Ado File


cap prog drop weatherization_ado
prog def weatherization_ado, rclass


syntax anything, /// either "marginal" or "non-marginal"
	policy_year(integer) /// policy year
	inflation_year(integer) /// usually same as policy year
	spec(string) /// "current" "baseline" etc...
	geo(string) /// state
	kwh_reduced(real) /// annual
	mmbtu_reduced(real) /// annual
	program_cost(real) /// not including FEs
	replacement(string) /// Set equal to the local replacement
	[policy(string)] /// If there are policy specific changes
	
	
// Setting the dollar year
preserve	
	if "`spec'" == "baseline"{
		local dollar_year = `policy_year'
	}
	
	if "`spec'" == "current"{
		local dollar_year = ${current_year}
	}
restore

if "${harmonized_2010}" == "yes"{
	local dollar_year = 2010
}

local discount = ${discount_rate}

	
// Starting with the non-marginal MVPF
if "`anything'" == "non-marginal" {
	
	// Getting the weatherization assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("WAP")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
		}
		
		local marginal_valuation = ${val_given}
		local prop_marginal = ${marginal_prop}
		local retrofit_lifespan = ${retrofit_lifespan}
		
	restore
	
	
	if "${weather_mar_valuation_change}" == "yes" {
		local marginal_valuation = 0
	}
	
	if "`policy'" == "ihwap_nb" {
		local retrofit_lifespan = 34 // Lifespan of 34 from Christensen, Francisco & Myers (2023)
	}
	
	if "${decre_weather_lifespan}" == "yes" {
		local retrofit_lifespan = 10 // Assumption for testing robustness
	}
	
	if "${marginal_change}" == "yes" {
		local prop_marginal = 1  //Assumption for testing robustness
	}
	
	if "${grid_california}" == "yes" {
		local geo = "CA"
	}
	
	if "${grid_michigan}" == "yes" {
		local geo = "MI"
	}
	
	// Size the of subsidy
	local adj_rebate = `program_cost' * (${cpi_`dollar_year'}/${cpi_`inflation_year'})
	
	*************************
	/* WTP Calculations */
	*************************
	
	if "`policy'" == "wap_marketing" { //delete?
		local prop_marginal = 1
		local marginal_valuation = 0
	}
	
	rebound ${rebound}
	local r = `r(r)'
	local r_ng = `r(r_ng)'

	*Consumers
	local inframarginal = (1 - `prop_marginal') * `adj_rebate'
	local marginal = `prop_marginal' * `marginal_valuation' * `adj_rebate'

	*Producers
	local prod_annual = (`prop_marginal' * ((`kwh_reduced' * ${producer_surplus_`dollar_year'_${State}} * `r') + (`mmbtu_reduced' * `r_ng' *	${psurplus_mmbtu_`dollar_year'_${State}})))
		
	local corporate_loss = `prod_annual' + ((`prod_annual'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1))))
	
	if "${value_profits}" == "no" {
		local corporate_loss = 0
	}

	local c_savings = 0

	if "${value_savings}" == "yes" {
		local savings_annual = (`prop_marginal' * ((`kwh_reduced' * ${kwh_price_`dollar_year'_${State}}) + (`mmbtu_reduced' * ${ng_price_`dollar_year'_${State}})))
		
		local c_savings = `savings_annual' + (`savings_annual'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1)))
	}

	
	* Social Costs
	dynamic_grid `kwh_reduced', starting_year(`dollar_year') lifetime(`retrofit_lifespan') discount_rate(`discount') ef("`replacement'") type("uniform") geo("`geo'") grid_specify("yes") model("${grid_model}")
	local local_pollutants = `prop_marginal' * `r(local_enviro_ext)'
	local global_pollutants = `prop_marginal' * (`r(global_enviro_ext)' + (${global_mmbtu_`dollar_year'} * `mmbtu_reduced') + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced')/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1))))
	local carbon = `r(carbon_content)' * `r' * `prop_marginal'

	local rebound_local = `local_pollutants' * (1-`r')
	local rebound_global = ((`r(global_enviro_ext)' * (1-`r')) + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced') + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced')/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' -1)))) * (1 - `r_ng')) * `prop_marginal'

	* Social benefits from reduced carbon 
	local wtp_society = `global_pollutants' + `local_pollutants' - `rebound_global' - `rebound_local'
	
	global q_carbon_wap = (`carbon'/`prop_marginal') + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced' * `retrofit_lifespan')/${sc_CO2_`dollar_year'})

	local q_carbon = `carbon' + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced' * `retrofit_lifespan' * `prop_marginal' * `r_ng')/${sc_CO2_`dollar_year'})

	* Total WTP
	local WTP = `marginal' + `inframarginal' + `wtp_society' - `corporate_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})

	// Quick decomposition
	local WTP_USPres = `marginal' + `inframarginal' + `local_pollutants' - `corporate_loss' - `rebound_local' + `c_savings'
	local WTP_USFut  =      ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
	local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')

	**************************
	/* Cost Calculations  */
	**************************
	local program_cost = `adj_rebate'

	local annual_fe_t = (`prop_marginal' * ((`kwh_reduced' * ${government_revenue_`dollar_year'_${State}}  * `r') + (`mmbtu_reduced' * ${govrev_mmbtu_`dollar_year'_${State}} * `r_ng')))
	
	local fisc_ext_t = `annual_fe_t' + (`annual_fe_t'/`discount') * (1 - (1/(1+`discount')^(`retrofit_lifespan' - 1)))
	
	if "${value_profits}" == "no" {
		local fisc_ext_t = 0
	}

	local fisc_ext_s = 0
	
	if "`policy'" == "wap_marketing" {
		local fisc_ext_s = 5150 * `prop_marginal' * (${cpi_`dollar_year'}/${cpi_`inflation_year'}) 
		// Fowlie et al. (2018) find that the average cost of the energy upgrade per household was $5,150 in 2011 dollars

	}

	local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

	local policy_spending = `program_cost'
	local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

	
	**************************
	/* 7. MVPF Calculations */
	**************************

	local MVPF = `WTP'/`total_cost'

	****************************************
	/* 8. Cost-Effectiveness Calculations */
	****************************************
	local energy_cost = ${energy_cost}
	local ng_cost = 3.43 * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor from EIA, from ng_citygate tab in policy_category_assumptions_MASTER

	local ihwap_energy_savings = ((`kwh_reduced' * `energy_cost') + `mmbtu_reduced' * `ng_cost') + (((`kwh_reduced' * `energy_cost') + `mmbtu_reduced' * `ng_cost') / `discount') * (1 - (1 / (1 + `discount')^(`retrofit_lifespan' - 1)))

	local wap_cost = `program_cost'
	
	if "`policy'" == "retrofit_res"{
		local wap_cost = `program_cost' / 0.6 // Liang et al. (2018)
	}
	local resource_cost = `wap_cost' - `ihwap_energy_savings'

	local q_carbon_mck = (`carbon' / (`prop_marginal' * `r')) + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced' * `retrofit_lifespan') / ${sc_CO2_`dollar_year'})
	

	local resource_ce = `resource_cost' / `q_carbon_mck'

	local gov_carbon = `q_carbon_mck' * `prop_marginal'
	
}

return scalar MVPF = `MVPF'
return scalar total_cost = `total_cost'
return scalar WTP = `WTP'
return scalar marginal = `marginal' 
return scalar inframarginal = `inframarginal' 
return scalar corporate_loss = -`corporate_loss'
return scalar global_pollutants = `global_pollutants' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
return scalar local_pollutants = `local_pollutants'
return scalar rebound_local = -`rebound_local'
return scalar rebound_global = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
return scalar c_savings = `c_savings'

return scalar fisc_ext_t = `fisc_ext_t'
return scalar fisc_ext_s = `fisc_ext_s'
return scalar fisc_ext_lr = `fisc_ext_lr'
return scalar policy_spending = `policy_spending'
return scalar q_carbon = `q_carbon'

return scalar program_cost = `program_cost'
return scalar total_cost = `total_cost'
return scalar wtp_society = `wtp_society'

return scalar WTP_USPres = `WTP_USPres'
return scalar WTP_USFut  = `WTP_USFut'
return scalar WTP_RoW    = `WTP_RoW'

return scalar gov_carbon = `gov_carbon'
return scalar resource_ce = `resource_ce'
return scalar q_carbon_mck = `q_carbon_mck' 

end
	
	
	