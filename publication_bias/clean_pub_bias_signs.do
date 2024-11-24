


global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"
global outdata "${working}/data/uncorrected"
global raw_data "${maindir}/code_files/2a_causal_estimates_papers/uncorrected"
global corrected_data "${maindir}/code_files/2a_causal_estimates_papers/corrected"
global newinputs "${dropbox_me}/miscellany/JK_ed_wrapper_inputs"
global policylist "${maindir}/code_files/"



import excel using "${policylist}/policy_details_v3.xlsx", clear firstrow
drop if extended == 1 | international==1| regulation==1 
qui levelsof(program), local(programs) clean


local filelist: dir "$newinputs" files "*.xlsx" , respectcase
di "`:word 1 of `filelist''"

foreach policy of local programs {
    local policy_list_xlsx `policy_list_xlsx' `policy'_vJK.xlsx
}
local testlist: list policy_list_xlsx - filelist
foreach word of local testlist {
    di  "`word'" 
}
 
local filelistfinal: list filelist & policy_list_xlsx

clear 

foreach file of local filelistfinal {
    preserve
        import excel using "${newinputs}/`file'", clear sheet(raw_data) firstrow
        qui ds *, v(32)
        local vars `r(varlist)'
        cap destring B, force replace
        cap destring estimate, force replace 
        cap keep if "`:word 1 of `vars''"=="estimate" | !mi(B)

        local renamevars estimate pe se t_stat p_value ci_lo ci_hi pub_bias expected_sign source notes

        forv i=1/`:word count `renamevars'' {
            cap ren `:word `i' of `vars'' `:word `i' of `renamevars'' 
        }


        cap keep if !mi(estimate)| !mi(pe)

        g program = "`file'"
        tempfile toappend
        save `toappend'
    restore 
    append using `toappend', force
}
destring pe se t_stat p_value ci_lo ci_hi, replace

**************** COMPARE TO BASELINE ******************* 
clear 
foreach file of local filelistfinal {
    preserve
        import excel using "${newinputs}/`file'", clear sheet(wrapper_ready) firstrow


        g program = "`file'"
        tempfile toappend
        save `toappend'
    restore 
    append using `toappend', force
}
drop if mi(pe)
drop if mi(se) & mi(t_stat) & mi(p_value) & mi(ci_lo) & mi(ci_hi)
drop if se==0 & mi(t_stat) & mi(p_value) & mi(ci_lo) & mi(ci_hi)
replace program = subinstr(program,"_vJK.xlsx","",.)

tempfile new 
save `new'

clear
local filelistold: dir "$raw_data" files "*.csv" , respectcase

foreach policy of local programs {
    local policy_list_csv `policy_list_csv' `policy'.csv
}


local filelistfinal: list filelistold & policy_list_csv


foreach file of local filelistfinal {
    preserve
        import delimited using "${raw_data}/`file'", clear  


        g program = "`file'"
        tempfile toappend
        save `toappend'
    restore 
    append using `toappend', force
}

drop if mi(se) & mi(t_stat) & mi(p_value) & mi(ci_lo) & mi(ci_hi)
drop if se==0 & mi(t_stat) & mi(p_value) & mi(ci_lo) & mi(ci_hi)

ren * *_old
ren (estimate_old program_old) (estimate program)
replace program = subinstr(program,".csv","",.)
merge 1:1 estimate program using `new' , keep(3) 
