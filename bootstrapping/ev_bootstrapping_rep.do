********************************
*EV Bootstrapping
********************************
clear
local policies = "bev_state muehl_efmp"

*************************************************
*Create and Append the distribution of the draws
*************************************************
global reps = `6'

foreach policy in `policies' {
	noi do "${github}/wrapper/prepare_causal_estimates.do" ///
	"`policy'" // programs to run / all_programs
}

clear
foreach policy in `policies' {
	append using "${causal_draws}/${ts_causal_draws}/`policy'.dta", gen(`policy')
}

gen policy = " "
replace policy = "bev_state" if bev_state == 1
replace policy = "muehl_efmp" if muehl_efmp == 1
drop bev_state muehl_efmp

**************************************
*Convert draws to elasticities
**************************************
gen elas = .

*Get BEV State Elasticity
*****************************

replace elas = (semie / 1000) * 37573.26051496494 if policy == "bev_state"

*Get Muehlegger EFMP Elasticity
*****************************

replace elas = epsilon * 0.85 if policy == "muehl_efmp"

****************************************************
*Create a crosswalk between elasticity and MVPF
****************************************************
global scc = "`2'"
global lbd = "`3'"
global value_savings = "`4'"
global value_profits = "`5'"



preserve
    // Only run once
    tempname bev_bootstrap
    tempfile bev_bootstrap_data
    postfile `bev_bootstrap' elasticity MVPF cost wtp_cc using `bev_bootstrap_data', replace 
        local i = 0
        forvalues e = 0(0.1)6.5 {
            global feed_in_elas = `e'
            di in red "Running for an elasticity of -`e'"
            if `i' == 0{
                qui run_program bev_testing, mode("`1'") folder("robustness") scc(${scc}) macros("yes")
            }
            else{
                qui run_program bev_testing, mode("`1'") folder("robustness") scc(${scc}) macros("no")
            }
            
            post `bev_bootstrap' (`e') (${MVPF_bev_testing}) (${cost_bev_testing}) (${WTP_cc_bev_testing})
            local i = 1
        }

    postclose `bev_bootstrap'
restore

preserve
    use `bev_bootstrap_data', clear

    nl exp2: wtp_cc elasticity
    cap drop wtp_predicted


    gen wtp_predicted = _b[/b1]*(_b[/b2]^elasticity)

    ** Visually check the non-linear model 
    *twoway (scatter wtp elasticity, mcolor("`bar_dark_blue'")) || (line wtp_predicted elasticity, lcolor("`bar_light_blue'")), ///
        xtitle("Elasticity") ///
        ytitle("WTP") ///
        title("BEVs") ///
        legend(label(1 "WTP") label(2 "Fitted Values"))


    gen b1_wtp = _b[/b1]
    local b1_wtp = _b[/b1]
    gen b2_wtp = _b[/b2]
    local b2_wtp = _b[/b2]

    nl log4: cost elasticity
    gen cost_predicted = _b[/b0] + _b[/b1] / (1 + exp(-_b[/b2] * (elasticity - _b[/b3])))

    *twoway (scatter cost elasticity, mcolor("`bar_dark_blue'")) || (line cost_predicted elasticity, lcolor("`bar_light_blue'")), ///
        xtitle("Elasticity") ///
        ytitle("Cost") ///
        title("BEVs") ///
        legend(label(1 "Cost") label(2 "Fitted Values"))

    gen b0_cost = _b[/b0]
    local b0_cost = _b[/b0]
    gen b1_cost = _b[/b1]
    local b1_cost = _b[/b1]
    gen b2_cost = _b[/b2]
    local b2_cost = _b[/b2]
    gen b3_cost = _b[/b3]
    local b3_cost = _b[/b3]

restore

**** If you don't want to rerun the generic EV .do file with all of the different elasticities, you can use this existing dataset

/* preserve

    use "${code_files}/_replication_package/outdta/bootstrapping/ev_synthetic_data_coeffs_${scc}", clear

    sum b1_wtp
    local b1_wtp = r(mean)
    sum b2_wtp
    local b2_wtp = r(mean)

    sum b0_cost
    local b0_cost = r(mean)
    sum b1_cost
    local b1_cost = r(mean)
    sum b2_cost
    local b2_cost = r(mean)
    sum b3_cost
    local b3_cost = r(mean)

restore */

gen predicted_WTP_cc = `b1_wtp'*(`b2_wtp'^elas)
gen predicted_cost = `b0_cost' + `b1_cost' / (1 + exp(-`b2_cost' * (elas - `b3_cost')))

*************************
*Policy-Specific CIs
*************************
foreach policy in `policies' {
	preserve
        keep if policy == "`policy'"
        gen MVPF = predicted_WTP_cc / predicted_cost
        replace MVPF = 99999 if MVPF < 0
        _pctile MVPF, p(2.5, 97.5)
        global `policy'_m_low = `r(r1)'
        global `policy'_m_high = `r(r2)'
	restore
}


*************************
*Category CIs
*************************
collapse (mean) predicted_cost predicted_WTP_cc, by(draw)
gen MVPF = predicted_WTP_cc/predicted_cost

replace MVPF = 99999 if MVPF < 0
_pctile MVPF, p(2.5, 97.5)
global bev_m_low = `r(r1)'
global bev_m_high = `r(r2)'
