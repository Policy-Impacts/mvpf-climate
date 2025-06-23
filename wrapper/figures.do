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

do "${github}/figtab/waterfalls_rep.do" "muehl_efmp" "current" "2024-11-15_09-44-45__full_current_193_nov_uncorrected_vJK"


*-------------------------
* 2a - Wind Waterfall Chart
*-------------------------
run_program hitaj_ptc, scc(193)

do "${github}/figtab/waterfalls_rep.do" "hitaj_ptc" "current" "2024-11-15_09-44-45__full_current_193_nov_uncorrected_vJK" 

*-----------------------------------------------
* 2b and 3b - Wind and Solar MVPFs by elasticity
*-----------------------------------------------

do "${github}/figtab/wind_solar_paper.do"

*--------------------------
* 3a - Solar waterfall chart
*--------------------------
run_program pless_ho

do "${github}/figtab/waterfalls_rep.do" "pless_ho" "current" "2024-11-15_09-44-45__full_current_193_nov_uncorrected_vJK"

*----------------------------------
* 4 -  Baseline MVPFs for Subsidies
*----------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "full_current_193" "Fig4_scc193" "193" "yes_cis"

*-------------------------------------------
* 5 -  MVPF plot for subsidies with $76 SCC
*-------------------------------------------


do "${github}/figtab/mvpf_plots_add.do" "subsidies" "Subsidy Robustness" "scc_193" "no_lbd" "no_profit" "e_savings" "cali_grid" "mi_grid"  "zero_rebound" "double_rebound" "scc_337" "scc_337_no_lbd" "scc_337_no_profit" "scc_337_e_savings" "scc_337_cali_grid" "scc_337_mi_grid" "scc_337_zero_rebound" "scc_337_double_rebound" "scc_76" "scc_76_no_lbd" "scc_76_no_profit" "scc_76_e_savings" "scc_76_cali_grid"  "scc_76_mi_grid" "scc_76_zero_rebound" "scc_76_double_rebound"


*-------------------------------------------
* 5a -  MVPF plot for subsidies with $76 SCC
*-------------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "full_current_76" "Fig5a_scc76" "76" "yes_cis"

*--------------------------------------------
* 5b -  MVPF plot for subsidies with $337 SCC
*--------------------------------------------

do "${github}/figtab/mvpf_plots.do" "subsidies" "2024-11-16_15-20-07__full_current_337_nov" "Fig5b_scc337" "337" "yes_cis

*----------------------------------
* 5c -  MVPFs plot for Subsidies, multiple SCCs
*----------------------------------

do "${github}/figtab/mvpf_plots_add.do" "subsidies" "Fig_name" "2024-11-15_09-44-45__full_current_193_nov" "2024-11-16_15-20-07__full_current_337_nov" "2024-11-16_14-43-50__full_current_76_nov" "compare_scc"



*--------------------
* 6 -  HERs MVPF plot
*--------------------

do "${github}/figtab/mvpf_plots_nudges.do" "yes" "no"

*-----------------------------
* 7 -  Gas tax waterfall chart
*-----------------------------
run_program small_gas_lr

do "${github}/figtab/waterfalls_rep.do" "small_gas_lr" "current" "2024-11-15_09-44-45__full_current_193_nov_uncorrected_vJK"

*----------------------------------
* 8 -  MVPF plot of revenue raisers
*----------------------------------

do "${github}/figtab/mvpf_plots.do" "taxes" "2024-11-15_09-44-45__full_current_193_nov" "Fig8_scc193" "193" "yes_cis"

*-----------------------------------------
* 9 -  MVPF plot of international policies
*-----------------------------------------

do "${github}/figtab/mvpf_plots.do" "intl" "2024-11-15_09-44-45__full_current_193_nov" "Fig9_scc193" "split" "no_cis"




