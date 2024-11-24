********************************************************************************
*						PREPARE CAUSAL ESTIMATES							   *
********************************************************************************
display `"All the arguments, as typed by the user, are: `0'"'

* Set options
local replications ${reps}
local correlation 1

*-------------------------------------------------------------------------------
*	0. Define programs to run for
*-------------------------------------------------------------------------------

if "`1'" == ""{ // file not being run externally

	global nrun = ""
	global stamp = "${nrun}"
	global redraw_causal_estimates = "yes"
    global ts_causal_draws = "${stamp}"
    cap mkdir "${causal_draws}/${ts_causal_draws}"
}


*Allow file to be ran externally from metafile
if "`1'" != "" { // file is being run externally
	local programs "`1'"

}

*Set the seed to the value defined in the metafile
confirm number ${welfare_seed}
set seed ${welfare_seed}

*Loop over programs
foreach program in `programs' {

	set seed ${welfare_seed}

	*check if draws exist
	cap confirm file "${causal_draws}/${ts_causal_draws}/`program'.dta"
 
	if _rc == 0 & "${redraw_causal_estimates}" != "yes" {
		di in red "Skipping redrawing for `program'"
		continue
	}

	noi di "`program' "

	import excel "${causal_ests}/`program'.xlsx", clear sheet("wrapper_ready") firstrow
	sort estimate

	*Get SE from t-stat
	replace se = abs(pe / t_stat) if se == . & t_stat != .

	*Get SE from ci range (Assumed to be 95% CI)
	replace se = ((ci_hi - ci_lo) / 2) / invnormal(0.975) if se == . & ci_lo != . & ci_hi != .

	*Allow for p-value ranges
	cap tostring p_value, replace force
	g p_value_range = p_value if regexm(p_value,"\[")|regexm(p_value,"\]")
	replace p_value = "" if p_value_range != ""
	destring p_value, replace force
	replace se = abs(pe / invnormal(p_value/2)) if p_value_range == "" & se == .
	g p_val_low = strtrim(substr(p_value_range,strpos(p_value_range,"[")+1,strpos(p_value_range,";")-strpos(p_value_range,"[")-1)) if p_value_range != ""
	g p_val_high = strtrim(substr(p_value_range,strpos(p_value_range,";")+1,strpos(p_value_range,"]")-strpos(p_value_range,";")-1)) if p_value_range != ""
	destring p_val_low p_val_high, replace
	drop if estimate == ""

	*Get PE matrix
	mkmat pe, matrix(pes) // just turns the column of estimates into a matrix

	*Get correlation matrix
	/* Here blocks are indicated by different base numbers and the sign determines
	the correlation direction. E.g. if we have four variables with corr_directions
	1, -1, 2, 2 respectively, then 1 and 2 are negatively correlated, 3 and 4 are
	positively correlated, and 1 and 2 are uncorrelated with 3 and 4. */

	matrix corr = J(`=_N', `=_N', 0)
	matlist corr
	local namelist
	forval j = 1/`=_N' {
		local name_`j' = estimate[`j']
		forval k = 1/`=_N' {
			if `j' == `k' matrix corr[`j',`k'] = 1
			else {
				if abs(corr_direction[`j'])==abs(corr_direction[`k']) {
					matrix corr[`j', `k'] = sign(corr_direction[`j'] * corr_direction[`k']) * `correlation'
				}
			else matrix corr[`j',`k'] = 0
			}
		}
		local namelist `namelist' `name_`j''
	}	

	*Loop over replications to get SE matrix (can vary due to p-value ranges)
	forval i = 1/`replications' {
		matrix se_`i' = J(`=_N', 1, 0)
		forval j = 1/`=_N' {
			if se[`j']!=. {
				matrix se_`i'[`j',1] = se[`j']
			}
			if se[`j'] == . & p_value_range[`j'] != "" {
				matrix se_`i'[`j',1] = abs(pe[`j'] / invnormal(runiform(p_val_low[`j'],min(p_val_high[`j'],0.9))/2))
			}
		}		
	}
	qui{
		*Draw uncorrected, save dataset 
		forval i = 1/`replications' {
			clear
			set obs 1
			drawnorm "`namelist'", n(1) sds(se_`i') corr(corr) means(pes)
			local j = 0
			foreach var in `namelist' {
				local ++j
				g `var'_pe = pes[`j',1]
			}
			tempfile temp`i'
			save `temp`i''
		}

		forval i = 1/`=`replications'-1' {
			append using `temp`i''
		}
	}

	g draw_number = _n
	order draw_number, first

	save "${causal_draws}/${ts_causal_draws}/`program'.dta", replace

	if _rc>0 {
		if _rc==1 continue, break
		di _rc
		local error_progs = "`error_progs'"+"`program'  "
		di as err "`program' broke"
	}

}

*Throw errors if things didn't run
if _rc!=1 {
	global error_progs = "`error_progs'"
	if "`error_progs'"!="" di as err "Finished running but the following programs threw errors: `error_progs'"
	else di in red "Finished running with no errors"
}







