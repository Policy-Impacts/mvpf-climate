/***************************************************************************
 *              FIGURES FOR MVPF ENVIRONMENTAL PROJECT                     *
 ***************************************************************************
    This file produces all of the main figures for A Welfare Analysis of 
    Policies Impacting Climate Change.
****************************************************************************/

*-----------------------
* 1 - EV Waterfall Chart
*-----------------------
run_program muehl_efmp, scc(193)

do "${github}/figtab/waterfalls_rep.do" "muehl_efmp" "current" "full_current_193"


*-------------------------
* 2a - Wind Waterfall Chart
*-------------------------
run_program hitaj_ptc, scc(193)

do "${github}/figtab/waterfalls_rep.do" "hitaj_ptc" "current" "full_current_193" 

*-----------------------------------------------
* 2b and 3b - Wind and Solar MVPFs by elasticity
*-----------------------------------------------

do "${github}/figtab/wind_solar_paper.do"

*--------------------------
* 3a - Solar waterfall chart
*--------------------------
run_program pless_ho

do "${github}/figtab/waterfalls_rep.do" "pless_ho" "current" "full_current_193"

*----------------------------------
* 4 -  Baseline MVPFs for Subsidies
*----------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "full_current_193" "Fig4_scc193" "193" "yes_cis"

*-------------------------------------------
* 5 -  MVPF plot for varying specifications
*-------------------------------------------

do "${github}/figtab/mvpf_plots_add.do" "subsidies" "Subsidy Robustness" "full_current_193" "full_current_no_lbd_193" "full_current_noprofits_193" "full_current_savings_193" "full_current_193_ca_grid" "full_current_193_mi_grid" "full_current_193_zero_rb" "full_current_193_2_rb" "full_current_337" "full_current_no_lbd_337" "full_current_noprofits_337" "full_current_savings_337" "full_current_337_ca_grid" "full_current_337_mi_grid" "full_current_337_zero_rb" "full_current_337_2_rb" "full_current_76" "full_current_no_lbd_76" "full_current_noprofits_76" "full_current_savings_76" "full_current_76_ca_grid" "full_current_76_mi_grid" "full_current_76_zero_rb" "full_current_76_2_rb"


*--------------------
* 6 -  HERs MVPF plot
*--------------------

do "${github}/figtab/mvpf_plots_nudges.do" "yes" "no"

*-----------------------------
* 7 -  Gas tax waterfall chart
*-----------------------------
run_program small_gas_lr

do "${github}/figtab/waterfalls_rep.do" "small_gas_lr" "current" "full_current_193"

*----------------------------------
* 8 -  MVPF plot of revenue raisers
*----------------------------------

do "${github}/figtab/mvpf_plots.do" "taxes" "full_current_193" "Fig8_scc193" "193" "yes_cis"

*-----------------------------------------
* 9 -  MVPF plot of international policies
*-----------------------------------------

do "${github}/figtab/mvpf_plots.do" "intl" "full_current_193_nov" "Fig9_scc193" "split" "no_cis"




