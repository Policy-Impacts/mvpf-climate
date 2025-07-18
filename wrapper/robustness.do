/*-----------------------------------------------------------------------
* Run Calculations for Different Specifications
*-----------------------------------------------------------------------*/

tempname numbers
tempfile robustness_values
postfile `numbers' str80 label value using `robustness_values', replace

local pattern_suffix = "full_current_193"
di in yellow "Looking for folders ending with pattern: `pattern_suffix'"

* Find all folders in the results directory that end with the pattern
local results_dir = "${code_files}/4_results"
local folder_list = ""
local folder_dates = ""

* Get list of all subdirectories
qui local folders : dir "`results_dir'" dirs "*"

* Filter folders that end with our pattern and extract timestamps
foreach folder of local folders {
	    di in red "Checking: `folder' against pattern: __`pattern_suffix'$"
    if regexm("`folder'", "^([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})__`pattern_suffix'$") {
        local timestamp = regexs(1)
        local folder_list = "`folder_list' `folder'"
        local folder_dates = "`folder_dates' `timestamp'"
        di in green "Found matching folder: `folder' (timestamp: `timestamp')"
    }
}

* If no matching folders found, display error and exit
if "`folder_list'" == "" {
    di as error "`pattern_suffix' folder has not been created, please run the masterfile first to create this folder"
    exit 601
}
else {
    * Find the most recent folder by comparing timestamps
    local most_recent_folder = ""
    local most_recent_timestamp = ""
    
    local folder_count : word count `folder_list'
    local date_count : word count `folder_dates'
    
    forvalues i = 1/`folder_count' {
        local current_folder : word `i' of `folder_list'
        local current_timestamp : word `i' of `folder_dates'
        
        * Convert timestamp to comparable format (remove hyphens and underscores)
        local current_numeric = subinstr(subinstr("`current_timestamp'", "-", "", .), "_", "", .)
        
        if "`most_recent_timestamp'" == "" {
            local most_recent_folder = "`current_folder'"
            local most_recent_timestamp = "`current_numeric'"
        }
        else {
            local most_recent_numeric = subinstr(subinstr("`most_recent_timestamp'", "-", "", .), "_", "", .)
            if `current_numeric' > `most_recent_numeric' {
                local most_recent_folder = "`current_folder'"
                local most_recent_timestamp = "`current_numeric'"
            }
        }
    }
    
    local main_data_set = "`most_recent_folder'"
    di in green "Selected most recent folder: `main_data_set'"
}


* local main_data_set = "2024-11-15_09-44-45__full_current_193_nov"
global lbd "yes"

*----------------------
* 1 - Electric Vehicles
*----------------------

run_program muehl_efmp
post `numbers' ("muehl_efmp_no_ice_local") (${wtp_no_ice_local_muehl_efmp})

post `numbers' ("muehl_efmp_no_ice") (${wtp_no_ice_muehl_efmp})

post `numbers' ("muehl_efmp_yes_ev_local") (${wtp_yes_ev_local_muehl_efmp})

post `numbers' ("muehl_efmp_wtp_yes_ev") (${wtp_yes_ev_muehl_efmp})

post `numbers' ("muehl_efmp_rbd_glob") (${wtp_soc_rbd_g_muehl_efmp})

post `numbers' ("muehl_efmp_rbd_loc") (${wtp_soc_rbd_l_muehl_efmp})

post `numbers' ("muehl_efmp_batt_damages") (${batt_damages_muehl_efmp})

post `numbers' ("muehl_efmp_wtp_batt") (${wtp_batt_muehl_efmp})

post `numbers' ("gas_markup_percent") (${nominal_gas_markup_2020} / ${nominal_gas_price_2020})

run_program muehl_efmp, ev_fed_subsidy(7500)

post `numbers' ("muehl_efmp_fe_7500") (${total_cost_muehl_efmp} - ${program_cost_muehl_efmp})

post `numbers' ("muehl_efmp_mvpf_7500") (${MVPF_muehl_efmp})

run_program muehl_efmp, ev_fed_subsidy(0)

post `numbers' ("muehl_efmp_mvpf_0") (${MVPF_muehl_efmp}) 

tempname ev_non_marg
tempfile ev_non_marginal_mvpf
postfile `ev_non_marg' subsidy mvpf using `ev_non_marginal_mvpf' 

forvalues s = 0(50)10000{

    run_program muehl_efmp, ev_fed_subsidy(`s')
    post `ev_non_marg' (`s') (${MVPF_muehl_efmp})

}

postclose `ev_non_marg'

use `ev_non_marginal_mvpf', clear

sum mvpf if subsidy >= 647.24887 & subsidy 
local non_marg_mvpf = r(mean)

post `numbers' ("muehl_efmp_non_marg_mvpf") (`non_marg_mvpf')


* category avg MVPF with average new car counterfactual

di in red "Calculating category avg MVPF with average new car counterfactual..."
run_program muehl_efmp, bev_cf_value(new_car)
run_program federal_ev, bev_cf_value(new_car)
run_program bev_state, bev_cf_value(new_car)

post `numbers' ("evs_avg_new_car_mvpf") ((${WTP_cc_muehl_efmp} + ${WTP_cc_federal_ev} + ${WTP_cc_bev_state}) / (${cost_muehl_efmp} + ${cost_federal_ev} + ${cost_bev_state})) 

* category avg MVPF with average new car counterfactual and VMT = 1 (not the 0.6ish number)
* need new time paths for VMT adjustment

di in red "Calculating category avg MVPF with average new car counterfactual and VMT = 1..."
run_program muehl_efmp, bev_cf_value(new_car) vmt_adjust(1) macros("yes")
run_program federal_ev, bev_cf_value(new_car) vmt_adjust(1) macros("no")
run_program bev_state, bev_cf_value(new_car) vmt_adjust(1) macros("no")

post `numbers' ("evs_VMT_1_mvpf") ((${WTP_cc_muehl_efmp} + ${WTP_cc_federal_ev} + ${WTP_cc_bev_state}) / (${cost_muehl_efmp} + ${cost_federal_ev} + ${cost_bev_state}))

* category avg MVPF with CA grid

di in red "Calculating category avg MVPF with CA grid..."
run_program muehl_efmp, ev_grid("CA") macros("yes")
run_program federal_ev, ev_grid("CA") macros("no")
run_program bev_state, ev_grid("CA") macros("no")

post `numbers' ("evs_ca_mvpf") ((${WTP_cc_muehl_efmp} + ${WTP_cc_federal_ev} + ${WTP_cc_bev_state}) / (${cost_muehl_efmp} + ${cost_federal_ev} + ${cost_bev_state}))

* category avg MVPF with MI grid

di in red "Calculating category avg MVPF with MI grid..."
run_program muehl_efmp, ev_grid("MI") macros("yes")
run_program federal_ev, ev_grid("MI") macros("no")
run_program bev_state, ev_grid("MI") macros("no")
global ev_grid = "US" // reset EV grid back to US

post `numbers' ("evs_mi_mvpf") ((${WTP_cc_muehl_efmp} + ${WTP_cc_federal_ev} + ${WTP_cc_bev_state}) / (${cost_muehl_efmp} + ${cost_federal_ev} + ${cost_bev_state})) 


*--------------------
* 2 - Hybrid Vehicles
*--------------------

* category avg MVPF with average new car counterfactual

run_program hev_usa_s, hev_cf_value(new_car)
run_program hev_usa_i, hev_cf_value(new_car)
run_program hybrid_cr, hev_cf_value(new_car)

post `numbers' ("hevs_avg_new_car_mvpf") ((${WTP_cc_hev_usa_s} + ${WTP_cc_hev_usa_i} + ${WTP_cc_hybrid_cr}) / (${cost_hev_usa_s} + ${cost_hev_usa_i} + ${cost_hybrid_cr})) 

* hybrid_cr MVPF with avg new car cf

run_program hybrid_cr, hev_cf_value(new_car)

post `numbers' ("hybrid_cr_new_car_mvpf") (${MVPF_hybrid_cr})

* hev_usa_s MVPF with avg new car cf

run_program hev_usa_s, hev_cf_value(new_car)

post `numbers' ("hev_usa_s_new_car_mvpf") (${MVPF_hev_usa_s}) 

*-----------
* 3 - Nudges
*-----------

* her_compiled global rebound

run_program her_compiled

post `numbers' ("her_compiled_rbd_glob") (${wtp_r_glob_her_compiled} / ${program_cost_her_compiled})

* her_compiled local rebound

post `numbers' ("her_compiled_rbd_loc") (${wtp_r_loc_her_compiled} / ${program_cost_her_compiled}) 

*----------------------
* 4 - International
*----------------------

* US-only cookstoves MVPF


* Cost components of 2020 cookstove policy.
run_program cookstoves

post `numbers' ("cookstoves_subsidy_2020_dollars") (${cookstove_subsidy} * (${cpi_2020} / ${cpi_2019}))
post `numbers' ("climate_FE_per_ton") (${sc_CO2_2020} - (${sc_CO2_2020} * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
post `numbers' ("cookstoves_us_mvpf") (${WTP_USFut_cookstoves} / ${cost_cookstoves})

* net cost of cookstoves assuming 100% of SCC is from economic productivity

post `numbers' ("cookstoves_cost_scc_econ") (${alt_cost_cookstoves})

* US-only MVPF for cookstoves assuming 100% of SCC is economic productivity

post `numbers' ("cookstoves_us_mvpf_scc_econ") (${alt_US_MVPF_cookstoves})

* US-only MVPF for cookstoves assuming 0% of SCC is economic productivity
post `numbers' ("cookstoves_us_mvpf_scc_no_econ") ((${WTP_USFut_cookstoves} + ${WTP_USPres_cookstoves} + ${fisc_ext_lr_cookstoves}) / ${program_cost_cookstoves})

post `numbers' ("cookstoves_mvpf_scc_no_econ") ((${WTP_USFut_cookstoves} + ${WTP_USPres_cookstoves} + ${WTP_RoW_cookstoves} + ${fisc_ext_lr_cookstoves}) / ${program_cost_cookstoves})


* sl_offset US-only MVPF

run_program sl_offset

post `numbers' ("sl_offset_us_mvpf") (${WTP_USFut_sl_offset} / ${cost_sl_offset})

* ug_deforest US-only MVPF

run_program ug_deforest

post `numbers' ("ug_deforest_us_mvpf") (${WTP_USFut_ug_deforest} / ${cost_ug_deforest})

* mx_deforest US-only MVPF

run_program mx_deforest

post `numbers' ("mx_deforest_us_mvpf") (${WTP_USFut_mx_deforest} / ${cost_mx_deforest})

* rice_in_st US-only MVPF

run_program rice_in_st

post `numbers' ("rice_in_st_us_mvpf") (${WTP_USFut_rice_in_st} / ${cost_rice_in_st})

* rice_in_up US-only MVPF

run_program rice_in_up

post `numbers' ("rice_in_up_us_mvpf") (${WTP_USFut_rice_in_up} / ${cost_rice_in_up})

* india_offset US-only MVPF

run_program india_offset

post `numbers' ("india_offset_us_mvpf") (${WTP_USFut_india_offset} / ${cost_india_offset})

* india_offset elasticity

post `numbers' ("india_offset_elasticity") (${elas_india_offset})

* cookstoves global enviro before normalizing by program cost

run_program cookstoves
post `numbers' ("wtp_soc_g_cookstoves") (${wtp_soc_g_cookstoves})


*--------------------------------------------
* 5 - Electricity
*--------------------------------------------
*Electric Utility Markups
post `numbers' ("electricity_markup") (1 - ${cost_price_US_2020}) // Created in gas_electricity_externalities.do

*--------------------------------------------
* 6 - Wind
*--------------------------------------------

*1.13% increase in wind production for a 1% decrease in prices
run_program hitaj_ptc
post `numbers' ("hitaj_wind_response") (${epsilon_hitaj_ptc}) // Created in hitaj_ptc.do policy file

*Wind category average MVPF w/ constant semie
global constant_semie = "yes"
run_program hitaj_ptc
run_program metcalf_ptc
run_program shirmali_ptc

di ((${WTP_cc_hitaj_ptc} + ${WTP_cc_metcalf_ptc} + ${WTP_cc_shirmali_ptc}) / (${cost_hitaj_ptc} + ${cost_metcalf_ptc} + ${cost_shirmali_ptc}))

post `numbers' ("wind_average_constant_semie") ((${WTP_cc_hitaj_ptc} + ${WTP_cc_metcalf_ptc} + ${WTP_cc_shirmali_ptc}) / (${cost_hitaj_ptc} + ${cost_metcalf_ptc} + ${cost_shirmali_ptc}))
global constant_semie = "no"

*Wind average with European wind subsidies
use "${code_files}/4_results/`main_data_set'/compiled_results_all_uncorrected_vJK", clear 

keep if inlist(program, "hitaj_ptc", "metcalf_ptc", "shirmali_ptc", "nicolini_eu", "hitaj_ger", "bolk_UK", "bolk_Spain", "bolk_France", "bolk_Germany")

qui sum component_value if component_type == "WTP_cc"
local total_WTP = `r(sum)'

qui sum component_value if component_type == "cost"
local total_Cost = `r(sum)'

post `numbers' ("wind_average_european") (`total_WTP'/`total_Cost')


*Scale LCOE by 50%
global lcoe_scaling = "yes"
global scalar = 1.5

run_program hitaj_ptc
run_program metcalf_ptc
run_program shirmali_ptc

post `numbers' ("wind_lcoe_150_percent") ((${WTP_cc_hitaj_ptc} + ${WTP_cc_metcalf_ptc} + ${WTP_cc_shirmali_ptc}) / (${cost_hitaj_ptc} + ${cost_metcalf_ptc} + ${cost_shirmali_ptc}))


*Scale LCOE by 200%
global scalar = 2

run_program hitaj_ptc
run_program metcalf_ptc
run_program shirmali_ptc

post `numbers' ("wind_lcoe_200_percent") ((${WTP_cc_hitaj_ptc} + ${WTP_cc_metcalf_ptc} + ${WTP_cc_shirmali_ptc}) / (${cost_hitaj_ptc} + ${cost_metcalf_ptc} + ${cost_shirmali_ptc}))

global lcoe_scaling = "no"

*US-Only wind average
use "${code_files}/4_results/`main_data_set'/compiled_results_all_uncorrected_vJK", clear 
keep if program == "hitaj_ptc" | program == "metcalf_ptc" | program == "shirmali_ptc"

qui sum component_value if component_type == "WTP_USPres" | component_type == "WTP_USFut" 
local total_us_wtp = `r(sum)'

qui sum component_value if component_type == "cost"
local total_cost = `r(sum)'
post `numbers' ("wind_avg_us_only") (`total_us_wtp' / `total_cost')


*Wind Non-Marginal Category Average
global subsidy_loop = "yes"

tempname wind_mvpfs_nma
tempfile wind_mvpfs_nma_data
postfile `wind_mvpfs_nma' str18 policy elasticity sub_level mvpf WTP_cc cost using `wind_mvpfs_nma_data', replace 

local policies = "hitaj_ptc metcalf_ptc shirmali_ptc"
foreach policy in `policies' {
	
	forvalues sub = 0(0.001)0.027 {
		
		global fed_sub_loop = `sub'		
		qui run_program `policy'
		
		post `wind_mvpfs_nma' ("`policy'") (${`policy'_ep}) (`sub') (${MVPF_`policy'}) (${WTP_cc_`policy'}) (${cost_`policy'})
	}
}

postclose `wind_mvpfs_nma'	
global subsidy_loop = "no"
use `wind_mvpfs_nma_data', clear

collapse (mean) WTP_cc cost, by(sub)
gen mvpf = WTP_cc / cost
qui sum mvpf
di `r(mean)'
post `numbers' ("wind_non_marginal_avg") (`r(mean)')


*--------------------------------------------
* 7 - Solar
*--------------------------------------------
*Fiscal externality if the ITC is 30%
global subsidy_change = "yes"
run_program pless_ho
di (${fisc_ext_s_pless_ho} / ${program_cost_pless_ho})
post `numbers' ("solar_fe_itc30") (${fisc_ext_s_pless_ho} / ${program_cost_pless_ho})
global subsidy_change = "no"

*Utility scale solar
run_program uscale_solar, folder(robustness)
di ${MVPF_uscale_solar}
post `numbers' ("utility_scale_solar_mvpf") (${MVPF_uscale_solar})

*US-Only Solar Average
use "${code_files}/4_results/`main_data_set'/compiled_results_all_uncorrected_vJK", clear 
keep if inlist(program, "ne_solar", "ct_solar", "pless_ho", "pless_tpo", "hughes_csi")

qui sum component_value if component_type == "WTP_USPres" | component_type == "WTP_USFut" 
local total_us_wtp = `r(sum)'

qui sum component_value if component_type == "cost"
local total_cost = `r(sum)'
post `numbers' ("solar_us_only_mvpf") (`total_us_wtp' / `total_cost')

*Solar Non-Marginal Category Average
global subsidy_loop = "yes"

tempname solar_mvpfs_nma
tempfile solar_mvpfs_nma_data
postfile `solar_mvpfs_nma' str18 policy elasticity sub_level mvpf WTP_cc cost using `solar_mvpfs_nma_data', replace 

local policies = "pless_ho pless_tpo ct_solar ne_solar hughes_csi"
foreach policy in `policies' {

	di in red "Starting policy `policy'..."
	
	forvalues sub = 0(0.01)0.31 {
		
		global fed_sub_loop = `sub'		
		qui run_program `policy'
		
		post `solar_mvpfs_nma' ("`policy'") (${`policy'_ep}) (`sub') (${MVPF_`policy'}) (${WTP_cc_`policy'}) (${cost_`policy'})
	}
}

postclose `solar_mvpfs_nma'	
global subsidy_loop = "no"

use `solar_mvpfs_nma_data', clear

collapse (mean) WTP_cc cost, by(sub)
gen mvpf = WTP_cc / cost
qui sum mvpf
post `numbers' ("solar_non_marginal_mvpf") (`r(mean)')


*--------------------------------------------
* 8 - Weatherization
*--------------------------------------------

*Category average with 100% marginal
global marginal_change = "yes"
local weatherization_policies = "wap ihwap_nb retrofit_res hancevic_rf wisc_rf"

foreach policy in `weatherization_policies' {
	run_program `policy'
	
	local `policy'_wtp_scaled = ${WTP_`policy'} / ${program_cost_`policy'}
	local `policy'_cost_scaled = ${cost_`policy'} / ${program_cost_`policy'}
	
}
global marginal_change = "no"

di ((`retrofit_res_wtp_scaled'/ `retrofit_res_cost_scaled'))

post `numbers' ("weatherization_avg_all_marginal") ((`wap_wtp_scaled' + `ihwap_nb_wtp_scaled' + `retrofit_res_wtp_scaled' + `hancevic_rf_wtp_scaled' + `wisc_rf_wtp_scaled') / (`wap_cost_scaled' + `ihwap_nb_cost_scaled' + `retrofit_res_cost_scaled' + `hancevic_rf_cost_scaled' + `wisc_rf_cost_scaled'))


*Category average with Michigan Grid
global grid_michigan = "yes"
local weatherization_policies = "wap ihwap_nb retrofit_res hancevic_rf wisc_rf"

foreach policy in `weatherization_policies' {
	run_program `policy'
	
	local `policy'_wtp_scaled = ${WTP_`policy'} / ${program_cost_`policy'}
	local `policy'_cost_scaled = ${cost_`policy'} / ${program_cost_`policy'}
	
}
global grid_michigan = "no"
post `numbers' ("weatherization_midwest_grid") ((`wap_wtp_scaled' + `ihwap_nb_wtp_scaled' + `retrofit_res_wtp_scaled' + `hancevic_rf_wtp_scaled' + `wisc_rf_wtp_scaled') / (`wap_cost_scaled' + `ihwap_nb_cost_scaled' + `retrofit_res_cost_scaled' + `hancevic_rf_cost_scaled' + `wisc_rf_cost_scaled'))

*Category average with California Grid
global grid_california = "yes"
local weatherization_policies = "wap ihwap_nb retrofit_res hancevic_rf wisc_rf"

foreach policy in `weatherization_policies' {
	run_program `policy'
	
	local `policy'_wtp_scaled = ${WTP_`policy'} / ${program_cost_`policy'}
	local `policy'_cost_scaled = ${cost_`policy'} / ${program_cost_`policy'}
	
}
global grid_california = "no"
post `numbers' ("weatherization_california_grid") ((`wap_wtp_scaled' + `ihwap_nb_wtp_scaled' + `retrofit_res_wtp_scaled' + `hancevic_rf_wtp_scaled' + `wisc_rf_wtp_scaled') / (`wap_cost_scaled' + `ihwap_nb_cost_scaled' + `retrofit_res_cost_scaled' + `hancevic_rf_cost_scaled' + `wisc_rf_cost_scaled'))


*--------------------------------------------
* 9 - Appliance Rebates
*--------------------------------------------

*Rebound effect for clothes washers rebate
run_program c4a_cw

post `numbers' ("clothes_washers_local_rebound") (${wtp_r_loc_c4a_cw}/${program_cost_c4a_cw})
post `numbers' ("clothes_washers_global_rebound") (${wtp_r_glob_c4a_cw}/${program_cost_c4a_cw})


*--------------------------------------------
* 10 - Other Subsidies
*--------------------------------------------
*Rebound effect for CA electricity rebate
run_program ca_electric

post `numbers' ("elec_rebate_local_rebound") (${wtp_r_loc_ca_electric}/${program_cost_ca_electric})
post `numbers' ("elec_rebate_global_rebound") (${wtp_r_glob_ca_electric}/${program_cost_ca_electric})


*--------------------------------------------
* 11 - Nudges
*--------------------------------------------

*Nudge MVPFs for SCC of $76
local scc_temp = ${scc}
global scc = 76
qui do "${github}/wrapper/macros.do"	
qui do "${github}/figtab/mvpf_plots_nudges.do" "no" "no"
global scc = `scc_temp'
qui do "${github}/wrapper/macros.do" "no"

post `numbers' ("nudge_mid_atlantic_76") (${her_MVPF_region4})
post `numbers' ("nudge_northwest_76") (${her_MVPF_region5})
post `numbers' ("nudge_midwest_76") (${her_MVPF_region3})
post `numbers' ("nudge_california_76") (${her_MVPF_region2})
post `numbers' ("nudge_new_england_76") (${her_MVPF_region1})

*Nudge MVPFs with Persistence
qui do "${github}/figtab/mvpf_plots_nudges.do" "no" "yes"
post `numbers' ("nudge_ca_alcott_kessler") (${her_MVPF_region2})
post `numbers' ("nudge_ne_alcott_kessler") (${her_MVPF_region1})

*Nudge MVPFs without utility profits
global value_profits = "no"
qui do "${github}/figtab/mvpf_plots_nudges.do" "no" "no"

post `numbers' ("nudge_mid_atlantic_no_profits") (${her_MVPF_region4})
post `numbers' ("nudge_northwest_no_profits") (${her_MVPF_region5})
post `numbers' ("nudge_midwest_no_profits") (${her_MVPF_region3})
post `numbers' ("nudge_california_no_profits") (${her_MVPF_region2})
post `numbers' ("nudge_new_england_no_profits") (${her_MVPF_region1})
global value_profits = "yes"

*ATE per electricity and natural gas nudge
use "${output_fig}/figures_data/Nudge_inter_v1.dta", clear
gen effect_per_nudge = ATE/Nudges_per_year
collapse effect_per_nudge [aw=Treated], by(Utilitytype)

qui sum effect_per_nudge if Utilitytype == "ELECTRICITY"
post `numbers' ("electricity_nudge_ATE") (`r(mean)')

qui sum effect_per_nudge if Utilitytype == "NATURAL GAS"
post `numbers' ("natural_gas_nudge_ATE") (`r(mean)')

*PER MVPF for 500 & 1000 marginal costs & blackout scenario
run_program PER
post `numbers' ("per_mvpf_1000_mc") (${MVPF_per})

global PER_robustness = "yes"
global PER_mc = "low"
run_program PER
post `numbers' ("per_mvpf_500_mc") (${MVPF_per})

global PER_mc = "vll"
run_program PER
post `numbers' ("per_mvpf_vll_mc") (${MVPF_per})

global PER_robustness = "no" 

*--------------------------------------------
* 12 - Gasoline Taxes
*--------------------------------------------
global gas_tax_robustness_numbers "yes"
run_program small_gas_lr, mode(current) // For LBD benefits from gas taxes, can run any gas tax--do not vary with elasticity of gasoline.
macro drop gas_tax_robustness_numbers

	post `numbers' ("cross_price_elasticity_gas_EVs_current") (${report_cross_price})
	post `numbers' ("gas_tax_static_ev_ext_current") (${report_gas_tax_static_ev_ext})
	post `numbers' ("gas_tax_dynamic_ev_price_current") (${report_gas_tax_dynamic_ev_price})
	post `numbers' ("gas_tax_dynamic_ev_env_current") (${report_gas_tax_dynamic_ev_env})
	
local main_sample_gas_taxes 	cog_gas dk_gas gelman_gas h_gas_01_06 k_gas_15_22 li_gas levin_gas ///
									manzan_gas park_gas sent_ch_gas small_gas_lr su_gas

local running_US_WTP = 0
local running_cost = 0
local running_local_pollution = 0
local running_local_driving = 0
local running_global_US_only = 0
local running_tax_fe = 0
local running_prod_wtp = 0

foreach p of local main_sample_gas_taxes {
	
	run_program `p', mode(current)
	
	local running_US_WTP = `running_US_WTP' + (${WTP_USPres_`p'} + ${WTP_USFut_`p'})
	local running_cost = `running_cost' + ${cost_`p'}
	
	local running_local_pollution = `running_local_pollution' + ${wtp_soc_l_po_`p'}
	local running_local_driving = `running_local_driving' + ${wtp_soc_l_dr_`p'}
	
	local running_global_US_only = `running_global_US_only' + ///
				((${wtp_soc_g_`p'}/(1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
				
	local running_tax_fe = `running_tax_fe' + ${fisc_ext_t_`p'}
	local running_prod_wtp = `running_prod_wtp' + ${wtp_prod_s_`p'}
	
}
	
post `numbers' ("avg_gas_tax_local_pollution_wtp_2020") (`running_local_pollution' / 12) // Average across twelve gas taxes.
post `numbers' ("avg_gas_tax_local_driving_wtp_2020") (`running_local_driving' / 12) // Average across twelve gas taxes.
post `numbers' ("avg_gas_tax_summed_local_wtp_2020") ((`running_local_pollution' + `running_local_driving') / 12) // Average across twelve gas taxes.
post `numbers' ("avg_gas_tax_US_only_global_wtp_2020") (`running_global_US_only' / 12) // Average across twelve gas taxes.
post `numbers' ("avg_gas_tax_tax_fe_2020") (`running_tax_fe' / 12)
post `numbers' ("avg_gas_tax_wtp_prod_2020") (`running_prod_wtp' / 12)

post `numbers' ("US_WTP_only_avg_gas_tax_current") (`running_US_WTP' / `running_cost')

// To obtain our gas externalities, run gas_vehicle_externalities.
post `numbers' ("per_gallon_gas_ext_total") (${gas_ldv_ext_2020})
post `numbers' ("per_gallon_gas_ext_global") (${gas_ldv_ext_global_2020})
post `numbers' ("per_gallon_gas_ext_local") (${gas_ldv_ext_local_2020})



// Gas Taxes w/ Only Driving Externalities
local main_sample_gas_taxes 	cog_gas dk_gas gelman_gas h_gas_01_06 k_gas_15_22 li_gas levin_gas manzan_gas park_gas sent_ch_gas small_gas_lr su_gas

local total_accident_congestion_wtp = 0
local total_accident_congestion_cost = 0
foreach p of local main_sample_gas_taxes {
	
	run_program `p' , mode(current)
	
	// Ignoring all climate and pollution effects, including climate FE.
	local total_accident_congestion_wtp = `total_accident_congestion_wtp' + (${wtp_soc_l_dr_`p'} + ${wtp_cons_`p'})
	local total_accident_congestion_cost = `total_accident_congestion_cost' + (${cost_`p'})
	
}
post `numbers'("average_gas_tax_only_driving_ext") (`total_accident_congestion_wtp' / `total_accident_congestion_cost')



// Gas Taxes w/ Different Prices
global vary_gas_price 	yes
local alternative_year 2021
	global alternative_gas_price = ${nominal_gas_price_`alternative_year'}
	
local running_wtp = 0
local running_cost = 0

local main_sample_gas_taxes 	cog_gas dk_gas gelman_gas h_gas_01_06 k_gas_15_22 li_gas levin_gas manzan_gas park_gas sent_ch_gas small_gas_lr su_gas
foreach p of local main_sample_gas_taxes {
	
	run_program `p' , mode(current)
	
	local running_wtp = `running_wtp' + ${WTP_`p'}
	local running_cost = `running_cost' + ${cost_`p'}
	
	
}
macro drop alternative_gas_price vary_gas_price alternative_year
post `numbers' ("average_gas_tax_`alternative_year'_price") (`running_wtp' / `running_cost')



global vary_gas_price 	yes
local alternative_year 2022
	global alternative_gas_price = ${nominal_gas_price_`alternative_year'}
	
local running_wtp = 0
local running_cost = 0

local main_sample_gas_taxes 	cog_gas dk_gas gelman_gas h_gas_01_06 k_gas_15_22 li_gas levin_gas manzan_gas park_gas sent_ch_gas small_gas_lr su_gas
foreach p of local main_sample_gas_taxes {
	
	run_program `p' , mode(current)
	
	local running_wtp = `running_wtp' + ${WTP_`p'}
	local running_cost = `running_cost' + ${cost_`p'}
	
	
}
macro drop alternative_gas_price vary_gas_price alternative_year
post `numbers' ("average_gas_tax_`alternative_year'_price") (`running_wtp' / `running_cost')


*--------------------------------------------
* 13 - Cap and Trade
*--------------------------------------------

run_program rggi, mode(baseline)
	post `numbers' ("rggi_permit_price_in_context") (${permit_price_rggi})
	post `numbers' ("carbon_abated_rggi_short_tons_in_context") (${gov_carbon_rggi})
	post `numbers' ("macc_slope_rggi_in_context") (${macc_rggi})
	post `numbers' ("fiscal_externality_permits_rggi_in_context") (${fisc_ext_t_rggi} * -1)
	post `numbers' ("change_permit_prices_rggi_in_context") (${wtp_permits_rggi} * -1)
	post `numbers' ("fiscal_externality_climate_rggi_in_context") (${fisc_ext_lr_rggi} * -1)
	post `numbers' ("total_cost_rggi_in_context") (${cost_rggi} * -1)
	post `numbers' ("firms_wtp_rggi_in_context") (${wtp_permits_rggi} * -1)
	post `numbers' ("leakage_share_rggi_in_context") (1 - ${share_leakage_rggi})
	post `numbers' ("global_benefits_rggi_in_context") (${wtp_soc_g_rggi} * -1)
	post `numbers' ("local_benefits_rggi_in_context") (${wtp_soc_l_rggi} * -1)
	post `numbers' ("total_wtp_rggi_in_context") (${WTP_rggi} * -1)
	post `numbers' ("MVPF_rggi_in_context") (${MVPF_rggi})
	post `numbers' ("rggi_eta_in_context") (${wtp_permits_rggi} / ${permit_price_rggi})
	post `numbers' ("rggi_V(1-L)p_in_context") ((${wtp_soc_rggi} * -1) / ${permit_price_rggi})
	post `numbers' ("MVPF_rggi_wo_local_damages_in_context") ((${wtp_permits_rggi} + ${wtp_soc_g_rggi}) / ${cost_rggi} )
	post `numbers' ("rggi_incidence_comparison_in_context") (abs(${wtp_soc_rggi} / ${wtp_permits_rggi}))

run_program rggi, mode(current)
	post `numbers' ("total_cost_rggi_current") (${cost_rggi})
	post `numbers' ("enviro_wtp_rggi_current") (${wtp_soc_rggi})
	post `numbers' ("firms_wtp_rggi_current") (${wtp_permits_rggi})
	post `numbers' ("MVPF_rggi_current") (${MVPF_rggi})
	
run_program ca_cnt, mode(baseline)
	post `numbers' ("MVPF_ca_cap_and_trade_in_context") (${MVPF_ca_cnt})
	post `numbers' ("MVPF_ca_cap_and_trade_in_context_wo_local") ((${wtp_permits_ca_cnt} + ${wtp_soc_g_ca_cnt}) / ${cost_ca_cnt})

global toggle_firm_assumption yes
run_program ca_cnt, mode(baseline)
	post `numbers' ("MVPF_ca_cap_and_trade_in_context_alternative_firms_assumption") (${MVPF_ca_cnt})
	assert "${toggle_firm_assumption}" == ""
	
run_program ets_c, mode(baseline)
	post `numbers' ("ETS_Colmer_permit_price_in_context") (${permit_price_ets_c})
	post `numbers' ("ETS_Colmer_firms_wtp_in_context") (${wtp_permits_ets_c})	
	post `numbers' ("ETS_Colmer_global_wtp_in_context") (${wtp_soc_g_ets_c})	
	post `numbers' ("ETS_Colmer_total_wtp_in_context") (${WTP_ets_c} *-1)	
	post `numbers' ("ETS_Colmer_permit_fe_in_context") (${fisc_ext_t_ets_c})
	post `numbers' ("ETS_Colmer_permit_price_revenue_in_context") (${program_cost_ets_c})
	post `numbers' ("ETS_Colmer_total_cost_in_context") (${cost_ets_c})

run_program ets, mode(baseline)
	post `numbers' ("ETS_BayerAklin_permit_price_in_context") (${permit_price_ets})
	post `numbers' ("ETS_BayerAklin_total_CO2_reduction") (${gov_carbon_ets})
	post `numbers' ("ETS_BayerAklin_macc_slope_in_context") (${macc_ets})
	post `numbers' ("ETS_BayerAklin_firms_wtp_in_context") (${wtp_permits_ets})
	post `numbers' ("ETS_BayerAklin_climate_fe_in_context") (${fisc_ext_lr_ets})
	post `numbers' ("ETS_BayerAklin_firms_wtp_in_context") (${wtp_permits_ets})
	post `numbers' ("ETS_BayerAklin_global_wtp_in_context") (${wtp_soc_g_ets})	
	post `numbers' ("ETS_BayerAklin_total_wtp_in_context") (${WTP_ets})	
	post `numbers' ("ETS_BayerAklin_total_cost_in_context") (${cost_ets})


postclose `numbers'


use `robustness_values', clear
save "${code_files}/4_results/robustness", replace
export excel using "${code_files}/4_results/robustness", replace

*--------------------------------------------
* 14 - Different Grids
*--------------------------------------------
* Create list of all programs to run.
filelist, pattern("*.do") dir("${github}/policies/harmonized/") save(temp_filelist.txt) replace
preserve

	use temp_filelist.txt, clear
	
	levelsof(filename), local(file_loop)
	foreach program of local file_loop {
		
		local program_entry = substr("`program'", 1, strlen("`program'") - 3)
		local all_programs "`all_programs' `program_entry'" 
		
	}
	
	cap erase temp_filelist.txt
	
restore 
/*
*Run with CA grid
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193_CA_grid" // nrun
	
	*Reset back to original
	global change_grid = ""
	global ev_grid = "US"
*/
*Run with EU grid
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193_EU_grid" // nrun
	
	*Reset back to original
	global change_grid = ""
	global ev_grid = "US"
	
*Run with MI grid
	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193_MI_grid" // nrun
	
	*Reset back to original
	global change_grid = ""
	global ev_grid = "US"
	qui do "${github}/calculations/gas_electricity_externalities"
	

*--------------------------------------------
* 15 - Different Natural Gas Rebound
*--------------------------------------------
global ng_rebound_robustness = "yes"

	do "${github}/wrapper/metafile.do" ///
		"current" /// 2020
		"193" /// SCC
		"yes" /// learning-by-doing
		"no" /// savings
		"yes" /// profits
		"`all_programs'" /// programs to run
		0 /// reps
		"full_current_193_gas_rebound" // nrun

global ng_rebound_robustness = "no"
