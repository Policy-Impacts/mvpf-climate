*************************************************************************************
/*       0. Program: Wisconsin Residential Weatherization	    	              */
*************************************************************************************

/*
Measuring the Welfare Effects of Residential Energy Efficiency Programs
Hunt Allcott and Michael Greenstone
NBER Working Paper No. 23386
*/
*https://www.nber.org/system/files/working_papers/w23386/w23386.pdf

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals

local replacement = "${replacement}"
global spec_type = "`4'"
local discount = ${discount_rate}

*********************************
/* 2. Estimates from Paper */
*********************************
/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates. */

if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
*	if ${draw_number} ==1 {
		preserve
			use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
			qui ds draw_number, not 
			global estimates_${name} = r(varlist)
			
			mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
		restore
*	}
	local ests ${estimates_${name}}
	foreach var in `ests' {
		matrix temp = draws_${name}["${draw_number}", "`var'"]
		local `var' = temp[1,1]
	}
}
if "`bootstrap'" != "yes" {
	preserve
		qui import excel "${code_files}/2a_causal_estimates_papers/${folder_name}/${name}.xlsx", clear sheet("wrapper_ready") firstrow
		levelsof estimate, local(estimates)
		foreach est in `estimates' {
			su pe if estimate == "`est'"
			local `est' = r(mean)
		}
	restore
}


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

rebound ${rebound}
local r = `r(r)'
local r_ng = `r(r_ng)'

*********************************
/* 4. Intermediate Calculations */
*********************************
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	local dollar_year = ${policy_year}
}
if "`4'" == "current"{
	local dollar_year = ${current_year}
}

// For 2020 MVPF, we scale the paper's MVPFs by our set of externality assumptions
	
	*Get the weights of electricity and natural gas reduced (per mmbtu)
	local elec_weight = -1 * (0.15 * `audit_elec' + 0.02 * `investment_elec') * 0.003412
	local gas_weight = -1 * (0.15 * `audit_gas' + 0.02 * `investment_gas') * 0.1
	
	local elec_weight_adj = `elec_weight' / (`elec_weight' + `gas_weight')
	local gas_weight_adj = `gas_weight' / (`elec_weight' + `gas_weight')


	*************************
	/* WTP Calculations */
	*************************
	
	// Using markups in paper from Table 2
	local paper_markup_adj = 2.75 * `gas_weight_adj' + 29.73 * `elec_weight_adj'

	local our_markup_adj = ${psurplus_mmbtu_2020_US} * `gas_weight_adj' + (${producer_surplus_2020_US} * (1 / 0.003412)) * `elec_weight_adj'

	local profit_loss = (`our_markup_adj' / `paper_markup_adj') * 0.21

	// WTP Prod adjusting for taxes (72% private utilities + 10% tax rate)
	local prod_loss = `profit_loss' * 0.72 * 0.9
	
	// Local Damages - Using damages from Table A8
	local paper_local_enviro = 1.0 * `gas_weight_adj' + 0.0678 * (1 / 0.003412) * `elec_weight_adj'

	local our_local_enviro = (0) * `gas_weight_adj' + (${local_uniform_US_2020} * (1 / 0.003412)) * `elec_weight_adj'

	// Global Damages - Using damages from Table A8
	local paper_global_enviro = 15.3 * `gas_weight_adj' + 0.1066 * (1 / 0.003412) * `elec_weight_adj'

	local our_global_enviro = (${global_mmbtu_2020}) * `gas_weight_adj' + (${global_uniform_US_2020} * (1 / 0.003412)) * `elec_weight_adj'

	// Final Local and Global Damages
	local local_pollutants = 0.87 * (`paper_local_enviro' / (`paper_local_enviro' + `paper_global_enviro')) * (`our_local_enviro' / `paper_local_enviro')
	
	local global_pollutants = 0.87 * (`paper_global_enviro' / (`paper_local_enviro' + `paper_global_enviro')) * (`our_global_enviro' / `paper_global_enviro')
	
	
	local wtp_glob = `global_pollutants' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

	// Share of Global Damages that is Natural Gas
	local global_ng = ((${global_mmbtu_2020}) * `gas_weight_adj' * `elec_weight_adj') / `our_global_enviro'
	
	// Adding in Rebound Effects
	local rebound_global = ((1 - `global_ng') * `global_pollutants' * (1 - `r')) + (`global_ng' * `global_pollutants' * (1 - `r_ng'))
	local rebound_global = ((1 - `global_ng') * `global_pollutants' * (1 - `r')) + (`global_ng' * `global_pollutants' * (1 - `r_ng'))
	local wtp_r_glob = `rebound_global' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
	
	local rebound_local = `local_pollutants' * (1 - `r')

	local rebound_local = `local_pollutants' * (1 - `r')

	// Getting Transfer value from paper
	local investment_distortion = -0.91 * ${cpi_2020}/${cpi_${policy_year}}
	local consumer_surplus = 10.79 * ${cpi_2020}/${cpi_${policy_year}}
	local wtp_cons = `consumer_surplus' + `investment_distortion'
	di in red "wtp consumers is `wtp_cons'"

	local wtp_society = `local_pollutants' - `rebound_local' + `global_pollutants' - `rebound_global'
	
	local c_savings = 0
	
	if "${value_profits}" == "no" {
		local prod_loss = 0
		local profit_loss = 0
	}
	
	* Total WTP
	local WTP = `wtp_cons' + `wtp_society' - `prod_loss' + `c_savings' - ((`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})
	
	
	// Quick decomposition
	local WTP_USPres = `wtp_cons' + `local_pollutants' - `prod_loss' - `rebound_local' + `c_savings'
	local WTP_USFut  =      ${USShareFutureSSC}  * ((`global_pollutants' - `rebound_global') - ((`global_pollutants' - `rebound_global') * ${USShareGovtFutureSCC}))
	local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')
	
	**************************
	/* Cost Calculations  */
	**************************
	
	local program_cost = 11.35 * ${cpi_2020}/${cpi_${policy_year}}
	
	local fisc_ext_t = (`profit_loss' * 0.72 * 0.1) + (`profit_loss' * 0.28)
	
	local fisc_ext_s = 0
	
	local fisc_ext_lr = -1 * (`global_pollutants' - `rebound_global') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
	
	local total_cost = `program_cost' + `fisc_ext_t' + `fisc_ext_lr'

	local MVPF = `WTP' / `total_cost'

// For in-context estimates, we use the paper's MVPF as is
if "${spec_type}" == "baseline" {
	local wtp_cons = 10.79 - 0.91
	local prod_loss = 0.21
	
	local local_pollutants = 0.87 * (`paper_local_enviro' / (`paper_local_enviro' + `paper_global_enviro'))
	local global_pollutants = 0.87 * (`paper_global_enviro' / (`paper_local_enviro' + `paper_global_enviro'))
	local wtp_glob = `global_pollutants'
	
	local rebound_local = 0
	local rebound_global = 0
	local wtp_r_glob = `rebound_global'
	local c_savings = 0
	
	local wtp_society = `local_pollutants' - `rebound_local' + `global_pollutants' - `rebound_global'
	
	local WTP = `wtp_cons' + `wtp_society' - `prod_loss' + `c_savings'

	local WTP_USPres = `wtp_cons' + `local_pollutants' - `prod_loss' - `rebound_local' + `c_savings'
	local WTP_USFut  =      ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global')
	local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global')
	
	local total_cost = 11.35
	local program_cost = 11.35
	local fisc_ext_t = 0
	local fisc_ext_s = 0
	local fisc_ext_lr = 0
	local MVPF = (`WTP') / `total_cost'
}

********************************
/* 5. Cost Effectiveness */
********************************
local energy_cost = ${energy_cost}
local ng_cost = 3.43 * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor form EIA, from ng_citygate tab in policy_category_assumptions_MASTER
local retrofit_lifespan = 20
local kwh_reduced = -1 * (`audit_elec' + `investment_elec') * 365
di in red "kwh reduced is `kwh_reduced'"
local mmbtu_reduced = -1 * (`audit_gas' + `investment_gas') * 0.1 * 365
di in red "mmbtu reduced is `mmbtu_reduced'"

local energy_savings = ((`kwh_reduced' * `energy_cost') + `mmbtu_reduced' * `ng_cost') + (((`kwh_reduced' * `energy_cost') + `mmbtu_reduced' * `ng_cost') / `discount') * (1 - (1 / (1 + `discount')^(`retrofit_lifespan' - 1)))
di in red "energy savings is `energy_savings'"

dynamic_grid `kwh_reduced', starting_year(`dollar_year') lifetime(`retrofit_lifespan') discount_rate(`discount') ef("`replacement'") type("uniform") geo("${State}") grid_specify("yes") model("${grid_model}")

local carbon = `r(carbon_content)' + ((${global_mmbtu_`dollar_year'} * `mmbtu_reduced' * `retrofit_lifespan')/${sc_CO2_`dollar_year'})
di in red "carbon is `carbon'"

local wap_cost = (1486 + 400) * (${cpi_2020} / ${cpi_2013}) // From page 12 + cost of audit
di in red "wap cost is `wap_cost'"
	
local resource_cost = `wap_cost' - `energy_savings'
di in red "resource cost is `resource_cost'"

local q_carbon_mck = `carbon'
	
local resource_ce = `resource_cost' / `q_carbon_mck'
di in red "resource cost per ton is `resource_ce'"


****************
/* 6. Outputs */
****************

di `MVPF'
global MVPF_`1' = `MVPF'
global cost_`1' = `total_cost'
global WTP_`1' = `WTP'
global wtp_cons_`1' = `wtp_cons' 
global wtp_prod_`1' = `prod_loss'
global wtp_glob_`1' = `wtp_glob'
global wtp_loc_`1' = `local_pollutants'
global wtp_r_loc_`1' = `rebound_local'
global wtp_r_glob_`1' = `wtp_r_glob'

global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' = `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `program_cost'
global q_CO2_`1' = `carbon'

global program_cost_`1' = `program_cost'
global total_cost_`1' = `total_cost'
global wtp_soc_`1' = `wtp_society'

global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global resource_ce_`1' = `resource_ce'
global q_carbon_mck_`1' = `q_carbon_mck'

/*
** for waterfall charts
global wtp_comps_`1' wtp_marg wtp_inf wtp_prod wtp_glob wtp_loc wtp_r_loc wtp_r_glob c_savings WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_prod", "wtp_glob" ,"wtp_loc", "c_savings", "wtp_r_loc", "wtp_r_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Wisconsin Weatherization"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `"Producers"' 4 `""Global" "Enviro""' 5 `""Local" "Enviro""' 6 `""Rebound" "Local""' 7 `""Rebound" "Global""' 8 `""Consumer" "Savings""' 9 `"Total WTP"' 11 `""Program" "Cost""' 12 `""FE" "Subsidies""' 13 `""FE" "Taxes""' 14 `""FE" "Long-Run""' 15 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 3
global color_group2_`1' = 5
global color_group3_`1' = 8
global cost_color_start_`1' = 11
global color_group4_`1' = 14

global note_`1' = `"Publication: " "SCC: `scc'" "Description: Cost curve - `cc_def', MVPF definition - `mvpf_def', Subsidy value - `s_def', Grid - `grid_def', Replacement - `replacement_def'," "Grid Model - `grid_model_def', Electricity supply elasticity - `elec_sup_elas'"'
global normalize_`1' = 1
