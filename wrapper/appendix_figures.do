
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
