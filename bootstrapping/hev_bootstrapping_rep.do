********************************
*HEV Bootstrapping
********************************
clear
local policies = "hev_usa_s hev_usa_i hybrid_cr"

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
replace policy = "hev_usa_s" if hev_usa_s == 1
replace policy = "hev_usa_i" if hev_usa_i == 1
replace policy = "hybrid_cr" if hybrid_cr == 1
drop hev_usa_s hev_usa_i hybrid_cr

**************************************
*Convert draws to elasticities
**************************************
gen elas = .

*Get HEV USA - Sales Tax Elasticity
***********************************

replace elas = (semie / 1000) * 18492.75680284473 if policy == "hev_usa_s"

*Get HEV USA - Income Tax Elasticity
***********************************

replace elas = (semie / 1000) * 18005.75680284473 if policy == "hev_usa_i"

*Get Hybrid Credit Elasticity
*****************************

replace elas = (hybrid_increase / 2276) * 22873.54526474334 if policy == "hybrid_cr"

****************************************************
*Create a crosswalk between elasticity and MVPF
****************************************************
global scc = "`2'"
global lbd = "`3'"
global value_savings = "`4'"
global value_profits = "`5'"


preserve
    // Only run once
    tempname hev_bootstrap
    tempfile hev_bootstrap_data
    postfile `hev_bootstrap' elasticity MVPF cost wtp_cc using `hev_bootstrap_data', replace 
        local i = 0
        forvalues e = -0.2(0.2)9.6 {
            global feed_in_elas = `e'
            di in red "Running for an elasticity of -`e'"
            if `i' == 0{
                qui run_program hev_testing, mode("`1'") folder("robustness") scc(${scc}) macros("yes")
            }
            else{
                qui run_program hev_testing, mode("`1'") folder("robustness") scc(${scc}) macros("no")
            }

    
            post `hev_bootstrap' (`e') (${MVPF_hev_testing}) (${cost_hev_testing}) (${WTP_cc_hev_testing})
            local i = 1
        }       
    postclose `hev_bootstrap'
restore


preserve

    use `hev_bootstrap_data', clear


    nl exp2: wtp_cc elasticity
    cap drop wtp_predicted
    gen wtp_predicted = _b[/b1]*(_b[/b2]^elasticity)

    ** Visually check the non-linear model 
    *twoway (scatter wtp elasticity, mcolor("`bar_dark_blue'")) || (line wtp_predicted elasticity, lcolor("`bar_light_blue'")), ///
        xtitle("Elasticity") ///
        ytitle("WTP") ///
        title("HEVs") ///
        legend(label(1 "WTP") label(2 "Fitted Values"))


    gen b1_wtp = _b[/b1]
    local b1_wtp = _b[/b1]
    gen b2_wtp = _b[/b2]
    local b2_wtp = _b[/b2]

    nl exp3: cost elasticity
    gen cost_predicted = _b[/b0] + _b[/b1] * (_b[/b2] ^ elasticity)

    *twoway (scatter cost elasticity, mcolor("`bar_dark_blue'")) || (line cost_predicted elasticity, lcolor("`bar_light_blue'")), ///
        xtitle("Elasticity") ///
        ytitle("Cost") ///
        title("HEVs") ///
        legend(label(1 "Cost") label(2 "Fitted Values"))

    gen b0_cost = _b[/b0]
    local b0_cost = _b[/b0]
    gen b1_cost = _b[/b1]
    local b1_cost = _b[/b1]
    gen b2_cost = _b[/b2]
    local b2_cost = _b[/b2]

restore


gen predicted_WTP_cc = `b1_wtp'*(`b2_wtp'^elas)
gen predicted_cost = `b0_cost' + `b1_cost' * (`b2_cost' ^ elas)

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
global hev_m_low = `r(r1)'
global hev_m_high = `r(r2)'
