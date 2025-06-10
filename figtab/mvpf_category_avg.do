************************************************************************
/* Purpose: Calculate MVPF Category Averages*/
************************************************************************
ssc install missings
local stub1 "local_assumption_mvpf_plot_data/2025-06-09_15-57-36__wind_current_no_cap_factor_193"
local stub2 "local_assumption_mvpf_plot_data/2025-06-09_15-13-01__wind_current_lifetime_increase_193"
local stub3 "local_assumption_mvpf_plot_data/2025-06-09_15-10-16__wind_current_lifetime_reduce_193"
local stub4 "local_assumption_mvpf_plot_data/2025-06-09_17-18-47__wind_current_emissions_half_193"
local stub5 "local_assumption_mvpf_plot_data/2025-06-09_16-52-33__wind_current_emissions_double_193"
local stub6 "local_assumption_mvpf_plot_data/2025-06-09_15-02-02__wind_current_lcoe_2_193"
local stub7 "local_assumption_mvpf_plot_data/2025-06-09_14-59-23__wind_current_lcoe_05_193"
local stub8 "local_assumption_mvpf_plot_data/2025-06-09_14-43-55__wind_current_semie_193"
local stub9 "local_assumption_mvpf_plot_data/2025-06-02_15-26-00__solar_output_decrease_193"
local stub10 "local_assumption_mvpf_plot_data/2025-06-02_15-09-51__solar_output_increase_193"
local stub11 "local_assumption_mvpf_plot_data/2025-06-02_14-47-03__solar_lifetime_increase_193"
local stub12 "local_assumption_mvpf_plot_data/2025-06-02_14-24-30__solar_lifetime_reduce_193"
local stub13 "local_assumption_mvpf_plot_data/2025-06-02_16-52-16__ev_vehicle_lifetime_20"
local stub14 "local_assumption_mvpf_plot_data/2025-06-02_16-28-03__ev_vehicle_lifetime_15"
local stub15 "local_assumption_mvpf_plot_data/2025-06-02_15-42-59__ev_VMT_rebound_one_193"
local stub16 "local_assumption_mvpf_plot_data/2025-06-02_16-03-07__ev_new_car_193"
local stub17 "local_assumption_mvpf_plot_data/2025-06-02_23-12-05__weather_current_decr_lifespan_193"
local stub18 "local_assumption_mvpf_plot_data/2025-06-02_22-52-13__weather_current_marginal_chng_193"
local stub19 "local_assumption_mvpf_plot_data/2025-06-02_22-33-59__weather_current_marginal_per_193"
local stub20 "local_assumption_mvpf_plot_data/2025-06-02_23-59-38__hybrid_current_lifetime_decr_193"
local stub21 "local_assumption_mvpf_plot_data/2025-06-02_23-44-53__hybrid_current_lifetime_incr_193"
local stub22 "local_assumption_mvpf_plot_data/2025-06-02_23-30-44__hybrid_current_new_car_193"
local stub23 "local_assumption_mvpf_plot_data/2025-06-03_00-24-09__appliance_current_lifetime_5_193"
local stub24 "local_assumption_mvpf_plot_data/2025-06-03_00-13-30__appliance_current_lifetime_25_193"
local stub25 "local_assumption_mvpf_plot_data/2025-06-03_00-55-18__vehicle_ret_current_age_incr_193"
local stub26 "local_assumption_mvpf_plot_data/2025-06-03_00-44-36__vehicle_ret_current_marginal_chng_193"
local stub27 "local_assumption_mvpf_plot_data/2025-06-03_10-30-00__vehicle_ret_current_no_rb_193"


foreach i of numlist 1/27 {
	local stub `stub`i''
	quietly {
		use "${code_files}/4_results/`stub'/compiled_results_all_uncorrected_vJK", clear
		missings dropvars, force
		drop component_over_prog_cost
		cap drop perc_switch
		ren component_value cv
		cap drop assumptions component_sd
			
		replace cv = cv
		cap drop l_component u_component
			
		reshape wide cv, i(program) j(component_type) string
		ren cv* *
		replace WTP_cc = WTP if WTP_cc == .
		gen WTP_cc_scaled = WTP_cc / program_cost
		gen cost_scaled = cost/program_cost
		keep program WTP_cc_scaled cost_scaled
		collapse (mean) cost_scaled WTP_cc_scaled
		gen MVPF = WTP_cc_scaled / cost_scaled
	}
	di "Category Average for: `stub':"
	di  MVPF[1]
}