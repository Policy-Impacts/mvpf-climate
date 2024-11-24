/***************************************************************************
 *               TABLES FOR MVPF ENVIRONMENTAL PROJECT                     *
 ***************************************************************************
    This file produces all of the main tables for A Welfare Analysis of 
    Policies Impacting Climate Change.
****************************************************************************/

*-----------------------------
* 2 - Baseline MVPF Components
*-----------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-15_09-44-45__full_current_193_nov" "Table2_scc193_main" "no" "yes"


*----------------------------------------------------
* 3 - MVPF Versus Cost Per Ton (with and without LBD)
*----------------------------------------------------

do "${github}/figtab/cost_per_ton.do" "2024-11-15_09-44-45__full_current_193_nov" "yes"

do "${github}/figtab/cost_per_ton.do" "2024-11-15_01-31-00__full_current_no_lbd_193_nov" "no"

do "${github}/figtab/excel_ce_lbd_tables.do" "scc193"