* Load assumptions and run a welfare program

cap program drop run_program
program define run_program, rclass
syntax anything(name=program id="Program"), ///
		[mode(string) ///
		folder(string) ///
		scc(integer 193) ///
		ev_fed_subsidy(real -1) ///
		bev_cf_value(string) ///
		hev_cf_value(string) ///
		vmt_adjust(real 0.61544408) ///
		ev_grid(string) ///
		macros(string)]

di "vmt_adjust: `vmt_adjust'"


local policy_folder = "harmonized"
if "`folder'" != "" {
	local policy_folder = "`folder'"
}

if "`macros'" == "" {
	local macros = "no"
}

local bev_cf = "clean_car"
if "`bev_cf_value'" != ""{
	local bev_cf = "`bev_cf_value'"
}

local hev_cf = "muehl"
if "`hev_cf_value'" != ""{
	local hev_cf = "`hev_cf_value'"
}
local ev_grid_value = "US"
if "`ev_grid'" != ""{
	local ev_grid_value = "`ev_grid'"
}

if "`scc'" == "" {
	local scc = 193
}

global rerun_timepaths "no"
global rerun_macros "no"
if "`macros'" == "yes" {
	global scc = `scc'
	do "${github}/wrapper/macros.do" "no"
}

if "`macros'" == "no" {
	if `scc' != ${scc} {
		global scc = `scc'
		do "${github}/wrapper/macros.do" "no"
	}
}

* Set file paths
global program_folder           = "${github}/policies/`policy_folder'"


foreach file in `ado_files' {
	if regexm("`file'","run_program") == 0 do "${ado_files}/`file'"
}
local program = lower("`program'")

* deal with the programs whose assumptions files and or do files have different names
local do_file = "`program'"
local assumption_name = "`program'"

*************************************
* Import program specific Assumptions
*************************************
local spec_type = "current"

if "`mode'" != "" {
	local spec_type = "`mode'"
}

preserve
	import excel "${assumptions}/program_specific/`assumption_name'.xlsx", clear first
	keep if spec_type == "`spec_type'"
	qui count
	assert r(N)==1
	qui ds
	foreach assumption in `r(varlist)' {
		global `assumption' = `assumption'[1]
	}
	
restore

*************************************
* Handling policy-specific options
*************************************

global ev_fed_subsidy `ev_fed_subsidy'
global bev_cf `bev_cf'
global hev_cf `hev_cf'
global EV_VMT_car_adjustment `vmt_adjust'
global ev_grid "`ev_grid_value'"



*************
* Run Do File
*************

if (strpos("`program'", "cpc")) & regexm("`program'","ui")==0 {
	local type_cpc = substr("`program'", strpos("`program'", "_") + 1, .)
	global policy = "`type_cpc'"
	local program = subinstr("`program'", "_`type_cpc'", "",.)
	local do_file = "`program'"
}
global draw_number = 0


do "${program_folder}/`do_file'.do" `program' no uncorrected_vJK `spec_type'

macro drop global bev_cf EV_VMT_car_adjustment hev_cf

global ev_fed_subsidy -1
global hev_cf "muehl"
global EV_VMT_car_adjustment 0.61544408
end
