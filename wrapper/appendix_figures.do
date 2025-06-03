
/***************************************************************************
 *          APPENDIX FIGURES FOR MVPF ENVIRONMENTAL PROJECT                *
 ***************************************************************************
    This file produces all of the appendix figures for A Welfare Analysis 
    of Policies Impacting Climate Change.
****************************************************************************/

*----------------------
* 1 - Learning by doing
*----------------------

do "${github}/figtab/lbd_graphs_rep.do"

*---------------------------------------------
* 2 - Vehicle and grid externalities over time
*---------------------------------------------

do "${github}/figtab/connected_externalities_driving.do"

do "${github}/figtab/stacked_elec_externalities"

*------------------------------------------------------------------------
* 3 - Environmental Externality per MWh of Electricity Generation in 2020
*------------------------------------------------------------------------

do "${github}/figtab/grid_externality_region.do"

*------------------------------------------------------------------------
* 4 - Non-Marginal EV MVPF Plot
*------------------------------------------------------------------------

do "${github}/calculations/bevs_non_marginal.do"

*---------------------------------------
* 5 - Baseline MVPFs with a US/RoW split
*---------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-04_16-03-35__full_current_193_nov" "Ap_Fig5_split" "split" "no_cis"

*-----------------------------------
* 6 - CAFE vs. Gasoline + Income Tax
*-----------------------------------

do "${github}/figtab/regulations.do" "2024-11-15_09-44-45__full_current_193_nov" "gas" "cafe_dk"

*--------------------------------------
* 7 - Additional Regulation Comparisons
*--------------------------------------
do "${github}/figtab/regulations.do" "2024-11-15_09-44-45__full_current_193_nov" "gas" "cafe_as"

do "${github}/figtab/regulations.do" "2024-11-15_09-44-45__full_current_193_nov" "gas" "cafe_j"

do "${github}/figtab/regulations.do" "2024-11-15_09-44-45__full_current_193_nov" "gas" "rps"

*------------------------
* 8 - Electricity Rebound
*------------------------

do "${github}/figtab/contour_plot.do"

*----------------------------------
* 9 - Evidence of Publication Bias
*----------------------------------

do "${github}/publication_bias/heuristic_graphs.do" 5 10 4.9 .98

*--------------------------------------------------
* 10 - Model Fits for Estimates of Publication Bias
*--------------------------------------------------

do "${github}/publication_bias/cdf_plot.do" 4.9 .98

*-----------------------------------------------------
* 11 - MVPFs with Publication Bias–Corrected Estimates
*-----------------------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-04_16-42-05__corrected_ests_for_mvpf_plot" "App_Fig_12_scc193" "193" "no_cis" "pub_bias"

*----------------------------------
* Add -  MVPFs plot for Subsidies (changing global assumptions), multiple SCCs
*----------------------------------

do "${github}/figtab/mvpf_plots_add.do" "subsidies" "Subsidy Robustness" "scc_193" "no_lbd" "no_profit" "e_savings" "cali_grid" "mi_grid"  "zero_rebound" "double_rebound" "scc_337" "scc_337_no_lbd" "scc_337_no_profit" "scc_337_e_savings" "scc_337_cali_grid" "scc_337_mi_grid" "scc_337_zero_rebound" "scc_337_double_rebound" "scc_76" "scc_76_no_lbd" "scc_76_no_profit" "scc_76_e_savings" "scc_76_cali_grid"  "scc_76_mi_grid" "scc_76_zero_rebound" "scc_76_double_rebound"

*----------------------------------
* Add -  MVPFs plot for Subsidies (changing local assumptions)
*----------------------------------

do "${github}/figtab/mvpf_plots_locals.do" "subsidies" "Subsidy Robustness Locals" "scc_193" "wind_no_cap_factor" "wind_lifetime_increase" "wind_lifetime_reduce" "wind_emissions_half" "wind_emissions_double" "wind_lcoe_2" "wind_lcoe_05" "wind_semie" "solar_output_decrease" "solar_output_increase" "solar_lifetime_increase" "solar_lifetime_reduce" "ev_lifetime_increase" "ev_lifetime_reduce" "ev_vmt_rebound_one" "ev_new_car" "wea_lifetime_reduce" "wea_mar_val_decr" "wea_mar_per_decr" "hybrid_lifetime_reduce" "hybrid_lifetime_increase" "hybrid_new_car" "app_lifetime_reduce" "app_lifetime_increase" "vehicle_lifetime_increase" "vehicle_mar_decrease" "vehicle_no_rb"



