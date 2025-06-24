
local output_path "${output_figtab}/figures_appendix"

import excel "${assumptions}/grid_pollution", first clear sheet("elec_share_2020") // Electricity Mix in the US in 2020

foreach var in "Coal" "Oil"	"Gas" "Nuclear"	"Hydro"	"Biomass" "Wind" "Solar" "Geothermal" "OtherFossil"	"OtherUnknown" {
	local `var'_share = `var'[1]
}

*Get weighted average supply * demand elas from MarketSim Model (https://www.boem.gov/sites/default/files/documents//MarketSim%20Model%20Documentation.pdf)

local nodata = `Geothermal_share' + `Biomass_share' + `OtherFossil_share' + `OtherUnknown_share' // Do not have elasticities for these sources

local elec_supply_ms = (0.22 * `Oil_share' + 1.50 * `Gas_share' + 0.27 * `Coal_share' + 0.53 * `Nuclear' + 0.05 * `Hydro_share' + 0.65 * `Wind_share' + 2.03 * `Solar_share') * (1/(1 - `nodata'))

local elec_supply_estimates = (0.22 * `Oil_share' + 1.50 * `Gas_share' + 0.27 * `Coal_share' + 0.53 * `Nuclear' + 0.05 * `Hydro_share' + 0.65 * `Wind_share' + 2.03 * `Solar_share') * (1/(1 - `nodata'))

local elec_demand_ms = (0.384 * 0.287) + (0.354 * 0.134) + (0.260 * 0.125) // demand shares from https://www.eia.gov/energyexplained/electricity/use-of-electricity.php

local elec_demand_tatyana = 0.27 // https://www.aeaweb.org/articles?id=10.1257/app.20180256

local elec_demand_eia = (((0.13 + 0.22 + 0.26)/3) * (0.384/(0.384+0.354))) + (((0.08 + 0.13 + 0.15)/3) * (0.354/(0.384+0.354))) //https://www.eia.gov/analysis/studies/buildings/energyuse/pdf/price_elasticities.pdf

import delimited "${output_fig}/figures_data/contour_test.csv", varnames(1) clear

gen Rebound = 1 - (1/(1 - ((demand * -1)/supply)))

twoway (contour Rebound demand supply, ccolors("8 51 97*0.2" "8 51 97*0.4" "36 114 237*0.4" "115 175 235*0.8" "36 114 237*0.6" "36 114 237*0.8" "36 114 237" "8 51 97*0.9" "8 51 97") ylabel( , nogrid) ccuts(0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8) xline(`elec_supply_ms', lc(black)) yline(`elec_demand_eia' `elec_demand_ms' `elec_demand_tatyana', lc(black)) xtitle("Supply Elasticity") ytitle("Demand Elasticity")) 

graph export "`output_path'/Ap_Fig8_rebound.png", replace
cap graph export "`output_path'/Ap_Fig8_rebound.wmf", replace