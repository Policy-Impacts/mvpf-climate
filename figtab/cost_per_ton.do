********************************************************
* Replicating the McKinsey Carbon Abatement Cost Curve *
********************************************************

local data_stub "`1'" 

local output_path "${output_tab}/tables_data"
	
/* Definitions:
The carbon in the denominator for all calculations is CO2eq (including other greenhouse gases), not just CO2.
*/

local mode = "current"
local scc = 193
local profits = "yp"
local savings = "ns"

local lbd = "`2'"
*NOTE: The metafile must be run on at least one policy before this file can be run to ensure the necessary globals are created

if "`lbd'" == "yes"{
	use "${code_files}/4_results/`1'/compiled_results_all_uncorrected_vJK", clear
}
else if "`lbd'" == "no"{
	use "${code_files}/4_results/`1'/compiled_results_all_uncorrected_vJK", clear
}


missings dropvars, force
drop component_over_prog_cost
ren component_value cv

if "`mode'" == "current"{ 
    cap keep if assumptions == "current"
	local modename = "current"
}
else if "`mode'" == "baseline"{
    cap keep if assumptions == "baseline"
}

reshape wide cv, i(program) j(component_type) string

ren cv* *

drop WTP_RoW WTP_USFut WTP_USPres WTP_USTotal

preserve
	import excel "${code_files}/policy_details_v3.xlsx", clear first
	tempfile policy_labels
	save "`policy_labels.dta'", replace
restore 

merge m:1 program using "`policy_labels.dta'", keep(3)

missings dropvars, force
drop _merge program_label_long

drop correlation replications


mvencode _all, mv(0) override

order program_cost, after(WTP)

gen mvpf = MVPF
ren resource_ce resource_ce_no_lbd
ren WTP_cc WTP_lbd
ren MVPF_no_cc MVPF_no_lbd

********************************************
*          Harmonizing Components          *
********************************************

**** Transfer
cap gen wtp_install = 0
cap drop transfer
gen transfer = wtp_cons + wtp_deal + wtp_install
drop wtp_cons wtp_deal wtp_install
replace transfer = wtp_inf + wtp_marg if (inlist(group_label, "Weatherization", "Appliance Rebates", "Other Nudges", "Vehicle Retirement") & program != "wisc_rf" & program != "care" & program != "solarize" & program != "her_compiled" & program != "cw_datta" & program != "dw_datta" & program != "fridge_datta") | inlist(program, "ca_electric", "cookstoves", "mx_deforest", "ug_deforest")
replace transfer = wtp_inf + wtp_marg + wtp_ctr if inlist(program, "ihwap_hb", "ihwap_lb")
drop wtp_inf wtp_marg wtp_private
cap gen wtp_abatement = 0
cap gen wtp_permits = 0
replace transfer = wtp_abatement + wtp_permits if group_label == "Cap and Trade"
drop wtp_abatement wtp_permits
replace transfer = wtp_prod if group_label == "Wind Production Credits" | inlist(program, "rao_crude", "bmm_crude", "india_offset")
replace transfer = 1 if program == "sallee_hy"

**** Global and Local Enviro
assert round(wtp_no_ice, 0.0001) == round(wtp_no_ice_g + wtp_no_ice_local, 0.0001)
assert round(wtp_yes_ev, 0.0001) == round(wtp_yes_ev_local + wtp_yes_ev_g, 0.0001) if group_label == "Electric Vehicles"
assert round(wtp_loc, 0.0001) == round(wtp_yes_ev_local + wtp_no_ice_local, 0.0001) if group_label == "Electric Vehicles"

drop wtp_no_ice_g wtp_no_ice_local wtp_yes_ev_g wtp_yes_ev_local


assert round(wtp_soc, 0.0001) == round(wtp_glob + wtp_loc, 0.0001) if group_label == "Electric Vehicles"
assert round(wtp_soc, 0.0001) == round(wtp_glob + wtp_loc, 0.0001) if group_label == "Hybrid Vehicles"
replace wtp_glob = wtp_glob + wtp_e_cost if group_label == "Residential Solar" | program == "solarize"
replace wtp_glob = (wtp_glob + wtp_e_cost) - wtp_r_glob if group_label == "Wind Production Credits"
replace wtp_glob = wtp_soc_g if inlist(group_label, "Gasoline Taxes", "Cap and Trade") | inlist(program, "cookstoves", "bmm_crude", "bunker_fuel", "ethanol", "rao_crude")
replace wtp_loc = wtp_soc_l if inlist(group_label, "Gasoline Taxes", "Cap and Trade") | inlist(program, "cookstoves", "bmm_crude", "bunker_fuel", "ethanol", "rao_crude")
replace wtp_loc = 0 if wtp_loc == -1.00e-35
replace wtp_loc = wtp_loc - wtp_r_loc if group_label == "Wind Production Credits"

cap gen wtp_leak = 0
cap gen wtp_no_leak = 0
drop wtp_yes_ev wtp_yes_hev wtp_no_ice wtp_soc wtp_e_cost wtp_soc_g wtp_soc_l wtp_leak wtp_no_leak 

**** Rebound
replace wtp_soc_rbd = 0 if wtp_soc_rbd == 1.00e-11
replace wtp_soc_rbd_l = 0 if wtp_soc_rbd_l == 1.00e-20 | program == "rggi"
replace wtp_soc_rbd_g = 0 if wtp_soc_rbd_g == 1.00e-20 | program == "rggi"
assert round(wtp_soc_rbd, 0.0001) == round(wtp_soc_rbd_g + wtp_soc_rbd_l, 0.0001) if wtp_soc_rbd_g != 0 & wtp_soc_rbd_l != 0
replace wtp_r_loc = wtp_soc_rbd_l if wtp_soc_rbd_l != 0 & wtp_r_loc == 0
replace wtp_r_glob = wtp_soc_rbd_g if wtp_soc_rbd_g != 0  & wtp_r_glob == 0
drop wtp_soc_rbd_l wtp_soc_rbd_g
replace wtp_soc_rbd = wtp_r_glob + wtp_r_loc if wtp_soc_rbd == 0 & wtp_r_glob != 0 & wtp_r_loc != 0
replace wtp_soc_rbd = wtp_r_glob if inlist(program, "care", "opower_ng", "rebate_es", "es_incent", "ac_mex", "fridge_mex", "nudge_ger", "nudge_qatar", "wap_mexico") | inlist(program, "india_offset")
replace wtp_soc_rbd = -wtp_soc_rbd if program == "wisc_rf"
replace wtp_r_loc = -wtp_r_loc if program == "wisc_rf"
replace wtp_r_glob = -wtp_r_glob if program == "wisc_rf"


**** Dynamic Price and Dynamic Enviro
replace env_cost_wtp = 0 if env_cost_wtp == -1.00e-17
replace cost_wtp = 0 if cost_wtp == -1.00e-17

assert round(env_cost_wtp, 0.0001) == round(env_cost_wtp_g + env_cost_wtp_l, 0.0001) if env_cost_wtp_l != 0 & env_cost_wtp_g != 0 & group_label != "Gasoline Tax"

drop cost_mvpf enviro_mvpf firm_mvpf

**** Producers
gen producers = firm_cost_wtp + wtp_prod_s + wtp_prod_u
replace producers = wtp_prod if inlist(group_label, "Residential Solar", "Appliance Rebates", "Weatherization", "Other Nudges", "Home Energy Reports") | program == "care" | program == "ca_electric"
replace producers = wtp_prod if inlist(program, "jet_fuel", "CPP_aj", "CPP_pj", "PER", "baaqmd", "ca_electric")
replace producers = -wtp_prod if program == "wisc_rf"
drop wtp_prod_s wtp_prod_u wtp_prod

**** Fiscal Externalities
replace fisc_ext_s = beh_fisc_ext + fed_fisc_ext + state_fisc_ext if group_label == "Electric Vehicles" | group_label == "Hybrid Vehicles"
replace fisc_ext_t = gas_corp_fisc_e + gas_fisc_ext + utility_fisc_ext if group_label == "Electric Vehicles" | group_label == "Hybrid Vehicles"

gen fisc_ext_sr = fisc_ext_s + fisc_ext_t
drop fisc_ext_s fisc_ext_t

drop beh_fisc_ext fed_fisc_ext state_fisc_ext gas_corp_fisc_e gas_fisc_ext utility_fisc_ext

**** Total WTP
gen WTP_no_lbd = WTP
replace WTP = WTP_lbd if WTP_lbd != 0

**** Total Cost
assert total_cost == cost if total_cost != 0
drop total_cost


**** Normalization Factor
gen normalization = program_cost // for normalizing all the factors such that program_cost is 1
gen prog_cost_no_normal = program_cost

local components transfer wtp_loc wtp_glob wtp_soc_rbd env_cost_wtp cost_wtp producers WTP program_cost fisc_ext_sr fisc_ext_lr cost wtp_r_loc wtp_r_glob WTP_no_lbd WTP_lbd env_cost_wtp_g env_cost_wtp_l c_savings q_CO2
foreach comp of local components{
    replace `comp' = `comp' / normalization
}


if "`savings'" == "ys"{
    assert round(WTP, 0.001) == round(transfer + c_savings + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers, 0.001)
}
else{
    assert round(WTP, 0.001) == round(transfer + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers, 0.001)
}

assert round(cost, 0.001) == round(program_cost + fisc_ext_sr + fisc_ext_lr, 0.001) if program != "bev_state_i" // see if this is fixed after the latest big run

drop if inlist(program, "cafe_dk", "cafe_as", "cafe_j", "rps")
assert round(MVPF, 0.001) == round(WTP / cost, 0.001) if MVPF != 99999

************* Prepping Data for Graphs *************

drop if group_label == "Cap and Trade"


order mvpf resource_ce_no_lbd, after(program)

replace gov_carbon = gov_carbon / normalization
replace resource_cost = resource_ce * q_carbon_mck

* Generating more consistent governtment policy carbon numbers

* Carbon numbers
gen gov_carbon_no_lbd_lazy = (wtp_glob + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) // this is the shortcut version
gen gov_carbon_no_lbd = q_CO2
gen gov_carbon_yes_lbd = (wtp_glob + wtp_r_glob + env_cost_wtp_g) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) // need to adjust all the components to be the pre-scaled values

* Government cost per ton numbers
gen gov_ce_no_lbd = cost / gov_carbon_no_lbd
gen gov_ce_no_lbd_lazy = cost / gov_carbon_no_lbd_lazy
gen gov_ce_yes_lbd = cost / gov_carbon_yes_lbd


replace gov_ce_no_lbd = gov_ce_no_lbd_lazy

order gov_carbon gov_carbon_no_lbd

* Net social cost per ton
g net_social_ce_yes_lbd = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc) / ///
						 ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
g net_social_ce_no_lbd = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - wtp_loc - wtp_r_loc) / ///
						((wtp_glob + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))

list program fisc_ext_sr fisc_ext_lr program_cost transfer producers cost_wtp wtp_loc wtp_r_loc wtp_glob env_cost_wtp wtp_r_glob net_social_ce_yes_lbd net_social_ce_no_lbd if group_label == "Hybrid Vehicles"

* Net social cost per ton with deadweight loss
g net_social_ce_yes_lbd_dwl1 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.1 * cost) / ///
						       ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
g net_social_ce_yes_lbd_dwl3 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.3 * cost) / ///
						 	   ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
g net_social_ce_yes_lbd_dwl5 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.5 * cost) / ///
						 	   ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))


* Resource cost with cost curve price included, no dynamic enviro though
* check that semie is the 2020 one
replace pass_through = 1 if pass_through == 0
list program resource_cost cost_wtp prog_cost_no_normal semie pass_through q_carbon_mck if inlist(group_label, "Residential Solar", "Wind Production Credits", "Electric Vehicles", "Hybrid Vehicles")
*no prog cost for solar

gen resource_ce_yes_lbd = (resource_cost - (cost_wtp / (semie * pass_through))) / q_carbon_mck
list program resource_cost cost_wtp semie pass_through q_carbon_mck resource_ce_yes_lbd if group_label == "Hybrid Vehicles"

local annual_output = 1.44
replace resource_ce_yes_lbd = (resource_cost + (cost_wtp / (semie * 100))) / q_carbon_mck if group_label == "Wind Production Credits" // no wind policies have pass-through rates

list program resource_cost semie pass_through q_carbon_mck if group_label == "Residential Solar"
replace resource_ce_yes_lbd = (resource_cost + (cost_wtp / (semie * pass_through * 25 * `annual_output'))) / q_carbon_mck if group_label == "Residential Solar" // solar

list program resource_ce_yes_lbd if inlist(group_label, "Residential Solar", "Wind Production Credits", "Electric Vehicles", "Hybrid Vehicles")

replace resource_ce_yes_lbd = resource_ce_no_lbd if env_cost_wtp_g == 0

* Benefit/Cost Ratio
gen bcr = (WTP - fisc_ext_sr - fisc_ext_lr) / program_cost

* WTP and MVPF with and without cost curve
replace WTP_lbd = WTP if inlist(group_label, "Appliance Rebates", "Cap and Trade", "Home Energy Reports", "Other Nudges", "Other Fuel Taxes", "Vehicle Retirement", ///
								"Weatherization", "Other Revenue Raisers")
replace MVPF_no_lbd = MVPF if inlist(group_label, "Appliance Rebates", "Cap and Trade", "Home Energy Reports", "Other Nudges", "Other Fuel Taxes", "Vehicle Retirement", "Weatherization", "Other Revenue Raisers")

replace WTP_lbd = WTP if group_label == "Gasoline Tax"
replace WTP_no_lbd = WTP_lbd - cost_wtp - env_cost_wtp_l - env_cost_wtp_g if group_label == "Gasoline Tax"

replace MVPF_no_lbd = WTP_no_lbd / (cost - env_cost_wtp_g * (${USShareFutureSSC} * ${USShareGovtFutureSCC})) if group_label == "Gasoline Tax" | group_label == "Residential Solar"
replace MVPF_no_lbd = mvpf if inlist(group_label, "Appliance Rebates", "Cap and Trade", "Home Energy Reports", "Other Nudges", "Other Fuel Taxes", "Vehicle Retirement", "Weatherization", "Other Revenue Raisers")

assert round(MVPF_no_lbd, 0.00001) == round(mvpf, 0.00001) if inlist(group_label, "Appliance Rebates", "Cap and Trade", "Home Energy Reports", "Other Nudges", "Other Tax", "Vehicle Retirement", "Weatherization")
if "`mode'" == "current"{
	assert MVPF_no_lbd > mvpf if group_label == "Gasoline Tax"
}

order program mvpf MVPF_no_lbd resource_ce_no_lbd gov_ce_yes_lbd gov_ce_no_lbd net_social_ce_yes_lbd net_social_ce_no_lbd

order gov_ce_no_lbd gov_ce_no_lbd_lazy, after(program)

drop if extended == 1

//////////////////////////////// Table of Different Measures of Cost-Effectiveness for Each Policy ////////////////////////////////

drop if inlist(group_label, "Rice Burning", "Deforestation", "International Rebates", "International Nudges", "Wind Offset", "Cookstoves", "Other Subsidies", "Other Nudges", "Renewable Portfolio Standards")
gen group_label_code = substr(group_label, 1, 4)

replace group_label_code = subinstr(group_label_code, " ", "", .)
replace group_label_code = "ofue" if group_label == "Other Fuel Taxes"
replace group_label_code = "orev" if group_label == "Other Revenue Raisers"

** Tables with different cost per ton measures with and without learning-by-doing, only category averages
preserve


	cap drop if extended == 1
	replace across_group_ordering = 11 if group_label == "Gasoline Taxes"
	replace across_group_ordering = 13 if group_label == "Other Revenue Raisers"
	collapse transfer wtp_loc wtp_glob wtp_soc_rbd wtp_r_glob wtp_r_loc env_cost_wtp env_cost_wtp_g env_cost_wtp_l cost_wtp producers program_cost fisc_ext_sr fisc_ext_lr ///
			 resource_ce_no_lbd resource_ce_yes_lbd , by(group_label_code group_label across_group_ordering)

	gen bcr = (transfer + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers - fisc_ext_sr - fisc_ext_lr) / program_cost
	
	gen mvpf_yes_lbd = (transfer + wtp_loc + wtp_glob + wtp_soc_rbd + env_cost_wtp + cost_wtp + producers) / (program_cost + fisc_ext_sr + fisc_ext_lr)
	gen cost_yes_lbd = program_cost + fisc_ext_sr + fisc_ext_lr

	gen wtp_no_lbd = transfer + wtp_loc + wtp_glob + wtp_soc_rbd + producers
	gen cost_no_lbd = program_cost + fisc_ext_sr + fisc_ext_lr - ((env_cost_wtp_g / (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))) * (${USShareFutureSSC} * ${USShareGovtFutureSCC}))
	gen mvpf_no_lbd = wtp_no_lbd / cost_no_lbd

	gen gov_carbon_no_lbd = (wtp_glob + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))
	gen gov_carbon_yes_lbd = (wtp_glob + wtp_r_glob + env_cost_wtp_g) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC})))

	gen gov_ce_no_lbd = cost_no_lbd / gov_carbon_no_lbd
	gen gov_ce_yes_lbd = cost_yes_lbd / gov_carbon_yes_lbd

	list program fisc_ext_sr fisc_ext_lr program_cost transfer producers cost_wtp wtp_loc wtp_r_loc env_cost_wtp_l wtp_glob env_cost_wtp_g wtp_r_glob if group_label == "Hybrid Vehicles"

	gen net_social_ce_yes_lbd = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc - env_cost_wtp_l) / ///
							   ((wtp_glob + env_cost_wtp_g + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
	gen net_social_ce_no_lbd = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - wtp_loc - wtp_r_loc) / ((wtp_glob + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))

	gen net_social_cost_yes_lbd = fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc - env_cost_wtp_l
	gen net_social_cost_yes_lbd_dwl = fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc - env_cost_wtp_l + 0.3 * cost_yes_lbd

	g net_social_ce_yes_lbd_dwl1 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.1 * cost_yes_lbd) / ///
						 ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
	g net_social_ce_yes_lbd_dwl3 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.3 * cost_yes_lbd) / ///
						 ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))
	g net_social_ce_yes_lbd_dwl5 = (fisc_ext_sr + fisc_ext_lr + program_cost - transfer - producers - cost_wtp - wtp_loc - wtp_r_loc + 0.5 * cost_yes_lbd) / ///
						 ((wtp_glob + env_cost_wtp + wtp_r_glob) / (193 * (1 - (${USShareFutureSSC} * ${USShareGovtFutureSCC}))))

	list program net_social_ce_yes_lbd net_social_ce_no_lbd if group_label == "Hybrid Vehicles"


	assert round(mvpf_no_lbd, 0.00001) == round(mvpf_yes_lbd, 0.00001) if inlist(group_label_code, "rebates", "Home Energy Reports", "Other Nudges", "OtherTax", "veh_ret", "Weatherization")
	list if mvpf_no_lbd >= mvpf_yes_lbd & inlist(group_label_code, "ElectricVehicles", "HybridVehicles", "SolarEnergy", "WindEnergy")
	assert mvpf_no_lbd < mvpf_yes_lbd if inlist(group_label_code, "ElectricVehicles", "HybridVehicles", "SolarEnergy", "WindEnergy")
	assert mvpf_no_lbd > mvpf_yes_lbd if group_label_code == "GasTax"

	gen n = _N
	sum n
	local N = `r(mean)'

	replace across_group_ordering = 11 if group_label == "Gasoline Taxes"
	replace across_group_ordering = 13 if group_label == "Other Revenue Raisers"
	
	sort across_group_ordering


	levelsof group_label_code, local(groups)
	
	* Saving averages for use in other tables
	foreach group of local groups{

		sum mvpf_yes_lbd if group_label_code == "`group'"
		local mvpf_yes_lbd_`group' = `r(mean)'

		sum mvpf_no_lbd if group_label_code == "`group'"
		local mvpf_no_lbd_`group' = `r(mean)'

		sum resource_ce_yes_lbd if group_label_code == "`group'"
		local resource_ce_yes_lbd_`group' = `r(mean)'
		
		sum resource_ce_no_lbd if group_label_code == "`group'"
		local resource_ce_no_lbd_`group' = `r(mean)'
		
		sum gov_ce_yes_lbd if group_label_code == "`group'"
		local gov_ce_yes_lbd_`group' = `r(mean)'
		
		sum gov_ce_no_lbd if group_label_code == "`group'"
		local gov_ce_no_lbd_`group' = `r(mean)'
		
		sum net_social_ce_yes_lbd if group_label_code == "`group'"
		local net_social_ce_yes_lbd_`group' = `r(mean)'
		
		sum net_social_ce_no_lbd if group_label_code == "`group'"
		local net_social_ce_no_lbd_`group' = `r(mean)'

		sum net_social_ce_yes_lbd_dwl1 if group_label_code == "`group'"
		local net_social_ce_yes_lbd_dwl1_`group' = `r(mean)'

		sum net_social_ce_yes_lbd_dwl3 if group_label_code == "`group'"
		local net_social_ce_yes_lbd_dwl3_`group' = `r(mean)'

		sum net_social_ce_yes_lbd_dwl5 if group_label_code == "`group'"
		local net_social_ce_yes_lbd_dwl5_`group' = `r(mean)'
	}
restore

* Adding in the category averages to the full dataset

replace in_group_ordering = table_order - 51 if group_label == "Gasoline Taxes"
replace in_group_ordering = table_order - 75 if group_label == "Other Revenue Raisers"
replace in_group_ordering = table_order - 69 if group_label == "Other Fuel Taxes"


expand 2 if in_group_ordering == 1, gen(dup)
sort group_label in_group_ordering
replace program_label_short = group_label if in_group_ordering == 1 & dup == 1

foreach group of local groups{
	
	replace mvpf = `mvpf_yes_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace MVPF_no_lbd = `mvpf_no_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace resource_ce_yes_lbd = `resource_ce_yes_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace resource_ce_no_lbd = `resource_ce_no_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace gov_ce_yes_lbd = `gov_ce_yes_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace gov_ce_no_lbd = `gov_ce_no_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace net_social_ce_yes_lbd = `net_social_ce_yes_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace net_social_ce_no_lbd = `net_social_ce_no_lbd_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1

	replace net_social_ce_yes_lbd_dwl1 = `net_social_ce_yes_lbd_dwl1_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
	replace net_social_ce_yes_lbd_dwl3 = `net_social_ce_yes_lbd_dwl3_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1

	replace net_social_ce_yes_lbd_dwl5 = `net_social_ce_yes_lbd_dwl5_`group'' if group_label_code == "`group'" & in_group_ordering == 1 & dup == 1
	
}

replace in_group_ordering = 0 if dup == 1

cap drop n
cap drop blank
gen n = _N
sum n
local N = `r(mean)'

label define groups 1 "Wind Production Credits" 2 "Residential Solar" 3 "Electric Vehicles" 4 "Appliance Rebates" 5 "Vehicle Retirement" 6 "Hybrid Vehicles" 7 "Weatherization" 8 "Home Energy Reports" 9 "Gasoline Taxes" 10 "Other Fuel Taxes" 11 "Other Revenue Raisers"
encode group_label, gen(groups)
sort groups in_group_ordering


drop if extended == 1

gen blank = .

local ces mvpf resource_ce_no_lbd resource_ce_yes_lbd gov_ce_no_lbd gov_ce_yes_lbd net_social_ce_no_lbd net_social_ce_yes_lbd
order in_group_ordering dup group_label, after(program)


if "`lbd'" == "yes"{
	save "`output_path'/table_3_data_with_lbd", replace
}

else if "`lbd'" == "no"{
	save "`output_path'/table_3_data_no_lbd", replace
}













