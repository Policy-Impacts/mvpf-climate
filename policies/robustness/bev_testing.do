/*
*************************************************************************************
/*                         0. Program: BEV Testing                      */
*************************************************************************************

*/

display `"All the arguments, as typed by the user, are: `0'"'

local elec_dem_elas = -0.190144
local elec_sup_elas = 0.7806420154513118

local bev_cf = "${bev_cf}"
local veh_lifespan_type = substr("${bev_cf}", strpos("${bev_cf}", "_") + 1, .)

********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
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

local farmer_theta = -0.421

****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************

global dollar_year = ${current_year}

global run_year = 2020
local dollar_year = ${dollar_year}

****************************************************
/* 3a. EV Counterfactual Vehicle Fuel Economy Data */
****************************************************
preserve
    use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
    forvalues y = 2011(1)2014{
        qui sum total_sales if year == `y'
        local total_sales`y' = r(mean)
    }
    keep if year == ${run_year}
    qui sum cf_mpg
    local ev_cf_mpg = r(mean)
restore

****************************************************
/* 3b. Gas Price and Tax Data */
****************************************************


preserve
    use "${gas_fleet_emissions}/fleet_year_final", clear
    keep if fleet_year==${run_year}
    
    qui ds *_gal
    foreach var in `r(varlist)' {
        replace `var' = `var'/1000000
        * Converting from grams per gallon to metric tons per gallon.
        qui sum `var'
        local `var' = r(mean)
    }
restore

preserve
    use "${user_specific_assumptions}/files_v${user_name}/Gasoline Prices, Markups, and Taxes/gas_data_final", clear
            
    gen real_gas_price = gas_price*(${cpi_${dollar_year}} / index) 
    gen real_tax_rate = avg_tax_rate*(${cpi_${dollar_year}} / index)
    gen real_markup = markup * (${cpi_${dollar_year}} / index)
            
    keep if year==${run_year}
        
    local consumer_price = real_gas_price 
    * Consumer price = includes taxes. 
    local tax_rate = real_tax_rate
    local markup = real_markup

restore

****************************************************
/* 3c. EV Specific Assumptions */
****************************************************
preserve
    qui import excel "${policy_assumptions}", first clear sheet("evs")
        
    levelsof Parameter, local(levels)
    foreach val of local levels {
        qui sum Estimate if Parameter == "`val'"
        global `val' = `r(mean)'
    }
        
    local val_given = ${val_given}
    local lifetime = ${vehicle_`veh_lifespan_type'_lifetime}
restore

****************************************************
/* 3d. EV Energy Consumption Data */
****************************************************
preserve
    use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
    keep if year == ${run_year}
    qui sum avg_kwh_per_mile
    local kwh_per_mile = r(mean)
    qui sum avg_batt_cap
    local batt_cap = r(mean)
restore


****************************************************
/*                  3e. EV Price Data             */
****************************************************
preserve
    use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
    forvalues y = 2011(1)2014{
        replace avg_msrp = avg_msrp * (${cpi_2011} / ${cpi_`y'}) if year == `y'
        qui sum avg_msrp if year == `y'
        local msrp`y' = r(mean)
    }
    * calculating fixed price in paper's sample period for use in calculating a constant elasticity
    local elas_msrp = (`total_sales2011' * `msrp2011' + `total_sales2012' * `msrp2012' + `total_sales2013' * `msrp2013' + `total_sales2014' * `msrp2014') ///
                    / (`total_sales2011' + `total_sales2012' + `total_sales2013' + `total_sales2014')
    
    use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
    keep if year == ${run_year}
    qui sum avg_msrp
    local msrp = r(mean) * (${cpi_`dollar_year'} / ${cpi_${run_year}})
restore

****************************************************
/* 3f. EV and ICE Age-State-Level VMT Data */
****************************************************
preserve
    
    use "${assumptions}/evs/processed/ev_vmt_by_age", clear
    local ub = `lifetime'
    duplicates drop age vmt, force
    sort age
    forvalues y = 1(1)`ub'{
        local ev_miles_traveled`y' = vmt[`y']
    }

restore

preserve
    
    use "${assumptions}/evs/processed/ice_vmt_by_age", clear
    duplicates drop age vmt, force
    sort age
    forvalues y = 1(1)`ub'{
        local ice_miles_traveled`y' = vmt[`y']
    }

restore

** Fixing EVs vmt at same levels as ICE
forvalues y = 1(1)`ub'{
    local ev_miles_traveled`y' = `ice_miles_traveled`y''
}

****************************************************
/* 3g. Cost Curve */
****************************************************
preserve
    use "${assumptions}/evs/processed/battery_sales_combined", clear
    keep if year == `dollar_year'
    qui sum cum_sales
    local cum_sales = r(mean)
    qui sum marg_sales
    local marg_sales = r(mean)		
restore

preserve
    use "${assumptions}/evs/processed/cyl_batt_costs_combined", clear
    
    keep if year == `dollar_year'
    qui sum prod_cost_2018
    local prod_cost = r(mean)
    local batt_per_kwh_cost = `prod_cost'

restore

****************************************************
/* 3i. Subsidy Levels */
****************************************************
preserve
    ** Federal Subsidy

    use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
    keep if year >= 2011 & year <= 2014
    egen N = total(subsidy_N)
    egen weighted_avg = total(subsidy_weighted_avg * subsidy_N)
    replace weighted_avg = weighted_avg / N
    qui sum weighted_avg
    local elas_avg_fed_subsidy = r(mean)

    use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
    keep if year == ${run_year}
    qui sum subsidy_weighted_avg
    local avg_fed_subsidy = r(mean)

    local avg_state_subsidy = 604.27 // see NST-EST2023-POP spreadsheet
restore

****************************************************
/* 4. Set local assumptions unique to this policy */
****************************************************
** Cost assumptions:
* Program costs - US$, (Table 8)
local rebate_cost = 185444000
local elas_avg_subsidy = `rebate_cost' / 69972

local avg_subsidy = `avg_state_subsidy'

****************************************************
/*          5. Intermediate Calculations          */
****************************************************
local epsilon = -${feed_in_elas}
local net_msrp = `msrp' - `avg_subsidy' - `avg_fed_subsidy'
local semie = -`epsilon' / `net_msrp'

local beh_response = `semie'

* oil producers
local producer_price = `consumer_price' - `tax_rate'
local producer_mc = `producer_price' - `markup'

* utility companies

local util_gov_revenue ${government_revenue_`dollar_year'_${State}}
local util_producer_surplus ${producer_surplus_`dollar_year'_${State}}


**************************
/* 6. Cost Calculations  */
**************************

* Program cost
local program_cost = 1

local utility_fisc_ext = 0
forvalues y = 1(1)`ub'{
    local utility_fisc_ext = `utility_fisc_ext' + (`beh_response' * `ev_miles_traveled`y'' * `kwh_per_mile' * `util_gov_revenue') / ((1 + `discount')^(`y' - 1)) // gain in profit tax from highter utility profits + gain in gov revenue since 28% of utilities are publicly owned
}


local gas_fisc_ext = `beh_response' * ${`bev_cf'_cf_gas_fisc_ext_`dollar_year'}
local fed_fisc_ext = `beh_response' * `avg_fed_subsidy'

local beh_fisc_ext = `semie' * `avg_subsidy'

local total_cost = `program_cost' - `utility_fisc_ext' + `gas_fisc_ext' + `fed_fisc_ext' + `beh_fisc_ext'


*************************
/* 7. WTP Calculations */
*************************

* consumers
local wtp_cons = 1

local wtp_prod_u = 0
local wtp_prod_s = 0

if "${value_profits}" == "yes"{

    
    local wtp_prod_s = `beh_response' * ${`bev_cf'_wtp_prod_s_`dollar_year'} 

    * producers - utilities
    local wtp_prod_u = 0
    forvalues y = 1(1)`ub'{
        local wtp_prod_u = `wtp_prod_u' + ((`beh_response' * (`ev_miles_traveled`y'' * `kwh_per_mile') * `util_producer_surplus') / ((1 + `discount')^(`y' - 1)))
    }
}

** take out the corporate effective tax rate
local total_wtp_prod_s = `wtp_prod_s'
local wtp_prod_s = `total_wtp_prod_s' * (1 - 0.21)
local gas_corp_fisc_e = `total_wtp_prod_s' * 0.21

local profits_fisc_e = `gas_corp_fisc_e' - `utility_fisc_ext'

local wtp_private = `wtp_cons' - `wtp_prod_s' + `wtp_prod_u'



* learning by doing
local prod_cost = `prod_cost' * (${cpi_`dollar_year'} / ${cpi_2018}) // data is in 2018USD



local batt_cost = `prod_cost' * `batt_cap'

local batt_frac = `batt_cost' / `msrp'

local fixed_cost_frac = 1 - `batt_frac'

local car_theta = `farmer_theta' * `batt_frac'




** Externality and WTP for driving a battery electric vehicle
local wtp_yes_ev_local = -`beh_response' * ${yes_ev_damages_local_no_r_`dollar_year'}
local wtp_yes_ev_global_tot = -`beh_response' * ${yes_ev_damages_global_no_r_`dollar_year'}
local wtp_yes_ev_g = `wtp_yes_ev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

local q_carbon_yes_ev = -`beh_response' * ${yes_ev_carbon_content_`dollar_year'}
local q_carbon_yes_ev_mck = -${yes_ev_carbon_content_`dollar_year'}

local yes_ev_local_ext = `wtp_yes_ev_local' / `beh_response'
local yes_ev_global_ext_tot = `wtp_yes_ev_global_tot' / `beh_response'
local wtp_yes_ev = `wtp_yes_ev_local' + `wtp_yes_ev_g'


local yes_ev_ext = `wtp_yes_ev' / `beh_response'

** Externality and WTP for driving an ICE vehicle

local wtp_no_ice_local = `beh_response' * ${`bev_cf'_cf_damages_loc_`dollar_year'}
local wtp_no_ice_global_tot = `beh_response' * ${`bev_cf'_cf_damages_glob_`dollar_year'}
local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

local q_carbon_no_ice = `beh_response' * ${`bev_cf'_cf_carbon_`dollar_year'}
local q_carbon_no_ice_mck = ${`bev_cf'_cf_carbon_`dollar_year'}

local no_ice_local_ext = `wtp_no_ice_local' / `beh_response'
local no_ice_global_ext_tot = `wtp_no_ice_global_tot' / `beh_response'

local wtp_no_ice = `wtp_no_ice_local' + `wtp_no_ice_g'


local no_ice_ext = `wtp_no_ice' / `beh_response'


*** Battery manufacturing emissions, 59.5 kg CO2eq/kWh for NMC111 batteries ***

local relevant_scc = ${sc_CO2_`dollar_year'}

local batt_emissions = 59.5 * `batt_cap' // for Latex

local batt_damages_n = (`batt_emissions' * 0.001 * `relevant_scc') / `net_msrp'

local batt_man_ext = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
local batt_man_ext_tot = `batt_emissions' * 0.001 * `beh_response' * `relevant_scc'

local wtp_soc = `wtp_yes_ev' + `wtp_no_ice' - `batt_man_ext'
local wtp_glob = `wtp_yes_ev_g' + `wtp_no_ice_g' - `batt_man_ext'
local wtp_loc = `wtp_yes_ev_local' + `wtp_no_ice_local'



** rebound effect
local rbd_coeff = (1 / (1 - (`elec_dem_elas'/`elec_sup_elas')))
local wtp_soc_rbd =  -(1 - `rbd_coeff') * `wtp_yes_ev'
local wtp_soc_rbd_l = -(1 - `rbd_coeff') * `wtp_yes_ev_local'
local wtp_soc_rbd_global_tot = -(1 - `rbd_coeff') * `wtp_yes_ev_global_tot'
local wtp_soc_rbd_g = -(1 - `rbd_coeff') * `wtp_yes_ev_g'

    
local q_carbon_rbd = -(1 - `rbd_coeff') * `q_carbon_yes_ev'
local q_carbon_rbd_mck = -(1 - `rbd_coeff') * `q_carbon_yes_ev_mck'

* Adding the rebound effect to the utility producer WTP
local wtp_private = `wtp_private' - (1 - `rbd_coeff') * `wtp_prod_u'
local wtp_prod_u = `rbd_coeff' * `wtp_prod_u' 

* Adding the rebound effect to the utility fiscal externality
local total_cost = `total_cost' + (1 - `rbd_coeff') * `utility_fisc_ext'
local utility_fisc_ext =  `utility_fisc_ext' - (1 - `rbd_coeff') * `utility_fisc_ext' // rebound makes the utility fe smaller

local local_enviro_ext = (`wtp_no_ice_local' + `wtp_yes_ev_local') / `beh_response'
local global_enviro_ext_tot = (`wtp_no_ice_global_tot' + `wtp_yes_ev_global_tot') / `beh_response'

local enviro_ext = `wtp_soc' / `beh_response'

local enviro_ext = `enviro_ext' + (`wtp_soc_rbd' / `beh_response')
local local_enviro_ext = `local_enviro_ext' + (`wtp_soc_rbd_l' / `beh_response')
local global_enviro_ext_tot = `global_enviro_ext_tot' + (`wtp_soc_rbd_global_tot' / `beh_response')

local prod_cost = `prod_cost' * `batt_cap' // cost of a battery in a car as opposed to cost per kWh

* learning-by-doing

*temporary solution -> if bootstrap gets a positive elasticity, hardcode epsilon
if `epsilon' > 0{
    local epsilon = -0.001
}

local lbd_cf = ("`bev_cf'" == "new_car")
** --------------------- COST CURVE --------------------- **
cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_local) scc(${scc_import_check}) new_car(`lbd_cf')
local dyn_enviro_local = `r(enviro_mvpf)'

cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_global) scc(${scc_import_check}) new_car(`lbd_cf')
local dyn_enviro_global_tot = `r(enviro_mvpf)'
local dyn_enviro_global = `dyn_enviro_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

local dyn_price = `r(cost_mvpf)'
local cost_wtp = `r(cost_mvpf)' * `program_cost'
local env_cost_wtp = (`dyn_enviro_local' + `dyn_enviro_global') * `program_cost'
local env_cost_wtp_l = `dyn_enviro_local' * `program_cost'
local env_cost_wtp_global_tot = `dyn_enviro_global_tot' * `program_cost'
local env_cost_wtp_g = `dyn_enviro_global' * `program_cost'

local q_carbon = `q_carbon_no_ice' + `q_carbon_yes_ev' + `q_carbon_rbd'
local q_carbon_no = `q_carbon'
local q_carbon_cost_curve = `dyn_enviro_global_tot' / ${sc_CO2_`dollar_year'}
local q_carbon_cost_curve_mck = `q_carbon_cost_curve' / `beh_response'
local q_carbon_mck = `q_carbon_no_ice_mck' + `q_carbon_yes_ev_mck' + `q_carbon_rbd_mck' 
local q_carbon = `q_carbon' + `q_carbon_cost_curve'


********** Long-Run Fiscal Externality **********

local fisc_ext_lr = -1 * (`wtp_no_ice_global_tot' + `wtp_yes_ev_global_tot' + `wtp_soc_rbd_global_tot' + `env_cost_wtp_global_tot' + `batt_man_ext_tot') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
local total_cost = `total_cost' + `fisc_ext_lr' + `gas_corp_fisc_e'

*************************************************

// Quick Decomposition

/* Assumptions:

    - wtp_private, cost_wtp -> US Present
    - wtp_soc, env_cost_wtp -> US Future & Rest of the World

*/

* Total WTP
local WTP = `wtp_private' + `wtp_soc' + `wtp_soc_rbd' // not including learning-by-doing
local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp'

local WTP_USPres = `wtp_private' + `wtp_yes_ev_local' + `wtp_no_ice_local' + `env_cost_wtp_l' + `wtp_soc_rbd_l'
local WTP_USFut = (${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC})) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot') + 0.1 * `cost_wtp'
local WTP_RoW = (1 - ${USShareFutureSSC}) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot') + 0.9 * `cost_wtp'

**************************
/* 8. MVPF Calculations */
**************************

local MVPF = `WTP_cc' / `total_cost'
local MVPF_no_cc = `WTP' / `total_cost'

global MVPF_bev_testing `MVPF' 
global cost_bev_testing `total_cost' 
global WTP_cc_bev_testing `WTP_cc'
