
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

do "${github}/figtab/grid_externality_region.do"

*------------------------------------------------------------------------
* 3 - Environmental Externality per MWh of Electricity Generation in 2020
*------------------------------------------------------------------------

* A -  MVPF plot for varying specifications
// do "${github}/figtab/mvpf_plots_add.do" "subsidies" "Subsidy Robustness" "full_current_76_s" "full_current_no_lbd_76_s" "full_current_noprof_76_s" "full_current_savings_76_s" "full_current_76_ca_grid_s" "full_current_76_mi_grid_s" "full_current_76_zero_rb_s" "full_current_76_2_rb_s" "full_current_337_s" "full_current_no_lbd_337_s" "full_current_noprof_337_s" "full_current_savings_337_s" "full_current_337_ca_grid_s" "full_current_337_mi_grid_s" "full_current_337_zero_rb_s" "full_current_337_2_rb_s" "full_current_193_s" "full_current_no_lbd_193_s" "full_current_noprof_193_s" "full_current_savings_193_s" "full_current_193_ca_grid_s" "full_current_193_mi_grid_s" "full_current_193_zero_rb_s" "full_current_193_2_rb_s"
//
// * B -  MVPFs with a Changing Grid
//
// do "${github}/figtab/changing_grid.do" //

*---------------------------------------
* 4 - Baseline MVPFs with a US/RoW split
*---------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "full_current_193_s" "Ap_Fig4_split" "split" "no_cis"

*------------------------------------------------------------------------
* 5 - Non-Marginal EV MVPF Plot
*------------------------------------------------------------------------

do "${github}/calculations/bevs_non_marginal.do" "bev_state"

*------------------------
* 6 - Electricity Rebound
*------------------------

do "${github}/figtab/contour_plot.do"

*----------------------------------
* 7 - Evidence of Publication Bias
*----------------------------------

do "${github}/publication_bias/heuristic_graphs.do" 5 10 4.9 .98 //check for hardcoded dataset

*--------------------------------------------------
* 8 - Model Fits for Estimates of Publication Bias
*--------------------------------------------------

do "${github}/publication_bias/cdf_plot.do" 4.9 .98 //check for hardcoded

*-----------------------------------------------------
* 9 - MVPFs with Publication Bias–Corrected Estimates
*-----------------------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "full_current_193_pub_bias_and_lbd" "App_Fig_9_scc193" "193" "no_cis" "pub_bias"
* find where this datafile is being created and search for name and change the name to match corrected_ests

*-----------------------------------
* 10 - CAFE vs. Gasoline + Income Tax 
*-----------------------------------

do "${github}/figtab/regulations.do" "full_current_193" "gas" "cafe_dk"

*--------------------------------------
* 11 - Additional Regulation Comparisons
*--------------------------------------
do "${github}/figtab/regulations.do" "full_current_193" "gas" "cafe_as"

do "${github}/figtab/regulations.do" "full_current_193" "gas" "cafe_j"

do "${github}/figtab/regulations.do" "full_current_193" "wind" "rps"



