*************************************************************************************
/*                            0. Non-Marginal BEV Analysis                         */
*************************************************************************************
clear
global run_year = 2020
global State "US"
insobs 500
gen subsidy = .
gen mvpf = .
gen semie = .
gen net_msrp = .
gen epsilon = .

local elec_dem_elas = -0.190144
local elec_sup_elas = 0.7806420154513118

local bev_cf = "${bev_cf}"
local veh_lifespan_type = substr("${bev_cf}", strpos("${bev_cf}", "_") + 1, .)

local epsilon = 2.1
local pass_through = 0.85

local i = 1
/*
forvalues s = 0(100)10000{

    local epsilon = 2.1

    replace subsidy = `s' in `i'

    * Note this is only run for the current (2020) spec

    display `"All the arguments, as typed by the user, are: `0'"'

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
    if "`4'" == "current"{
        global dollar_year = ${current_year}
    }

    global run_year = ${run_year}
    local dollar_year = ${dollar_year}

    ****************************************************
    /* 3a. EV Counterfactual Vehicle Fuel Economy Data */
    ****************************************************
    preserve
        use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
        forvalues y = 2015(1)2018{
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
        forvalues y = 2015(1)2018{
            replace avg_msrp = avg_msrp * (${cpi_2015} / ${cpi_`y'}) if year == `y'
            qui sum avg_msrp if year == `y'
            local msrp`y' = r(mean)
        }
        * calculating fixed price in paper's sample period for use in calculating a constant elasticity
        local elas_msrp = (`total_sales2015' * `msrp2015' + `total_sales2016' * `msrp2016' + `total_sales2017' * `msrp2017' + `total_sales2018' * `msrp2018') ///
                        / (`total_sales2015' + `total_sales2016' + `total_sales2017' + `total_sales2018')
        use "${assumptions}/evs/processed/kwh_msrp_batt_cap.dta", clear
        keep if year == ${run_year}
        qui sum avg_msrp
        local msrp = r(mean) * (${cpi_`dollar_year'} / ${cpi_${run_year}})
    restore

    ****************************************************
    /* 3f. EV and ICE Age-State-Level VMT Data */
    ****************************************************
    local ub = `lifetime'

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
            local ice_miles_traveled`y' = vmt[`y'] * ${EV_VMT_car_adjustment}
        }
    restore

    ** Fixing EVs vmt at same levels as ICE
    forvalues y = 1(1)`ub'{
        local ev_miles_traveled`y' = `ice_miles_traveled`y''
    }

    ****************************************************
    /* 3h. Cost Curve */
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
        local batt_per_kwh_cost = `prod_cost' * (${cpi_2020} / ${cpi_2018})
    restore

    ****************************************************
    /* 3i. Subsidy Levels */
    ****************************************************
    preserve
        ** Federal Subsidy

        use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
        keep if year >= 2015 & year <= 2018
        egen N = total(subsidy_N)
        egen weighted_avg = total(subsidy_weighted_avg * subsidy_N)
        replace weighted_avg = weighted_avg / N
        qui sum weighted_avg
        local elas_avg_fed_subsidy = r(mean)

        use "${assumptions}/evs/processed/bev_fed_subsidy_data", clear
        keep if year == ${run_year}
		
		if `s' > 604.27{
			local avg_fed_subsidy = `s' - 604.27
			local avg_state_subsidy = 604.27
		}
		
		else{
			local avg_fed_subsidy = 0
			local avg_state_subsidy = `s'
		}
    restore

    ****************************************************
    /* 4. Set local assumptions unique to this policy */
    ****************************************************
    ** Cost assumptions:
    * Program costs - US$
    local rebate_cost = 9000 // Average subsidy (cf. text p. 8)
    local adj_rebate_cost = `rebate_cost' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})
    local avg_subsidy = `adj_rebate_cost'
    local elas_avg_subsidy = `rebate_cost' // state subsidy, always want this in the policy year's dollars

    local avg_subsidy = `avg_state_subsidy'
    ****************************************************
    /*          5. Intermediate Calculations          */
    ****************************************************
    local net_elas_msrp = `elas_msrp' - `elas_avg_fed_subsidy' - 0.5 * `elas_avg_subsidy'
    local epsilon = -`epsilon' // make it negative for the cost curve

    local net_msrp = `msrp' - `avg_subsidy' - `avg_fed_subsidy'
    local total_subsidy = `avg_subsidy' + `avg_fed_subsidy'
    local semie = -`epsilon' / `net_msrp' // the negative sign makes this value positive

    local beh_response = `semie' * `pass_through'

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
    local tax_rate = ${nominal_gas_tax_`dollar_year'} // for Latex

    local fed_fisc_ext = `beh_response' * `avg_fed_subsidy'
    local avg_fed_subsidy_n = `avg_fed_subsidy' / `net_msrp'

    local beh_fisc_ext = `semie' * `avg_subsidy'

    local total_cost = `program_cost' - `utility_fisc_ext' + `gas_fisc_ext' + `fed_fisc_ext' + `beh_fisc_ext'


    *************************
    /* 7. WTP Calculations */
    *************************

    * consumers
    local wtp_cons = `pass_through'
    * dealers/car manufacturers
    local wtp_deal = (1 - `pass_through')

    local wtp_prod_u = 0
    local wtp_prod_s = 0

    if "${value_profits}" == "yes"{

        local tot_gal = ${`bev_cf'_gal_`dollar_year'} // for Latex
        local gas_markup = ${nominal_gas_markup_`dollar_year'} // for Latex

        local wtp_prod_s = `beh_response' * ${`bev_cf'_wtp_prod_s_`dollar_year'} 

        * producers - utilities
        local wtp_prod_u = 0
        local tot_kwh = 0

        forvalues y = 1(1)`ub'{
            local tot_kwh = `tot_kwh' + (`ev_miles_traveled`y'' * `kwh_per_mile') // for Latex
            local wtp_prod_u = `wtp_prod_u' + ((`beh_response' * (`ev_miles_traveled`y'' * `kwh_per_mile') * `util_producer_surplus') / ((1 + `discount')^(`y' - 1)))
        }
    }

    ** take out the corporate effective tax rate
    local total_wtp_prod_s = `wtp_prod_s'
    local wtp_prod_s = `total_wtp_prod_s' * (1 - 0.21)
    local gas_corp_fisc_e = `total_wtp_prod_s' * 0.21

    local profits_fisc_e = `gas_corp_fisc_e' - `utility_fisc_ext'
    local wtp_private = `wtp_cons' + `wtp_deal' - `wtp_prod_s' + `wtp_prod_u'


    * learning by doing
    local prod_cost = `prod_cost' * (${cpi_`dollar_year'} / ${cpi_2018}) // data is in 2018USD

    local batt_cost = `prod_cost' * `batt_cap'
    local batt_frac = `batt_cost' / `msrp'

    local fixed_cost_frac = 1 - `batt_frac'

    local car_theta = `farmer_theta' * `batt_frac'


    ** Externality and WTP for driving a battery electric vehicle

    
    local kwh_used_year_one = `ev_miles_traveled1' * `kwh_per_mile' // for Latex
    local total_bev_damages_glob = ${yes_ev_damages_global_no_r_`dollar_year'} // for Latex
    local total_bev_damages_glob_n = `total_bev_damages_glob' / `net_msrp' // for Latex
    local total_bev_damages_loc_n = -${yes_ev_damages_local_no_r_`dollar_year'} / `net_msrp' // for Latex
    *local ev_first_damages_g = ${ev_first_damages_g_2020} // for Latex

    local wtp_yes_ev_local = -`beh_response' * ${yes_ev_damages_local_no_r_`dollar_year'}
    local wtp_yes_ev_global_tot = -`beh_response' * ${yes_ev_damages_global_no_r_`dollar_year'}
    local wtp_yes_ev_g = `wtp_yes_ev_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

    local q_carbon_yes_ev = -`beh_response' * ${yes_ev_carbon_content_`dollar_year'}
    local q_carbon_yes_ev_mck = -${yes_ev_carbon_content_`dollar_year'}

    local yes_ev_local_ext = `wtp_yes_ev_local' / `beh_response'
    local yes_ev_global_ext_tot = `wtp_yes_ev_global_tot' / `beh_response'

    local wtp_yes_ev = `wtp_yes_ev_local' + `wtp_yes_ev_g'

    local yes_ev_ext = `wtp_yes_ev' / `beh_response'

    ** Calculating the gallons used in the first year of a vehicle's lifetime for Latex
    preserve

        use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vmt_dist_car.dta", clear
        qui sum vmt_avg_car if age == 1
        local vmt_age_1 = `r(mean)'

        use "${user_specific_assumptions}/files_v${user_name}/Vehicle Lifetime Damages/vehicles_${scc_ind_name}_${dr_ind_name}_rbd_${hev_cf}.dta", clear
        qui sum `bev_cf'_mpg if year == 2020
        local cf_mpg_2020 = `r(mean)'

        local gas_consumed_year_one = `vmt_age_1' / `cf_mpg_2020'

    restore

    ** Externality and WTP for driving an ICE vehicle

    local wtp_no_ice_local = `beh_response' * ${`bev_cf'_cf_damages_loc_`dollar_year'}
    local wtp_no_ice_global_tot = `beh_response' * ${`bev_cf'_cf_damages_glob_`dollar_year'}
    local wtp_no_ice_g = `wtp_no_ice_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))

    local total_ice_damages_glob = `wtp_no_ice_global_tot' / `beh_response' // for Latex
    local total_ice_damages_glob_n = `total_ice_damages_glob' / `net_msrp' // for Latex
    local total_ice_damages_loc = `wtp_no_ice_local' / `beh_response' // for Latex
    local total_ice_damages_loc_n = `total_ice_damages_loc' / `net_msrp' // for Latex
    local total_damages_loc_n = `total_bev_damages_loc_n' + `total_ice_damages_loc_n' // for Latex

    local q_carbon_no_ice = `beh_response' * ${`bev_cf'_cf_carbon_`dollar_year'}
    local q_carbon_no_ice_mck = ${`bev_cf'_cf_carbon_`dollar_year'}

    local no_ice_local_ext = `wtp_no_ice_local' / `beh_response'
    local no_ice_global_ext_tot = `wtp_no_ice_global_tot' / `beh_response'

    local wtp_no_ice = `wtp_no_ice_local' + `wtp_no_ice_g'


    local no_ice_ext = `wtp_no_ice' / `beh_response'

    *** Battery manufacturing emissions, 59.5 kg CO2eq/kWh for NMC111 batteries ***

    * Averaging the SCC for 2015-2018
    local relevant_scc = ${sc_CO2_`dollar_year'}

    local batt_emissions = 59.5 * `batt_cap' // for Latex

    local batt_damages = `batt_emissions' * 0.001 * `relevant_scc'
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

    local prod_cost = `prod_cost' * `batt_cap' // cost of a battery in a car as opposed to cost per kWh

    * learning-by-doing

    *temporary solution -> if bootstrap gets a positive elasticity, hardcode epsilon
    if `epsilon' > 0{
        local epsilon = -0.001
    }

    local lbd_cf = ("`bev_cf'" == "new_car")
    ** --------------------- COST CURVE --------------------- **
    cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
                           curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_local) ///
                           start_year(`dollar_year') scc(${scc_import_check}) new_car(`lbd_cf')
    local dyn_enviro_local = `r(enviro_mvpf)'

    cost_curve_masterfile, demand_elas(`epsilon') discount_rate(`discount') farmer(`farmer_theta') fcr(`fixed_cost_frac') ///
                           curr_prod(`marg_sales') cum_prod(`cum_sales') price(`net_msrp') enviro(ev_global) ///
                           start_year(`dollar_year') scc(${scc_import_check}) new_car(`lbd_cf')
    local dyn_enviro_global_tot = `r(enviro_mvpf)'
    local dyn_enviro_global = `dyn_enviro_global_tot' * ((1 - ${USShareFutureSSC}) + ${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC}))
    local dyn_price = `r(cost_mvpf)'
    local cost_wtp = `r(cost_mvpf)' * `program_cost' * 0.85 // pass-through
    local env_cost_wtp = (`dyn_enviro_local' + `dyn_enviro_global') * `program_cost' * 0.85 // pass-through
    local env_cost_wtp_l = `dyn_enviro_local' * `program_cost' * 0.85
    local env_cost_wtp_global_tot = `dyn_enviro_global_tot' * `program_cost' * 0.85
    local env_cost_wtp_g = `dyn_enviro_global' * `program_cost' * 0.85

    local q_carbon = `q_carbon_no_ice' + `q_carbon_yes_ev' + `q_carbon_rbd'
    local q_carbon_no = `q_carbon'
    local q_carbon_cost_curve = `dyn_enviro_global_tot' / ${sc_CO2_`dollar_year'}
    local q_carbon_cost_curve_mck = `q_carbon_cost_curve' / `beh_response'
    local q_carbon_mck = `q_carbon_no_ice_mck' + `q_carbon_yes_ev_mck' + `q_carbon_rbd_mck' 
    local q_carbon = `q_carbon' + `q_carbon_cost_curve'


    ********** Long-Run Fiscal Externality **********

    local fisc_ext_lr = -1 * (`wtp_no_ice_global_tot' + `wtp_yes_ev_global_tot' + `wtp_soc_rbd_global_tot' + `env_cost_wtp_global_tot' + `batt_man_ext_tot') * ${USShareFutureSSC} * ${USShareGovtFutureSCC}
    local total_cost = `total_cost' + `fisc_ext_lr' + `gas_corp_fisc_e'

    ************************************************
    local wtp_savings = 0

    * Total WTP
    local WTP = `wtp_private' + `wtp_soc' + `wtp_soc_rbd' + `wtp_savings' // not including learning-by-doing
    local WTP_cc = `WTP' + `cost_wtp' + `env_cost_wtp'

    // Quick Decomposition

    /* Assumptions:

        - wtp_private, cost_wtp -> US Present
        - wtp_soc, env_cost_wtp -> US Future & Rest of the World

    */

    local WTP_USPres = `wtp_private' + `wtp_yes_ev_local' + `wtp_no_ice_local' + `env_cost_wtp_l' + `wtp_soc_rbd_l'
    local WTP_USFut = (${USShareFutureSSC} * (1 - ${USShareGovtFutureSCC})) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot') + 0.1 * `cost_wtp'
    local WTP_RoW = (1 - ${USShareFutureSSC}) * (`wtp_yes_ev_global_tot' + `wtp_no_ice_global_tot' + `env_cost_wtp_global_tot' + `wtp_soc_rbd_global_tot') + 0.9 * `cost_wtp'

    **************************
    /* 8. MVPF Calculations */
    **************************

    local MVPF = `WTP_cc' / `total_cost'
    local MVPF_no_cc = `WTP' / `total_cost'

    replace mvpf = `MVPF' in `i'

    local ++i

}
save "${output_fig}/figures_data/bevs_non_marginal_mvpfs", replace
*/
***************************************************************************


*Creating Graphs
use "${output_fig}/figures_data/bevs_non_marginal_mvpfs", clear

local total_subsidy_ira = 604.27 + 7500 + 42.97887
local total_subsidy_2020 = 604.27 + 42.97887

qui sum mvpf if subsidy <= `total_subsidy_ira'
local avg_mvpf_0_ira = `r(mean)'
di `avg_mvpf_0_ira'

qui sum mvpf if subsidy > `total_subsidy_2020' & subsidy <= `total_subsidy_ira'
local avg_mvpf_2020_ira = `r(mean)'
di `avg_mvpf_2020_ira'


local bar_dark_blue = "8 51 97"
local bar_blue = "36 114 237"
local bar_light_blue = "115 175 235"
local bar_light_orange = "252 179 72"
local bar_dark_orange = "214 118 72"
local bar_light_gray = "181 184 191"

twoway (line mvpf subsidy, color("`bar_light_blue'")), ///
       legend(region(lwidth(vthin) lcolor(black))) ///
       ytitle("MVPF") ///
       xtitle("Total Subsidy Level") ///
       ylabel(#5, nogrid) ///
       xlabel( , nogrid) ///
       yline(1) ///
       xline(`total_subsidy_2020' `total_subsidy_ira', lpattern(solid) lcolor("`bar_blue'") lwidth(vthin)) ///
       yline(`avg_mvpf_2020_ira', lpattern(solid) lcolor("`bar_blue'") lwidth(vthin)) ///
       xscale(range(0 10000)) ///
       plotregion(margin(0))

graph export "${output_fig}/figures_appendix/Ap_Fig_4_non_marginal.png", replace
cap graph export "${output_fig}/figures_appendix/Ap_Fig_4_non_marginal.wmf", replace


