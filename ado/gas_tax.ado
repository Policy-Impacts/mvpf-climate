*************************************************************
/* Purpose: Calculate MVPF for a Given Own-Price Elasticity of Gasoline	*/
*************************************************************

* Note: This .ado file streamlines the process of MVPFing a gas tax. All papers that estimate an own-price elasticity of gasoline can run this file to calculate the MVPF. It requires that gas_vehicle_externalities be run beforehand (to create the globals for the externality associated with a light-duty, gas-powered vehicle).

cap prog drop run_gas_tax
prog def run_gas_tax, rclass

syntax anything, elas_demand(real) farmer_theta(real)

local dollar_year = `anything'
local e_demand_gas = `elas_demand'
local farmer_theta = `farmer_theta'

local discount = ${discount_rate}

local share_ev_market_US = 0.1 // 10% of dynamic cost benefits flow to American firms in the future, 90% to RoW. Axios (2024)

global value_local_damages = 								"yes"
global non_marginal_constant_semi =							"no"
global non_marginal_constant_e = 							"no"
global gtcc_toggle											"${bev_cf}" // Need to incorporate to allow to vary.

local ev_manufacturing_emissions = (59.5 / 1000) // Initially in kilograms per KWh, going to tons per KWh. 59.5 from Winjobi et al. (2022)

****************************************************
/* 1. Pull Price, Tax, and Markup Data for Relevant Year(s).  */
****************************************************
preserve

	local consumer_price = ${nominal_gas_price_`dollar_year'} // Consumer price includes taxes. 
	local tax_rate = ${nominal_gas_tax_`dollar_year'}
	local markup = ${nominal_gas_markup_`dollar_year'}
	local gas_consumption = ${gasoline_consumed_ldv_`dollar_year'}
	
	
	if "${vary_gas_price}" == "yes" {
		
		local consumer_price = ${alternative_gas_price}
		di in red `consumer_price'
		
	} 
	
	***** Semi-Elasticity of Gasoline Consumption w.r.t. Gasoline Price Calculated Here *****
	local semi_e_demand_gas_tax = `e_demand_gas'/`consumer_price' 

	
restore

**************************
/* 2. Perform Cost Curve Calculations  */
**************************
if `dollar_year' > 2011 & "${lbd}" == "yes" { // Earliest year with data for EV cost curve.																	

	**************************
	/* 2a. Pull Necessarily Data  */
	**************************
	preserve
	
		* Production Data (`marg_sales', `cum_sales')
		use "${assumptions}/evs/processed/battery_sales_combined", clear
		keep if year == `dollar_year'
			qui sum marg_sales
				local marg_sales = r(mean)
			qui sum cum_sales
				local cum_sales = r(mean)

		* Cost Data (`prod_cost')	
		use "${assumptions}/evs/processed/cyl_batt_costs_combined", clear
		keep if year == `dollar_year'
			qui sum prod_cost_2018
				local prod_cost = r(mean) * (${cpi_`dollar_year'}/${cpi_2018})
	
		* EV Price Data (`msrp')						
		use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
		keep if year == 2020
		qui sum avg_msrp
		local msrp = r(mean) * (${cpi_`dollar_year'} / ${cpi_2020})


		* Fiscal Externality from Subsidies for EV_externality
		use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
		keep year subsidy_weighted_avg
		keep if year == `dollar_year'
			qui sum subsidy_weighted_avg	
				local EV_subsidy = r(mean) + 604.27*(${cpi_`dollar_year'}/${cpi_2020}) // State Avg. Subsidy 2020 from AFDC's database
				
		* Total Number of EVs Sold (`ev_sold')						
		import excel "${policy_assumptions}", first clear sheet("ev_sales_annual")
		keep if year == `dollar_year'
			qui sum ev_sales if year == `dollar_year'
				local total_ev_sold = r(mean)
				
		* Battery Capacity				
		use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
		keep if year == 2020
			qui sum avg_batt_cap
				local battery_cap = r(mean)
					
	restore			
	
	**************************
	/* 2b. Intermediate Calculations  */
	**************************	
	local batt_cost = `prod_cost' * `battery_cap'
	local battery_frac = `batt_cost' / `msrp'
	local fixed_cost_frac = 1 - `battery_frac'
	local car_theta = `farmer_theta' * `battery_frac'
	
	local cross_price_gas_ev = -${gtcc_epsilon} * (${${gtcc_toggle}_cf_gas_savings_`dollar_year'}/`msrp')
// 		assert `cross_price_gas_ev' > 0 // Cross-price Elasticity of Substituites > 0
	
	local dynamic_adjust = (`cross_price_gas_ev' / (`consumer_price' * `gas_consumption')) / (${gtcc_epsilon}/(`msrp' * `total_ev_sold'))
	// Used to scale any components that come from the cost curve to levels of gasoline. 
	
	local static_adjust = (`cross_price_gas_ev'/`consumer_price') * (`total_ev_sold'/`gas_consumption')
	// Used to scale components from EV substitution that do not feed through cost curve.
	
	**************************
	/* 2c. Run Cost Curve  */
	**************************	
	cost_curve_masterfile, demand_elas(${gtcc_epsilon}) discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`msrp') enviro(ev_local) subsidy_max(`EV_subsidy') scc(193) // 193 baseline from EPA 2023c
		local dynamic_enviro_local = `r(enviro_mvpf)' * `dynamic_adjust'
		
	cost_curve_masterfile, demand_elas(${gtcc_epsilon}) discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`msrp') enviro(ev_global) subsidy_max(`EV_subsidy') scc(193) // 193 baseline from EPA 2023c
		local dynamic_enviro_global = `r(enviro_mvpf)' * `dynamic_adjust'
		
		local dynamic_cost = `r(cost_mvpf)' * `dynamic_adjust'
		
		
// 			assert `dynamic_cost'/`dynamic_enviro_global' >= 0
// 			assert `dynamic_enviro_global' + `dynamic_enviro_local' < 0
	
	**************************
	/* 2d. Account for Static EV Damages (Benefits Captured in Own Price Elasticity of Gasoline)  */
	**************************	
	local static_enviro_local = ${yes_ev_damages_local_`dollar_year'} * `static_adjust'
// 		assert `static_enviro_local' > 0 // Accounting for local charging damages makes MVPF look worse. 
	
	local static_enviro_global = (${yes_ev_damages_global_`dollar_year'} + (`ev_manufacturing_emissions' * `battery_cap' * ${sc_CO2_`dollar_year'}))* `static_adjust'
// 		assert `static_enviro_global' > 0 // Accounting for global charging damages makes MVPF look worse.
	
	// Both make gas taxes look worse b/c consuming less gas means charging more EVs. 
	
	**************************
	/* 2e. Account for Fiscal Externalities (FEs Related to Gas Captured by Own Price Elasticity)  */
	**************************	
	local fisc_ext_EV_sub = -`static_adjust' * `EV_subsidy'
// 		assert `fisc_ext_EV_sub' <= 0 // Lose revenue when someone buys an EV b/c of existing subsidies.
	
	local fisc_ext_EV_util = `static_adjust' * ${yes_ev_utility_taxes_`dollar_year'}
// 		assert `fisc_ext_EV_util' >= 0	// Gain revenue from public utilities when new EV owner charges their vehicle. 

	**************************
	/* 2f. Account for Producers (Gas Producers Captured by Own Price Elasticity)  */
	**************************			
	local ev_utility_profits = -`static_adjust' * ${yes_ev_utility_profits_`dollar_year'}
// 		assert `ev_utility_profits' <= 0 // Utilites like gas taxes b/c consumers substitute toward EVs, earning the utilites profits.
					
}
else {
	
	local dynamic_enviro_local = 0
	local dynamic_enviro_global = 0
	local dynamic_cost = 0
	
	local static_enviro_local = 0
	local static_enviro_global = 0
	
	local fisc_ext_EV_sub = -0
	local fisc_ext_EV_util = 0
	
	local ev_utility_profits = 0
	
	local cross_price_gas_ev = 0

}

**************************
/* 3. MVPF Cost Calculations  */
**************************
local program_cost = 1

*************************
/* 4. WTP Calculations */
*************************

* Consumers
local wtp_cons = 1

* Society
local wtp_soc_gas_local = ${gas_ldv_ext_local_`dollar_year'} * `semi_e_demand_gas_tax'

local wtp_local_pollution = (${gas_ldv_ext_local_no_vmt_`dollar_year'}) * `semi_e_demand_gas_tax'

local wtp_local_driving = (${gas_ldv_ext_local_`dollar_year'} - ${gas_ldv_ext_local_no_vmt_`dollar_year'}) * `semi_e_demand_gas_tax'
// Already scaled by beta in calculation file.
	
// 	assert round(`wtp_local_pollution' + `wtp_local_driving', 0.01) == round(`wtp_soc_gas_local', 0.01)
	
local wtp_soc_gas_global = ${gas_ldv_ext_global_`dollar_year'} * `semi_e_demand_gas_tax' 
				
* Producers
/* Three Producer WTPs: WTP for initial consumer reaction to change in gas price (+), 
						WTP for consumers switching from gas vehicle to EV (+),
						and WTP for increased electricity consumption / payment to utilities (-). */
						
local wtp_prod = (-`markup' * (1 - ${gasoline_effective_corp_tax}) *`semi_e_demand_gas_tax') + `ev_utility_profits'
local fisc_ext_corp_tax_gas = `markup' * ${gasoline_effective_corp_tax} *`semi_e_demand_gas_tax'
// 	assert `fisc_ext_corp_tax_gas' < 0

if "${value_profits}" == "no" {
	
	local wtp_prod = 0 // Includes utilities and gas companies' profits. 
	local fisc_ext_corp_tax_gas = 0
	local fisc_ext_EV_util = 0
	
}

if "${value_local_damages}" == "no" {
	
	local wtp_soc_gas_local = 0
	local dynamic_enviro_local = 0
	local static_enviro_local = 0
	
}


local total_WTP = `wtp_cons' + `wtp_prod' + `dynamic_cost' + ///
				  `wtp_soc_gas_local' + `dynamic_enviro_local' + `static_enviro_local' + ///
	 			  ((`wtp_soc_gas_global' + `dynamic_enviro_global' + `static_enviro_global')*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) 
	

* Incidence Calculations. 	

local WTP_USPres = `wtp_cons' + `wtp_prod' + `wtp_soc_gas_local' + `dynamic_enviro_local' + `static_enviro_local'

local WTP_USFut = ((`wtp_soc_gas_global' + `dynamic_enviro_global' + `static_enviro_global') * ///
				  (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) + ///
			      (`dynamic_cost' * (`share_ev_market_US'))
		

local WTP_RoW = ((1-(${USShareFutureSSC})) * (`wtp_soc_gas_global' + `dynamic_enviro_global' + `static_enviro_global')) + ///
				(`dynamic_cost' * (1 - `share_ev_market_US'))

**************************
/* 5. Fiscal Externality and MVPF Calculations */
**************************
local fiscal_externality_lr = -(`wtp_soc_gas_global' + `dynamic_enviro_global' + `static_enviro_global') * (${USShareFutureSSC} * ${USShareGovtFutureSCC})
	
local fiscal_externality_tax = (`tax_rate' * `semi_e_demand_gas_tax') + `fisc_ext_EV_util' + `fisc_ext_corp_tax_gas'

local fiscal_externality_subsidy = `fisc_ext_EV_sub'

	local total_cost = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_subsidy' + `fiscal_externality_lr'

		local MVPF = `total_WTP'/`total_cost'


assert round((`WTP_USPres' + `WTP_USFut' + `WTP_RoW') / `total_cost', 0.1) == round(`MVPF', 0.1)

return scalar q_CO2 = ((`wtp_soc_gas_global' + `dynamic_enviro_global' + `static_enviro_global')/${sc_CO2_`dollar_year'})

local q_CO2_mck = ((`wtp_soc_gas_global') / ${sc_CO2_`dollar_year'}) / `semi_e_demand_gas_tax'
return scalar q_CO2_mck = ((`wtp_soc_gas_global') / ${sc_CO2_`dollar_year'}) / `semi_e_demand_gas_tax'

return scalar q_CO2_no = ((`wtp_soc_gas_global' + `static_enviro_global')/${sc_CO2_`dollar_year'}) * -1
return scalar q_CO2_mck_no = ((`wtp_soc_gas_global' + `static_enviro_global')/${sc_CO2_`dollar_year'})/`semi_e_demand_gas_tax'

** No CC Saves
local total_WTP_no_cc = `wtp_cons' + `wtp_prod' + ///
						`wtp_soc_gas_local' + `static_enviro_local' + ///
						((`wtp_soc_gas_global' + `static_enviro_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) 
	
local fiscal_externality_lr_no_cc = -(`wtp_soc_gas_global' + `static_enviro_global') * (${USShareFutureSSC} * ${USShareGovtFutureSCC})

local total_cost_no_cc = `program_cost' + `fiscal_externality_tax' + `fiscal_externality_subsidy' + `fiscal_externality_lr_no_cc'

local MVPF_no_cc = `total_WTP_no_cc' / `total_cost_no_cc'

****************************************
/* 6. Cost-Effectiveness Calculations */
****************************************
local resource_cost = 0.92 * ${nominal_gas_price_2020} - ${nominal_gas_tax_2020} - ${nominal_gas_markup_2020} //economy-wide 8% markup from De Loecker et al. (2020)

local resource_ce = -`resource_cost' / `q_CO2_mck'

local gov_carbon = `semi_e_demand_gas_tax' * `q_CO2_mck'
local q_carbon_mck = `q_CO2_mck'


**************************
/* 7. Save Results (as Scalars) */
**************************
return scalar MVPF = `MVPF'
return scalar MVPF_no_cc = `MVPF_no_cc'

return scalar WTP_USPres = `WTP_USPres'
return scalar WTP_USFut  = `WTP_USFut'
return scalar WTP_RoW    = `WTP_RoW'
return scalar WTP = `total_WTP'

return scalar gas_soc = `wtp_soc_gas_local' + (`wtp_soc_gas_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
return scalar gas_soc_l = `wtp_soc_gas_local'
return scalar gas_soc_l_pollution = `wtp_local_pollution'
return scalar gas_soc_l_driving = `wtp_local_driving'
return scalar gas_soc_g = (`wtp_soc_gas_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
return scalar ev_stat_gas = `static_enviro_local' + (`static_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
return scalar ev_stat_gas_l = `static_enviro_local'
return scalar ev_stat_gas_g = (`static_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))	
		
return scalar ev_dyn_gas = `dynamic_enviro_local' + (`dynamic_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
return scalar ev_dyn_gas_l = `dynamic_enviro_local'
return scalar ev_dyn_gas_g = (`dynamic_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
return scalar ev_sub_c = `dynamic_cost'
return scalar ev_sub_c_row = (`dynamic_cost')
return scalar ev_sub_c_us = (`dynamic_cost')

return scalar wtp_prod = `wtp_prod'
return scalar wtp_prod_s = (-`markup' * (1 - ${gasoline_effective_corp_tax}) * `semi_e_demand_gas_tax')
return scalar wtp_prod_u = `ev_utility_profits'

return scalar wtp_cons = `wtp_cons'

return scalar program_cost = `program_cost'
return scalar p_spend = `program_cost' + (`tax_rate' * `semi_e_demand_gas_tax') 
// Different from fisc_ext_t when the cost curve is included (no lost gas tax revenue from EVs in this component).

return scalar fisc_ext_t = `fiscal_externality_tax'
return scalar fisc_ext_s = `fiscal_externality_subsidy'
return scalar fisc_ext_lr = `fiscal_externality_lr'
return scalar cost = `total_cost'

// return scalar q_CO2 = `q_CO2'

local consumer_price_return = round(`consumer_price', 0.01)
return scalar consumer_price_return = `consumer_price_return'
return scalar markup_return = `markup'

return scalar semi_e_demand_gas_tax = `semi_e_demand_gas_tax'

return scalar gov_carbon = `gov_carbon'
return scalar resource_ce = `resource_ce'
return scalar q_carbon_mck = `q_carbon_mck'

return scalar lbd_wtp = (`ev_utility_profits' + `dynamic_enviro_local' + `dynamic_cost' + `static_enviro_local') + (`dynamic_enviro_global' + `static_enviro_global') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

return scalar lbd_cost = (`fisc_ext_EV_sub' + `fisc_ext_EV_util') + ((`dynamic_enviro_global' + `static_enviro_global') * (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

if "${gas_tax_robustness_numbers}" == "yes" {
	
	global report_cross_price = `cross_price_gas_ev'
	global report_gas_tax_static_ev_ext = `static_enviro_local' + (`static_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	global report_gas_tax_dynamic_ev_price = `dynamic_cost'
	global report_gas_tax_dynamic_ev_env = `dynamic_enviro_local' + (`dynamic_enviro_global'*(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	
}


end
