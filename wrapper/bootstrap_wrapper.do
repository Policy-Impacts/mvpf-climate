********************************************************************************
*								BOOTSTRAP WRAPPER							   *
********************************************************************************

display `"All the arguments, as typed by the user, are: `0'"'
*Set options
local debug = 1 // 1 noisily displays running .do files

*Set modes
local modes "all"

/*
Note: modes can contain any of the following:
- baseline: only runs the baseline specification
- current: only runs the 2020 specification
*/

// macro list
*Set modes if running externally
if "`2'"!="" local modes "`2'"

*Set all
if "`modes'"=="all" local modes baseline current
global compile_loop_modes "`modes'"

*Set estimates to be used
local use_estimates $correction_mode

*-------------------------------------------------------------------------------
*	0. Define programs to run for
*-------------------------------------------------------------------------------
global compile_programs `1'
*Set programs if running externally
if "`1'" != "" {
	local programs "`1'"
}

local prog_num = wordcount("`programs'")

*-------------------------------------------------------------------------------
*	1. Simulations
*-------------------------------------------------------------------------------
global replications_master = $reps

foreach mode in `modes' {
	di in red "the mode is `mode'"

	local m = 0 // reset counter
	global replications $replications_master
	local replications $reps

	********** Looping through each program **********

	mat t`mode'=J(11, 5, .)
	local x = 1
	foreach program in `programs' {

		*Sort issues where names of assumption files don't line up with do file names
		local do_file = "`program'"
		local assumption_name = "`program'"

		*Import program specific assumptions
		import excel "${assumptions}/program_specific/`assumption_name'.xlsx", clear first
		ds

		duplicates drop // drop rows of assumptions that are identical
		count
		local columns = r(N)
		ds
		local varying_assumptions "`r(varlist)'"

		if inlist("`mode'","baseline", "current")  {
			confirm var spec_type // check for specification type indicator, previously had a capture
			if _rc==0 {
				keep if spec_type == "`mode'"
				assert _N == 1 | _N == 0
				if _N == 0{
					di in red "Skipping `program' because `mode' does not exist for this program"
					continue // skip programs missing certain assumptions
				} 
		
				qui ds spec_type, not
				local varying_assumptions `r(varlist)'
				foreach assumption in `r(varlist)'  {
					local `assumption'_1 = `assumption'[1]
				}
			}	

			keep in 1 // where not specified the first row is the baseline specification

			local correlation_1 = 1
			local varying_assumptions `varying_assumptions' correlation
			local columns = _N
			di `columns'
		}
		if "`mode'" != "baseline"{
			keep if spec_type == "`mode'"
			ds
			local varying_assumptions `r(varlist)'
			foreach assumption in `r(varlist)'{
				local `assumption'_1 = `assumption'[1]
			}
			local correlation_1 = 1
			local varying_assumptions `varying_assumptions' correlation
			local columns = _N
			di `columns'
		}

		local ++m

		*Loop over types of assumptions
		forval c = 1/`columns' {
			noi di "Specification `c' of `columns', program `m' of `prog_num' (`program')"

			*set assumptions
			foreach assumption in `varying_assumptions' {
				global `assumption' ``assumption'_`c''
			}
			*generate estimates
			clear

			set obs `replications'

			di "`program'"
			* Generate variables to store the estimates and clean globals
			local ests MVPF MVPF_no_cc cost WTP program_cost total_cost ///
			beh_fisc_ext utility_fisc_ext gas_fisc_ext fed_fisc_ext state_fisc_ext ///
			WTP_USPres WTP_USFut WTP_RoW WTP_USTotal enviro_mvpf cost_mvpf firm_mvpf cost_wtp ///
			env_cost_wtp marginal infmarg wtp_private wtp_soc wtp_no_ice wtp_yes_ev wtp_yes_hev wtp_soc_rbd wtp_yes_ev_local wtp_no_ice_local env_cost_wtp_l wtp_soc_rbd_l ///
			wtp_yes_ev_g wtp_no_ice_g env_cost_wtp_g wtp_soc_rbd_g ///
			wtp_marg wtp_inf wtp_glob wtp_loc wtp_r_glob wtp_r_loc wtp_e_cost ///
			WTP_cc wtp_install wtp_prod wtp_prod_s wtp_prod_u wtp_cons wtp_deal admin_cost ///
			wtp_permits wtp_abatement permitrev wtp_no_leak wtp_leak ///
			wtp_soc_g wtp_soc_l fisc_ext_t fisc_ext_s fisc_ext_lr q_CO2 q_CO2_no p_spend ///
			ev_sub_c ev_sub_c_row ev_sub_c_us ev_sub_env ev_sub_cost profits_fisc_e wtp_soc_l_po wtp_soc_l_dr ///
			gov_carbon resource_ce q_carbon_mck semie pass_through ///
			permitrev_new permitrev_ex fiscalext firm_cost_wtp c_savings resource_cost q_CO2_mck q_CO2_mck_no wtp_ctr gas_corp_fisc_e epsilon /// 
			transfer enviro_wtp cost_curve profits subsidies taxes ///
			wtp_batt wtp_local_w_r wind_g_wf wind_l_wf
			
			foreach est in `ests' {
				gen `est'_`program' = .
				macro drop `est'_`program'
			
			}
			cap recast double cost_wtp_`program'
			cap recast double cost_mvpf_`program'
			cap recast double MVPF_`program'

			local i = 1
			* Simulations: run each do file ~1000 times and store the estimates from each run
			if `replications' > 0 {
				qui{
					forvalues i = 1/`replications' {
						global draw_number = `i'
						di "${program_folder}/`do_file'"
						* Run the program with the "bootstrap" option and store estimates for this draw
						if `debug' == 0 qui do "${program_folder}/`do_file'" `program' yes `use_estimates' `mode' // first place the policy .do files are called
						if `debug' == 1 noi do "${program_folder}/`do_file'" `program' yes `use_estimates' `mode'
						foreach est in `ests'{
							if "${`est'_`program'}" != ""{
								replace `est'_`program' = ${`est'_`program'} in `i'							
							}
						}
					}
				}
			}
			*** End of 1000 loop
				
			* Get point estimates
			global draw_number = 0
			if `debug' == 0 qui do "${program_folder}/`do_file'" `program' no `use_estimates' `mode'
			if `debug' == 1 noi do "${program_folder}/`do_file'" `program' no `use_estimates' `mode'
			local inf = 99999
			local infinity_`program' = `inf'
				
			
			if `replications' >0 {
				if inlist("`mode'","baseline", "current")  {
					*Save draws
					gen draw_id = _n
					local program_temp `program'
					local mode_temp `mode'
					save "${bootstrap_files}/`program_temp'_`mode_temp'_`replications'_draws_corr_1.dta", replace
					drop draw_id
				}


				* If 99999 is not high enough, set new infinity
				qui su MVPF_`program' if !mi(MVPF_`program')
				local max = r(max)
				local min = r(min)
				local infinity_`program' = max(abs(`max'), abs(`min'), `inf' , abs(${MVPF_`program'}))
				if `infinity_`program''>`inf' {
					local infinity_`program' = `infinity_`program'' * 10
					replace MVPF_`program' = `infinity_`program'' if MVPF_`program' == `inf'
					replace MVPF_`program' = -`infinity_`program'' if MVPF_`program' == -`inf'
					if ${MVPF_`program'} == `inf' {
						global MVPF_`program' = `infinity_`program''
					}
					if ${MVPF_`program'} == -`inf' {
						global MVPF_`program' = -`infinity_`program''
					}

				}
			}

			
			*Save all estimates in separate rows
			clear
			
			local word_count : word count `ests'
			di in red `word_count'
			scalar var_count = `word_count'
			di var_count
			set obs `=scalar(var_count)'
			g col = `c'
			g program = "`program'"
			g component_type = ""
			g component_value = .
			recast double component_value
			g l_component = .
			g u_component = .
			g component_sd = .
			
			*********** Making the Final Table of Calculations ***********
			local i = 1
			di in red "`i'"
			foreach est in `ests' {
				di "`est'"
				replace component_type = "`est'" if _n == `i'
				if "${`est'_`program'}" != ""{
					replace component_value = ${`est'_`program'} if _n == `i'
				}
				local `est'index = `i'
				local ++ i
			}
			g infinity = `infinity_`program''
			gen component_over_prog_cost = .
			foreach est in WTP cost {
				replace component_over_prog_cost = component_value / ${program_cost_`program'} if component_type == "`est'"
			}

			*list assumptions
			gen assumptions = "`mode'"
			gen correlation = $correlation
			gen replications = $reps

			tempfile `program'_ests_`c'
			save ``program'_ests_`c'', emptyok
			ds
		}

		*-------------------------------------------------------------------------------
		*	3. Export estimates
		*-------------------------------------------------------------------------------
		use ``program'_ests_1', clear

		if `columns' > 1 {
			forval c = 2/`columns' {
				append using ``program'_ests_`c''
			}
		}

		drop col

		tempfile `program'_unbdd_ests
		save ``program'_unbdd_ests'
		
		drop infinity
		tempfile `program'_ests
		save ``program'_ests'


		if "`mode'" == "baseline"{
			local out_temp ${bootstrap_files}

			export delimited using "`out_temp'/`program'_baseline_estimates_`replications'_replications.csv", replace
			save "`out_temp'/`program'_baseline_estimates_`replications'_replications.dta", replace // version used for waterfall charts
			use ``program'_unbdd_ests', clear
			export delimited using "`out_temp'/`program'_baseline_unbounded_estimates_`replications'_replications.csv", replace
		}
		else{
			save "${bootstrap_files}/`program'_`mode'_estimates_`replications'_replications.dta", replace // version used for waterfall charts
			use ``program'_unbdd_ests', clear
			save "${bootstrap_files}/`program'_`mode'_unbounded_estimates_`replications'_replications.dta", replace
		}

		pause

		di in red "Finished running for `program' under `mode'"

		*Get back bounded estimates for inspection
		use ``program'_ests', clear


		if _rc > 0 {
			if _rc == 1 continue, break
			local error_progs = "`error_progs'"+"`program' on `mode', "
			di as err "`program' broke"
		}

	} //end of program loop
} //end of mode loop
 

*Throw errors if things didn't run
if _rc != 1 {
	global error_progs = "`error_progs'"
	if "`error_progs'" != "" di as err "Finished running but the following programs threw errors: `error_progs'"
	else di in red "Finished running with no errors"
}


