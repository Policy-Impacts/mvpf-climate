*********************************************
*Natural Gas and Electricity Externalities
*********************************************

*****************************************************
*Import Social Cost of Pollutants (per pound)
*****************************************************

**Local Externalities**
local tons_per_lb = 0.000453592 
foreach p in "PM25" "NOx" "SO2" "VOC" "NH3" {
 	forvalues y = 2000(1)2022 {
		
		local social_cost_`p'_`y' = ${md_`p'_`y'_unweighted} * `tons_per_lb' * (${cpi_`y'}/${cpi_${md_dollar_year}})
		
	}
}

**Global Externalities** 
forvalues y = 2000(1)2022{
	foreach p in "CO2" "CH4" "N2O" {
		local social_cost_`p'_`y' = ${sc_`p'_`y'} * `tons_per_lb' * (${cpi_`y'}/${cpi_${sc_dollar_year}})
		global social_cost_`p'_`y' = ${sc_`p'_`y'}	* `tons_per_lb' * (${cpi_`y'}/${cpi_${sc_dollar_year}})
	}
}
global last_run_scc_save = round((`social_cost_CO2_2020'/`tons_per_lb'), 1) // XX Used in macros.do to determine whether to re-run.
global last_run_md_save = round((`social_cost_NOx_2020'/`tons_per_lb'), 1)

*****************************************************
*Calculating Externality for the Average kWh
*****************************************************

import excel "${assumptions}/grid_pollution", first clear sheet("average_rates")
drop if Year < 2005 // Do not have data for earlier years
foreach var of varlist ef*{
	replace `var' = `var'/1000 // Converting from lbs per MWh to lbs per KWh
}
levelsof State, local(State)
forvalues y = 2005(1)2021 {
	foreach s in `State' {
		foreach p in NOx SO2 CH4 N2O CO2{
			if `y' == 2006 | `y' == 2008 | `y' == 2011 | `y' == 2013 | `y' == 2015 | `y' == 2017 { 
			// Years we don't have data for (taking average of years before & after)
				qui sum ef_`p' if State == "`s'" & (Year == `y' + 1 | Year == `y' - 1)
				local ef_`p'_mean = r(mean)
			}
			
			// Years we do have data for
			if `y' != 2006 & `y' != 2008 & `y' != 2011 & `y' != 2013 & `y' != 2015 & `y' != 2017 { 
				qui sum ef_`p' if State == "`s'" & Year == `y'
				local ef_`p'_mean = r(mean)
			}
			
			di "`y', `s', `p'"
			global sc_`p'_`s'_`y' = `ef_`p'_mean' * `social_cost_`p'_`y''
		}
		
***Creating the Main Globals***		
		global local_kwh_`s'_`y' = `ef_NOx_mean' * `social_cost_NOx_`y'' + `ef_SO2_mean' * `social_cost_SO2_`y''
		
		global global_kwh_`s'_`y' = `ef_CO2_mean' * `social_cost_CO2_`y'' + `ef_N2O_mean' * `social_cost_N2O_`y'' + `ef_CH4_mean' * `social_cost_CH4_`y''
		
		global sc_kwh_carbon_`s'_`y' = `ef_CO2_mean' * `social_cost_CO2_`y'' // social cost of carbon of one kWh of electricity
		
		global carbon_kwh_`s'_`y' = `ef_CO2_mean'
		
		if `y' == 2020 {
			global carbon_avg_`s'_2020 = (`ef_CO2_mean' * `social_cost_CO2_`y'')/(${global_kwh_`s'_2020}) // % of global emissions made up of CO2
		}
				
	}
		
}

***********************************************
*Calculating Externality for the Marginal kWh
***********************************************

import excel "${assumptions}/grid_pollution", first clear sheet("state_crosswalk")
levelsof State, local(State)
foreach s in `State' {
	preserve
	qui keep if State == "`s'"
	local `s'_1 = Region1[1]
	local `s'_2 = Region2[1]
	restore
}

forvalues y = 2007(1)2018 {
	
	import excel "${assumptions}/grid_pollution", first clear sheet("marginal_rates")
	qui keep if Year == `y'
	gen wind_sc = .
	gen solar_sc = .
	gen portfolio_sc = .
	gen uniform_sc = .
	
	foreach s in `State' {
		preserve
		qui keep if Region == "``s'_1'"
		foreach var in "wind" "solar" "portfolio" "uniform" {
			replace `var'_sc = (`var'/1000) * `social_cost_CO2_`y'' if pollutant == "CO2"
			replace `var'_sc = (`var'/1000) * `social_cost_NOx_`y'' if pollutant == "NOx"
			replace `var'_sc = (`var'/1000) * `social_cost_SO2_`y'' if pollutant == "SO2"
			replace `var'_sc = (`var'/1000) * `social_cost_PM25_`y'' if pollutant == "PM25"
			
			qui sum `var'_sc if pollutant == "CO2"
			global global_`var'_`s'_`y' = (`r(sum)') * (1/${carbon_avg_US_2020}) // scaling global externalities 
			
			qui sum `var'_sc if pollutant != "CO2"
			global local_`var'_`s'_`y' = `r(sum)'
		}
		restore
		
	}
}

// For 2019 onwards, we use the second set of the region to state crosswalk
forvalues y = 2019(1)2021 {
	
	import excel "${assumptions}/grid_pollution", first clear sheet("marginal_rates")
	qui keep if Year == `y'
	gen wind_sc = .
	gen solar_sc = .
	gen portfolio_sc = .
	gen uniform_sc = .
	
	foreach s in `State' {
		preserve
		qui keep if Region == "``s'_2'"
		foreach var in "wind" "solar" "portfolio" "uniform" {
			replace `var'_sc = (`var'/1000) * `social_cost_CO2_`y'' if pollutant == "CO2"
			replace `var'_sc = (`var'/1000) * `social_cost_NOx_`y'' if pollutant == "NOx"
			replace `var'_sc = (`var'/1000) * `social_cost_SO2_`y'' if pollutant == "SO2"
			replace `var'_sc = (`var'/1000) * `social_cost_PM25_`y'' if pollutant == "PM25"
			
			qui sum `var'_sc if pollutant == "CO2"
			global global_`var'_`s'_`y' = `r(sum)' * (1/${carbon_avg_US_2020})
			
			qui sum `var'_sc if pollutant != "CO2"
			global local_`var'_`s'_`y' = `r(sum)'
			
			if `y' == 2020 {
				global carbon_`var'_`s'_2020 = ${global_`var'_`s'_2020} * ${carbon_avg_US_2020} // for marginal emissions, CO2 represents 100% of the global emissions
				}
		}
		restore
		
	}
}

*Since we only have data from 2007 onwards, the 2004-2006 data will be equal to the 2007 values
forvalues y = 2004(1)2006 {
	
	import excel "${assumptions}/grid_pollution", first clear sheet("marginal_rates")
	qui keep if Year == 2007
	gen wind_sc = .
	gen solar_sc = .
	gen portfolio_sc = .
	gen uniform_sc = .
	
	foreach s in `State' {
		preserve
		qui keep if Region == "``s'_1'"
		foreach var in "wind" "solar" "portfolio" "uniform" {
			replace `var'_sc = (`var'/1000) * `social_cost_CO2_`y'' if pollutant == "CO2"
			replace `var'_sc = (`var'/1000) * `social_cost_NOx_`y'' if pollutant == "NOx"
			replace `var'_sc = (`var'/1000) * `social_cost_SO2_`y'' if pollutant == "SO2"
			replace `var'_sc = (`var'/1000) * `social_cost_PM25_`y'' if pollutant == "PM25"
			
			qui sum `var'_sc if pollutant == "CO2"
			global global_`var'_`s'_`y' = `r(sum)' * (1/${carbon_avg_US_2020})
			
			qui sum `var'_sc if pollutant != "CO2"
			global local_`var'_`s'_`y' = `r(sum)'
		}
		restore
		
	}
}


*Approximate grid in the EU
*Average US CO2e emissions in 2020 (eGRID): 822.61 lb/MWh
*Average EU CO2e emissions in 2020 (EEA): 227 g/kWh

local EU_to_US = 227 / ((822.61 * 453.592)/1000)

forvalues y = 2004(1)2021 {
	foreach var in "wind" "solar" "portfolio" "uniform" {
		global global_`var'_EU_`y' = ${global_`var'_US_`y'} * `EU_to_US'
		global local_`var'_EU_`y' =  ${local_`var'_US_`y'} * `EU_to_US'
	}
}

*Create clean grid (zero) emissions

forvalues y = 2004(1)2021 {
	foreach var in "wind" "solar" "portfolio" "uniform" {
		global global_`var'_clean_`y' = 0
		global local_`var'_clean_`y' =  0
	}
}


**********************************************************************
*Get Cleanest and Dirtiest Regions (Using Marginal Rates)
**********************************************************************
import excel "${assumptions}/grid_pollution", first clear sheet("average_rates")
levelsof State, local(State)
forvalues y = 2005(1)2020 {
	local temp_max = 0
	local temp_min = 100
	foreach s in `State'{
		if "`s'" == "AK" | "`s'" == "HI" | "`s'" == "PR" | "`s'" == "DC" {
			continue
		}
		
		local environment = ${local_uniform_`s'_`y'} + ${global_uniform_`s'_`y'}
		if `environment' > `temp_max'{
			local temp_max = `environment'
			local state_dirty_`y' = "`s'"
		}

		if `environment' < `temp_min' {
			local temp_min = `environment'
			local state_clean_`y' = "`s'"
		}

	}
	di "`y', Clean: `state_clean_`y''"
	di "`y', Dirty:`state_dirty_`y''"
}

forvalues y = 2005(1)2020 {
	foreach val in "LOW" "HIGH"{
		if "`val'" == "LOW"{
			global local_kwh_`val'_`y' = ${local_uniform_`state_clean_`y''_`y'}
			global global_kwh_`val'_`y' = ${global_uniform_`state_clean_`y''_`y'}
			global sc_kwh_carbon_`val'_`y' = ${sc_kwh_carbon_`state_clean_`y''_`y'}
			global state_clean_`y'  = "`state_clean_`y''"
		}
		if "`val'" == "HIGH"{
			global local_kwh_`val'_`y' = ${local_uniform_`state_dirty_`y''_`y'}
			global global_kwh_`val'_`y' = ${global_uniform_`state_dirty_`y''_`y'}
			global sc_kwh_carbon_`val'_`y' = ${sc_kwh_carbon_`state_dirty_`y''_`y'}
			global state_dirty_`y' = "`state_dirty_`y''"
		}
	}
}

********************************
*Import Social Cost per MMBTU
********************************
preserve

	import excel "${policy_assumptions}", first clear sheet("ng_pollutants")
	drop if year == .
	forvalues y = 2000(1)2022 {
		local data_year = `y'
		if `y' < 2011{
			local data_year = 2011 // Holding pre-2011 fixed at 2011 levels.
		}
		foreach p in CH4 N2O CO2 {
			qui sum `p'_lbs_mmbtu if year == `data_year'
			local ng_`p'_mean = r(mean)
			global mmbtu_`p'_`y' = `ng_`p'_mean' * ${social_cost_`p'_`y'}
		}
		
		global lbs_carbon_mmbtu_`y' = `ng_CO2_mean'
		global global_mmbtu_`y' = ${mmbtu_CH4_`y'} + ${mmbtu_N2O_`y'} + ${mmbtu_CO2_`y'}
		global carbon_mmbtu_`y' = ${mmbtu_CO2_`y'}
	}
	
restore

********************************
*Import Electricity Prices
********************************
import excel "${policy_assumptions}", first clear sheet("kwh_price_state")
	local obs = _N
	forvalues i = 1/`obs'{
		local yr : word 1 of year[`i']
		local year = `yr'
		local st : word 1 of stateid[`i']
		local state = `st'
		qui sum price if year == year[`i'] & stateid == stateid[`i']
		global kwh_price_`year'_`state' = `r(mean)'
	}	

***********************
*Electricity Markups
***********************
*Get tax rate and percent public
import excel "${policy_assumptions}", first clear sheet("electricity_markups")
levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		local `val' = `r(mean)'
	}
	
*Get Levelized Cost of Electricity
import excel "${policy_assumptions}", first clear sheet("lcoe_2020_new")
drop if Source == "Wind_offshore"
replace Source = "Wind" if Source == "Wind_onshore"
levelsof Source, local(levels)
foreach val of local levels {
	qui sum dollar_year if Source == "`val'"
	foreach var in "Average" "Minimum" "Maximum" {
		replace `var' = `var' * (${cpi_2020}/${cpi_`r(mean)'}) if Source == "`val'"
	}
}

*Save the wind average LCOE
qui sum Average if Source == "Wind"
global wind_lcoe = `r(mean)' / 1000

*Save the solar average LCOE
qui sum Average if Source == "Solar"
global solar_lcoe = `r(mean)' / 1000

*Save the natural gas average LCOE
qui sum Average if Source == "Natural_Gas"
global ng_lcoe = `r(mean)' / 1000

levelsof Source, local(levels)
foreach val of local levels {
	qui sum Average if Source == "`val'"
	local `val'_lcoe = `r(mean)'
	
	qui sum Minimum if Source == "`val'"
	local `val'_lcoe_min = `r(mean)'
	
	qui sum Maximum if Source == "`val'"
	local `val'_lcoe_max = `r(mean)'
	
	local `val'_diff = ``val'_lcoe_max' - ``val'_lcoe_min'
	
	local `val'_diff1 = ``val'_lcoe' - ``val'_lcoe_min'
	local `val'_diff2 = ``val'_lcoe_max' - ``val'_lcoe'
}
	
*Get state wage ranks
import excel "${policy_assumptions}", first clear sheet("wages")
sort wage
gen rank = _n
tempfile state_ranks
save "`state_ranks.dta'", replace 

*Get Electricity Share by State
import excel "${policy_assumptions}", first clear sheet("electricity_share_2020")

gen other = Oil + Other_Fossil + Other_Unknown
drop Oil Other_Fossil Other_Unknown

rename Gas Natural_Gas

*Add in Ranks based on state wages
merge 1:1 State using "`state_ranks.dta'", nogen
qui sum rank
replace rank = `r(max)'/2 if State == "US"

foreach val of local levels {
		gen state_multiplier_`val' = (``val'_diff1'/24.5) * rank if rank < 25
		replace state_multiplier_`val' = (``val'_diff2'/24.5) * rank if rank >= 25
		gen lcoe_scaled_`val' = (``val'_lcoe_min' + state_multiplier_`val') * `val' if rank < 25 
		replace lcoe_scaled_`val' = (``val'_lcoe' + state_multiplier_`val') * `val' if rank >= 25
	}
	
*Generate weighted average LCOE by state in 2020
egen lcoe_mwh = rowtotal(lcoe_scaled*) 
replace lcoe_mwh = lcoe_mwh * (1 / (1 - other))
gen lcoe_kwh = (lcoe_mwh / 1000) // LCOE per kwh in 2020

*Save the US average LCOE
qui sum lcoe_kwh if State == "US"
global energy_cost = `r(mean)'
local avg_profits = 0.08 // https://academic.oup.com/qje/article/135/2/561/5714769


***Add the Distribution costs to the LCOE kwh costs
preserve
import excel "${policy_assumptions}", first clear sheet("transmission_distribution")
local index = 1

forvalues y = 2007(1)2022 {
	local `y'_d = Distribution[`index']
	local index = `index' + 1
}

restore

levelsof State, local(levels)
	foreach val of local levels {
		qui sum lcoe_kwh if State == "`val'"
		global cost_2020_`val'_2020 = (`r(mean)' + `2020_d') * (1 + `avg_profits')
		global cost_price_`val'_2020 = ${cost_2020_`val'_2020} / ${kwh_price_2020_`val'}

}

save "${assumptions}/electricity_pricing/electricty_markups.dta", replace

import excel "${policy_assumptions}", first clear sheet("kwh_price_state")
forvalues y = 2001(1)2022{
	levelsof stateid, local(state)
	foreach s of local levels{
		local cost = ${cost_price_`s'_2020} * ${kwh_price_`y'_`s'}
		global producer_surplus_`y'_`s' = (${kwh_price_`y'_`s'} - `cost') * (1 - `corporate_tax') * (1-`utility_public')
		
		global government_revenue_`y'_`s' = ((${kwh_price_`y'_`s'} - `cost') * (1-`utility_public') * `corporate_tax') + ((${kwh_price_`y'_`s'} - `cost') * `utility_public')		
		
		if ${producer_surplus_`y'_`s'} < 0 {
			global producer_surplus_`y'_`s' = 0
		}
		
		if ${government_revenue_`y'_`s'} < 0 {
			global government_revenue_`y'_`s' = 0
		}
	}
}

********************************
*Import Natural Gas Prices
********************************
	
import excel "${policy_assumptions}", first clear sheet("ng_price")
	levelsof year, local(years)
	foreach y in `years'{
		import excel "${policy_assumptions}", first clear sheet("ng_price")
		keep if year == `y'
		qui ds
		foreach assumption in `r(varlist)' {
			global ng_price_`y'_`assumption' = `assumption'[1] * 1.038 // Convert thousand cubic feet to mmbtu, conversion factor form EIA
		} 
	}
	
********************************
*Import Natural Markups
********************************
local avg_profits = 0.08 // https://academic.oup.com/qje/article/135/2/561/5714769

import excel "${policy_assumptions}", first clear sheet("WAP")
	levelsof Parameter, local(levels)
	foreach val of local levels {
		qui sum Estimate if Parameter == "`val'"
		local `val' = `r(mean)'
	}

import excel "${policy_assumptions}", first clear sheet("ng_citygate")
levelsof year, local(years)
foreach y in `years'{
	preserve
	keep if year == `y'
	qui ds
	foreach state in `r(varlist)' {
		global ng_mc_`y'_`state' = `state'[1] * 1.038 // Convert thousand cubic feet to mmbtu
		
		global ng_markup_`y'_`state' =  ((${ng_price_`y'_`state'} - ${ng_mc_`y'_`state'})/${ng_price_`y'_`state'}) - `avg_profits'
		
		global psurplus_mmbtu_`y'_`state' = (${ng_markup_`y'_`state'} * ${ng_price_`y'_`state'}) * (1 - `corporate_tax') * (1-`ng_public')
		
		global govrev_mmbtu_`y'_`state' = (${ng_markup_`y'_`state'} * ${ng_price_`y'_`state'}) * (1-`ng_public') * `corporate_tax' + ((${ng_markup_`y'_`state'} * ${ng_price_`y'_`state'}) * `ng_public') 
	}
	restore
	
}

*Using 2021 values for 2020 because 2020 is an outlier
*Can't use 2022 values because we don't have them for every state
foreach state in `r(varlist)' {
	global ng_mc_2020_`state' = ${ng_mc_2021_`state'} * (${cpi_2020}/${cpi_2021}) // Convert thousand cubic feet to mmbtu
	
	global ng_price_2020_`state' = ${ng_price_2021_`state'} * (${cpi_2020}/${cpi_2021})
			
	global ng_markup_2020_`state' =  ((${ng_price_2020_`state'} - ${ng_mc_2020_`state'})/${ng_price_2020_`state'}) - `avg_profits'
			
	global psurplus_mmbtu_2020_`state' = ((${ng_markup_2020_`state'} * ${ng_price_2020_`state'}) * (1 - `corporate_tax') * (1-`ng_public')) 
			
	global govrev_mmbtu_2020_`state' = ((${ng_markup_2020_`state'} * ${ng_price_2020_`state'}) * (1-`ng_public') * `corporate_tax') +  ((${ng_markup_2020_`state'} * ${ng_price_2020_`state'}) * `ng_public')
}


********************************
*Market Share
********************************
global US_solarshare = 0.15 // In 2022, the US was responsible for 15% of solar generation growth - https://www.iea.org/energy-system/renewables/solar-pv
global US_windshare = 0.22 // In 2022, the US was responsible for 22% of wind generation growth - https://www.iea.org/energy-system/renewables/wind
global federal_subsidy = 0.26 // Solar ITC in 2020

global harmonized_2010 = "no"
global solar_markups = "no"

*Solar pass-through
global solar_passthrough = (0.778 + (1-0.156))/2 // Taking an average of Pless & CT Solar