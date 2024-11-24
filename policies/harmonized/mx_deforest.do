********************************************************************************
/*  0. Program: Payments for Ecosystem Services in Mexico                     */
********************************************************************************
/*
Izquierdo-Tort, Santiago, Seema Jayachandran, Santiago Saavedra.
"Redesigning payments for ecosystem services to increase cost-effectiveness."
Unpublished.
*/


********************************
/* 1. Pull Global Assumptions */
********************************
* Project wide globals
local discount = ${discount_rate}

*********************************
/* 2. Estimates from Paper */
*********************************
/* Import estimates from paper, giving option for corrected estimates.
When bootstrap!=yes import point estimates for causal estimates.
When bootstrap==yes import a particular draw for the causal estimates. */

if "`1'" != "" global name = "`1'"
local bootstrap = "`2'"
if "`3'" != "" global folder_name = "`3'"
if "`bootstrap'" == "yes" {
*	if ${draw_number} ==1 {
        preserve
            use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}.dta", clear
            qui ds draw_number, not 
            global estimates_${name} = r(varlist)
            
            mkmat ${estimates_${name}}, matrix(draws_${name}) rownames(draw_number)
        restore
*	}
    local ests ${estimates_${name}}
    foreach var in `ests' {
        matrix temp = draws_${name}["${draw_number}", "`var'"]
        local `var' = temp[1,1]
    }
}
if "`bootstrap'" == "no" {
    preserve
        
qui import excel "${code_files}/2a_causal_estimates_papers/${folder_name}/${name}.xlsx", clear sheet("wrapper_ready") firstrow        
levelsof estimate, local(estimates)


        foreach est in `estimates' {
            su pe if estimate == "`est'"
            local `est' = r(mean)
        }
    restore
}
if "`bootstrap'" == "pe_ci" {
	preserve
		use "${code_files}/2b_causal_estimates_draws/${folder_name}/${ts_causal_draws}/${name}_ci_pe.dta", clear
		
levelsof estimate, local(estimates)


		foreach est in `estimates' {
			sum ${val} if estimate == "`est'"
			local `est' = r(mean)
		}
	restore 
}


****************************************************
/* 3. Set local assumptions unique to this policy */
****************************************************
if "`4'" == "baseline" | "`4'" == "baseline_gen"{
	global dollar_year = ${policy_year}
}
if "`4'" == "current"{
	global dollar_year = ${current_year}
}

local dollar_year = ${dollar_year}

local years = 1 / (0.142 + 0.011)

local control_year = `dollar_year'
local treat_year = round(`control_year' + `years')

local scc_control = ${sc_CO2_`control_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})

local scc_treat = ${sc_CO2_`treat_year'} * (${cpi_`dollar_year'} / ${cpi_${sc_dollar_year}})



local carbon_per_ha = 550 // number is specific to the Lacandona forest, doesn't include behavioral response


****************************************************
/* 4. Calculate MVPF */
****************************************************
/* local subsidy_raw_control = 313400 / 7.3 // in Mexican pesos, pg. 20
local subsidy_converted_control = `subsidy_raw_control' * 0.0503 // conversion rate of 1 MXN to USD on Jul. 16, 2021 from Google
local subsidy_control = `subsidy_converted_control' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})

local subsidy_raw_treatment = 591000 / 62.9 // in Mexican pesos, pg. 20
local subsidy_converted_treatment = `subsidy_raw_treatment' * 0.0503 // conversion rate of 1 MXN to USD on Jul. 16, 2021 from Google
local subsidy_treatment = `subsidy_converted_treatment' * (${cpi_`dollar_year'} / ${cpi_${policy_year}}) */

/* local subsidy = `subsidy_treatment' - `subsidy_control' // difference in subsidy per marginal hectare */

local subsidy_raw = 8982 / 20.036 // per marginal hectare (MX$1000 / prop_marginal)
local subsidy = `subsidy_raw' * (${cpi_`dollar_year'} / ${cpi_${policy_year}})

local program_cost = `subsidy' // per marginal hectare (MX$1000 / prop_marginal)

/* local treatment_loss_percent = 0.14 + `treatment_effect' // 9.6% tree loss in treatment group

local control_loss_percent = 0.14 // 14% tree loss in control group

local control_saved = 1 - `control_loss_percent' // for Latex
local treat_saved = 1 - `treatment_loss_percent' // for Latex

local prop_inframarginal = (1 - `control_loss_percent') / (1 - `treatment_loss_percent') */

local prop_marginal = 65.8 / 591 // 65.8 = marginal hectares, 591 comes from MX$591,000 being paid at MX$1,000 per ha
local prop_inframarginal = 1 - `prop_marginal'

local wtp_infr = `prop_inframarginal' * `subsidy'

local wtp_marg = `prop_marginal' * `subsidy' * 0.5

local transfer = `wtp_infr' + `wtp_marg' // for Latex

local control_scc = `scc_control'
local treat_scc = `scc_treat' / ((1 + `discount')^`years')
local scc = `control_scc' - `treat_scc'

local wtp_soc = `carbon_per_ha' * `scc' * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))

local fiscal_externality_lr = -`carbon_per_ha' * `scc' * (${USShareFutureSSC} * ${USShareGovtFutureSCC})

local total_wtp = `wtp_marg' + `wtp_infr' + `wtp_soc'

local total_cost = `program_cost' + `fiscal_externality_lr'

local MVPF = `total_wtp' / `total_cost'

local WTP_USPres = 0
local WTP_USFut = (`carbon_per_ha' * `scc') * (${USShareFutureSSC} - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
local WTP_RoW = ((1 - ${USShareFutureSSC}) * (`carbon_per_ha' * `scc')) + `wtp_marg' + `wtp_infr'

local MVPF_US = `WTP_USFut' / `total_cost'

assert round((`WTP_RoW' + `WTP_USFut' + `WTP_USPres') / `total_cost', 0.01) == round(`MVPF', 0.01)

****************
/* 5. Outputs */
****************
global normalize_`1' = 1

global MVPF_`1' = `MVPF'
global WTP_USPres_`1' = `WTP_USPres'
global WTP_USFut_`1'  = `WTP_USFut'
global WTP_RoW_`1'    = `WTP_RoW'

global WTP_`1' = `total_wtp'

global wtp_glob_`1' = `wtp_soc'

global wtp_marg_`1' = `wtp_marg' 
global wtp_inf_`1' = `wtp_infr' 

global program_cost_`1' = `program_cost'
global fisc_ext_lr_`1' = `fiscal_externality_lr'
global cost_`1' = `total_cost'

** for waterfall charts

global wtp_comps_`1' wtp_marg wtp_inf wtp_glob WTP
global wtp_comps_`1'_commas "wtp_marg", "wtp_inf", "wtp_glob", "WTP"

global cost_comps_`1' program_cost fisc_ext_lr cost
global cost_comps_`1'_commas "program_cost", "fisc_ext_lr", "cost"

global `1'_xlab 1 `"Marginal"' 2 `"Inframarginal"' 3`""Global" "Enviro""' 4 `"Total WTP"' 6 `""Program" "Cost""' 7 `""Climate" "FE""' 8 `""Govt" "Cost""'
* color groupings
global color_group1_`1' = 2
global color_group2_`1' = 3
global color_group3_`1' = 3
global color_group4_`1' = 3
global cost_color_start_`1' = 6
global color_group5_`1' = 7

global `1'_name "Payments for Ecosystem Services to Reduce Deforestation in Mexico"

local y_ub = `WTP' + 0.3
global note_`1' = ""
global normalize_`1' = 1
global yscale_`1' = "range(0 `y_ub')"

if "${latex}" == "yes"{
	if ${sc_CO2_2020} == 193{

		** Latex Output
		local outputs control_saved treat_saved prop_inframarginal subsidy transfer scc_control scc_treat ///
		              scc wtp_soc total_wtp admin_cost program_cost fiscal_externality_lr total_cost MVPF ///
					  MVPF_US prop_marginal years delay_discount treat_scc
		capture: file close myfile
		file open myfile using "${user}/Dropbox (MIT)/Apps/Overleaf/MVPF Climate Policy/macros_`1'_`4'.sty", write replace
		file write myfile "\NeedsTeXFormat{LaTeX2e}" _n
		file write myfile "\ProvidesPackage{macros_`1'_`4'}" _n
		foreach i of local outputs{

			local original = "`i'"
			local newname = "`i'"

			// Remove underscores from the variable name
			while strpos("`newname'", "_"){
				local newname = subinstr("`newname'", "_", "", .)
			}
			local 1 = subinstr("`1'", "_", "", .)
			local 4 = subinstr("`4'", "_", "", .)

			if inlist("`i'", "kwh_per_install", "annual_kwh", "fisc_ext_t", "global_pollutants", "local_pollutants", "wtp_cons_treat", "wtp", "treated_muni_cost") | ///
			   inlist("`i'", "spill_muni_fed_fe", "treated_muni_fed_fe", "scc_treat"){
				local `original' = trim("`: display %9.0fc ``original'''")
			}
			else if inlist("`i'", "wtp_cons_spill_n"){
				local `original' = trim("`: display %5.3fc ``original'''")
			}
			else{
				local `original' = trim("`: display %5.2fc ``original'''")
			}
			local command = "\newcommand{\\`newname'`1'`4'}{``original''}"
			di "`command'"
			file write myfile "`command'" _n
			
		}
		file close myfile

	}

}

