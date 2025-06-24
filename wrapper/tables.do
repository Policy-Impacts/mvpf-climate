/***************************************************************************
 *               TABLES FOR MVPF ENVIRONMENTAL PROJECT                     *
 ***************************************************************************
    This file produces all of the main tables for A Welfare Analysis of 
    Policies Impacting Climate Change.
****************************************************************************/

*-----------------------------
* 2 - Baseline MVPF Components
*-----------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_193" "Table2_scc193_main" "no" "yes"


*----------------------------------------------------
* 3 - MVPF Versus Cost Per Ton (with and without LBD)
*----------------------------------------------------

do "${github}/figtab/cost_per_ton.do" "full_current_193" "yes"

do "${github}/figtab/cost_per_ton.do" "full_current_no_lbd" "no"

do "${github}/figtab/excel_ce_lbd_tables.do" "scc193"