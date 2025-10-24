
/***************************************************************************
 *           APPENDIX TABLES FOR MVPF ENVIRONMENTAL PROJECT                *
 ***************************************************************************
    This file produces all of the appendix tables for A Welfare Analysis 
    of Policies Impacting Climate Change.
****************************************************************************/
*----------------------------------------
* 1 - Baseline MVPF Components in Full
*----------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_193" "Table1_scc193_app" "no" "yes"
*---------------------------------------------------------------------
* 2 - Evidence of Learning By Doing, Using Data from Way et al. (2022)
*---------------------------------------------------------------------

do "${github}/figtab/lbd_table_rep"

*-------------------------------
* 3 - In-Context MVPF Components
*-------------------------------
do "${github}/figtab/excel_MVPF_tables.do" "full_incontext" "App_Table3_scc193_in_context" "no" "no"

*-------------------------------------------------------
* 4 - Baseline MVPF Components with Confidence Intervals
*-------------------------------------------------------

do "${github}/figtab/ci_table.do" "full_current_76" "full_current_193" "full_current_337" "App_Table4_CI" "no"

*---------------------------------------------------------
* 5 - Baseline MVPF Components Using an SCC of $76 in 2020
*---------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_76" "App_Table5_scc76" "no" "yes"

*----------------------------------------------------------
* 6 - Baseline MVPF Components Using an SCC of $337 in 2020
*----------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_337" "App_Table6_scc337_main" "no" "yes"

*----------------------------------------------------------
* 7 - Baseline MVPF Components Using an SCC of $1367 in 2020
*----------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_1367" "App_Table7_scc1367_main" "no" "yes"

*---------------------------------------------------------
* 8 - Baseline MVPF Components Excluding Learning by Doing
*---------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_no_lbd" "App_Table8_no_lbd" "no" "no"

*---------------------------------------------------------
* 9 - Baseline MVPF Components with an EU Grid
*---------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_193_EU_grid" "App_Table9_eu_grid" "no" "no"

*-----------------------------------------------
* 10 - Baseline MVPF Components Excluding Profits
*-----------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_noprofits" "App_Table10_no_profits" "no" "no"

*--------------------------------------------------------------------------
* 11 - Baseline MVPF Components Including Energy Savings Additional Benefits
*--------------------------------------------------------------------------

do "${github}/figtab/excel_MVPF_tables.do" "full_current_savings" "App_Table11_with_savings" "yes"

*--------------------------------------------------------
* 12 - MVPF Versus Cost Per Ton Measures for All Policies
*--------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "scc193"

*-----------------------------------------------------------
* 13 - MVPF Versus Cost Per Ton, Excluding Learning By Doing
*-----------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "193" "no" "no" // 1 is table name, 2 is DWL, 3 is LBD

*--------------------------------------------------------
* 14 - MVPF Versus Social Cost Per Ton with MCF Adjustment
*--------------------------------------------------------

do "${github}/figtab/excel_ce_lbd_tables.do" "193" "yes" // 1 is table name, 2 is DWL, 3 is LBD

*----------------------------------------------------------------
* 15 - Average Light-duty, Gasoline-powered Vehicle Externalities
*----------------------------------------------------------------

do "${github}/figtab/connected_externalities_driving.do"



