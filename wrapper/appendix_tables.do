
/***************************************************************************
 *           APPENDIX TABLES FOR MVPF ENVIRONMENTAL PROJECT                *
 ***************************************************************************
    This file produces all of the appendix tables for A Welfare Analysis 
    of Policies Impacting Climate Change.
****************************************************************************/

*---------------------------------------------------------------------
* 1 - Evidence of Learning By Doing, Using Data from Way et al. (2022)
*---------------------------------------------------------------------

do "${github}/figtab/lbd_table_rep"

*-------------------------------
* 2 - In-Context MVPF Components
*-------------------------------
do "${github}/figtab/excel_MVPF_tables.do" "2024-11-15_01-14-07__full_incontext_193_nov" "App_Table2_scc193_in_context" "no" "no"

*-------------------------------------------------------
* 3 - Baseline MVPF Components with Confidence Intervals
*-------------------------------------------------------

do "${github}/figtab/ci_table.do" "2024-11-16_14-43-50__full_current_76_nov" "2024-11-15_09-44-45__full_current_193_nov" "2024-11-16_15-20-07__full_current_337_nov" "App_Table3_CI" "no"
*---------------------------------------------------------
* 4 - Baseline MVPF Components Using an SCC of $76 in 2020
*---------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-16_14-43-50__full_current_76_nov" "App_Table4_scc76" "no" "yes"

*----------------------------------------------------------
* 5 - Baseline MVPF Components Using an SCC of $337 in 2020
*----------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-16_15-20-07__full_current_337_nov" "App_Table5_scc337_main" "no" "yes"

*-----------------------------------------------
* 6 - Baseline MVPF Components Excluding Profits
*-----------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-15_02-01-52__full_current_noprofits_193_nov" "App_Table6_no_profits" "no"

*--------------------------------------------------------------------------
* 7 - Baseline MVPF Components Including Energy Savings Additional Benefits
*--------------------------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-15_01-32-09__full_current_savings_193_nov" "App_Table7_with_savings" "yes"

*---------------------------------------------------------
* 8 - Baseline MVPF Components Excluding Learning by Doing
*---------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "2024-11-15_01-31-00__full_current_no_lbd_193_nov" "App_Table8_no_lbd" "no"

*--------------------------------------------------------
* 9 - MVPF Versus Social Cost Per Ton with MCF Adjustment
*--------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "193" "yes" // 1 is table name, 2 is DWL, 3 is LBD

*--------------------------------------------------------
* 10 - MVPF Versus Cost Per Ton Measures for All Policies
*--------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "scc193"

*-----------------------------------------------------------
* 11 - MVPF Versus Cost Per Ton, Excluding Learning By Doing
*-----------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "193" "no" "no" // 1 is table name, 2 is DWL, 3 is LBD

*----------------------------------------------------------------
* 12 - Average Light-duty, Gasoline-powered Vehicle Externalities
*----------------------------------------------------------------
do "${github}/figtab/connected_externalities_driving.do"



