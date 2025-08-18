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




