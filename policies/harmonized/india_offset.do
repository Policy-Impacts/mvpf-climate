********************************************************************************
/*  0. Program: India Carbon Offsets                   */
********************************************************************************
/*
Do Carbon Offsets Offset Carbon?
Raphael Calel, Jonathan Colmer, Antoine Dechezleprêtre, Matthieu Glachant 
*/


********************************
/* 1. Pull Global Assumptions */
********************************
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
if "`bootstrap'" == "no" {
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

    ****************************************************
    /* 3a. Set Dollar Year and Policy Year */
    ****************************************************

    preserve

        if "`4'" == "baseline"{
            
            local dollar_year = ${policy_year}
            
        }
        
        if "`4'" == "current"{
            
            local dollar_year = ${today_year}
            
        }
        
    restore

	****************************************************
	/* 3b. Elasticity Calculation */
	****************************************************
	local prop_infra = `infra' // at least 52% of projects are inframarginal
	
	preserve
		local dollar_year = 2020
		import excel "${policy_assumptions}", first clear sheet("CER_prices")
		drop if CER_price == .
		destring Year, replace
		replace LCOE = LCOE * 1000 * (${cpi_2020} / ${cpi_2022}) // converting $/kwh to $/mwh
		qui sum Year
		gen CER_price_2020 = .
		forvalues y = `r(min)'(1)`r(max)'{
			
			replace CER_price_2020 = CER_price * ${cpi_`dollar_year'} / ${cpi_`y'} if Year == `y'
		}
		
		egen CDM_total = total(CDM_capacity)
		qui sum CDM_total
		local CDM_total = `r(mean)' * (1 - `prop_infra')
		
		egen Non_CDM_total = total(Non_CDM_capacity)
		qui sum Non_CDM_total
		local Non_CDM_total = `r(mean)' + (`CDM_total' / (1 - `prop_infra')) * `prop_infra'
		
		collapse (mean) CER_price LCOE [aw=CDM_capacity]
		local CER_mean = CER_price[1]
		local LCOE_mean = LCOE[1]
	restore

	local co2_per_mwh_context = 0.81 // tons CO2 per MWh (Value for 2013 from https://cea.nic.in/wp-content/uploads/baseline/2020/07/user_guide_ver14.pdf)
	
	local p_change = `CER_mean' * `co2_per_mwh_context'
	local per_change_p = `p_change' / (`LCOE_mean' - (`p_change' * 0.5))
	di `per_change_p'
	
	local per_change_q = `CDM_total' / (`Non_CDM_total' + (`CDM_total' * 0.5))
	di `per_change_q'
	
	local elas = -1 * `per_change_q' / `per_change_p'

	local co2_per_mwh = 0.71 // tons CO2 per MWh (https://cea.nic.in/wp-content/uploads/baseline/2023/01/Approved_report_emission__2021_22.pdf)

	local lcoe_2020 = 40.4 * (${cpi_2020} / ${cpi_2022}) // https://www.irena.org/Energy-Transition/Technology/Wind-energy
	
	local current_credit = 5.3 // https://www.researchgate.net/publication/371350214_Lessons_from_Gulf_Cooperation_Council_Countries'_Participation_in_the_Clean_Development_Mechanism
	
	local current_credit = `current_credit' * `co2_per_mwh' // scaling to get credit per mwh
	
	local semie = `elas' / (`lcoe_2020' - `current_credit')

	****************************************************
	/* 3c. Policy Category Assumptions */
	****************************************************

	*i. Import Wind assumptions
	preserve
		import excel "${policy_assumptions}", first clear sheet("Wind")
		
		levelsof Parameter, local(levels)
		foreach val of local levels {
			qui sum Estimate if Parameter == "`val'"
			global `val' = `r(mean)'
			local `val' = `r(mean)'
		}
		
		local lifetime = ${lifetime}
		local capacity_factor = ${capacity_factor} // capacity factor for wind
		local credit_life = `lifetime' // credit lasts for lifetime of turbine
		local capacity_reduction = ${capacity_reduction}
		local wind_emissions = ${wind_emissions}
		local hrs = 8760 // hours per year
		local corporate_disc = 0.0673
	
	restore
	
	rebound ${rebound}
	local r = `r(r)'
	
*************************
/* 4. WTP Calculations */
*************************
local annual_mwh = `hrs' * `capacity_factor' // After the first ten years we need to scale this down by the capacity reduction factor

local local_pollutants = 0
local global_pollutants = 0
local last_year = 2020 + `lifetime'

forvalues y = 2020 (1) `last_year'{
	local discount_year = `y' - 2020
	local global_pollutants = `global_pollutants' + (`co2_per_mwh' * `annual_mwh' * ${sc_CO2_2020})/(1 + `discount')^`discount_year'
}

*Calculating lifecycle costs of wind
local wind_emissions = `wind_emissions' * 1000 // Converting from g/kwh to g/mwh

local env_cost = (`wind_emissions' * 1/1000000 * `annual_mwh' * `lifetime') * ${sc_CO2_2020} * `r'

	local val_local_pollutants = `local_pollutants' * -`semie'
	local val_global_pollutants = `global_pollutants' * -`semie'
	local rebound_local = `local_pollutants' * (1-`r') * -`semie'
	local rebound_global = `global_pollutants' * (1-`r') * -`semie'
	local val_env_cost = `env_cost' * -`semie'

* Society
local wtp_society = `val_local_pollutants' + `val_global_pollutants' - `val_env_cost' - `rebound_local' - `rebound_global'

* Private
local wtp_producers = (`hrs'*`capacity_factor') + ((`hrs'*`capacity_factor')/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) // $1 per MWh transfer
local wtp_private = `wtp_producers'

local enviro_ext = `local_pollutants' + `global_pollutants' - `env_cost' - ((`local_pollutants' + `global_pollutants') * (1-`r'))

local enviro_ext_global = (`global_pollutants' * `r') / `enviro_ext'

local program_cost = (`hrs'*`capacity_factor') + ((`hrs'*`capacity_factor')/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1))) // $1 per MWh transfer

*Cost Curve
/*
*Learning by Doing Assumptions
local cum_sales = 742689 // 742689 2020 or 93924 2007, world numbers
local marg_sales = 92490 // 92490 for 2020 or 2007 is 19967, world numbers

local prod_cost = `annual_mwh' * `lifetime' * (`lcoe_2020' - `current_credit')

local subsidy_max = `annual_mwh' * `lifetime' * `current_credit'

cost_curve_masterfile,  demand_elas(`elas') discount_rate(`discount') farmer(`farmer_theta') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`prod_cost') enviro("constant_`enviro_ext'") scc(${sc_CO2_2020}) subsidy_max(`subsidy_max')
	
	local env_cost_wtp_global = (`r(enviro_mvpf)' * `program_cost') * `enviro_ext_global'
	local env_cost_wtp_local = (`r(enviro_mvpf)' * `program_cost') * (1 - `enviro_ext_global')
	local enviro_mvpf_raw = `r(enviro_mvpf)' * 0

	
	local cost_mvpf = `r(cost_mvpf)' * 0
	local cost_wtp = `r(cost_mvpf)' * `program_cost' * 0
	local enviro_wtp = `env_cost_wtp_local' + `env_cost_wtp_global' * 0
// 	local enviro_ext_global = `env_cost_wtp_global' / `enviro_wtp'
	local enviro_ext_global = 0
*/
	
* Total WTP
local WTP = `wtp_private' + `wtp_society' - ((`val_global_pollutants' - `rebound_global' - `val_env_cost') * ${USShareFutureSSC} * ${USShareGovtFutureSCC})
local WTP_cc = `WTP'

local WTP_USPres = 0
local WTP_USFut = ${USShareFutureSSC} * (`val_global_pollutants' - `rebound_global' - `val_env_cost' - ((`val_global_pollutants' - `rebound_global' - `val_env_cost') * ${USShareGovtFutureSCC})) 
local WTP_RoW = ((1 - ${USShareFutureSSC}) * (`val_global_pollutants' - `rebound_global' - `val_env_cost') + (`wtp_private' + `val_local_pollutants' - `rebound_local'))

// // Quick decomposition
// local WTP_USPres = 0
// local WTP_USFut  =     ${USShareFutureSSC}  * (`global_pollutants' - `rebound_global') * (1 - ${USShareGovtFutureSCC})
// local WTP_RoW    = (1 - ${USShareFutureSSC}) * (`global_pollutants' - `rebound_global') + `local_pollutants' + `wtp_cons' - `rebound_local'
**************************
/* 6. Cost Calculations  */
**************************
local fisc_ext_s = (`hrs'* `capacity_factor' * -`semie' * `current_credit') + ((`hrs'* `capacity_factor' * -`semie' * `current_credit')/`discount') * (1 - (1/(1+`discount')^(`lifetime' - 1)))

local fisc_ext_t = 0

local fisc_ext_lr = -1 * (`val_global_pollutants' - `rebound_global' - `val_env_cost') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}

local policy_spending = `program_cost' + `fisc_ext_s'
local total_cost = `program_cost' + `fisc_ext_s' + `fisc_ext_t' + `fisc_ext_lr'

**************************
/* 7. MVPF Calculations */
**************************
local MVPF = (`WTP' / `total_cost')
	

****************
/* 5. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `MVPF'
global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'
global cost_`1' = `total_cost'
global total_cost_`1' = `total_cost'
global WTP_`1' = `WTP'

global wtp_glob_`1' = (`val_global_pollutants' - `val_env_cost') * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_r_loc_`1' = -`rebound_local'
global wtp_r_glob_`1' = -`rebound_global' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
global wtp_loc_`1' = `local_pollutants'
global wtp_prod_`1' = `wtp_producers'

global program_cost_`1' = `program_cost'
global fisc_ext_t_`1' = `fisc_ext_t'
global fisc_ext_s_`1' =  `fisc_ext_s'
global fisc_ext_lr_`1' = `fisc_ext_lr'
global p_spend_`1' = `policy_spending'
global US_MVPF_`1' = (`WTP_USFut' + `WTP_USPres')/`total_cost'

global elas_`1' = `elas'


** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_glob wtp_r_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "wtp_r_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_s fisc_ext_t fisc_ext_lr total_cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_s", "fisc_ext_t", "fisc_ext_lr", "total_cost"
global `1'_name "Cookstoves - India"
global `1'_ep = "N"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3 `""Env" "Global""' 4 `""Rebound" "Global""' 5 `"Total WTP"' 7 `""Program" "Cost""' 8 `""FE" "Subsidies""' 9 `""FE" "Taxes""' 10 `""FE" "Long-Run""' 11 `"Total Cost"' ///

*color groupings
global color_group1_`1' = 2
global color_group2_`1' = 4
global color_group3_`1' = 4
global cost_color_start_`1' = 7
global color_group4_`1' = 10

global note_`1' = `"Publication: " "SCC: `scc'" "Description: "'
global normalize_`1' = 1

di `MVPF'
di `total_cost'
di `WTP'
di `wtp_cons'
di `local_pollutants'
di `global_pollutants'
di `rebound_global'
di `rebound_local'
di `wtp_society'
di `WTP_RoW' + `WTP_USFut' + `WTP_USPres'
di (`WTP_USFut' + `WTP_USPres')/`total_cost'
