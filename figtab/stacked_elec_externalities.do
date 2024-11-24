*******************************************************************************
*Stacked area chart showing breakdown of environmental externality over time
*******************************************************************************
local output_path "${output_fig}/figures_appendix"

qui do "${github}/ado/stacked_graph_grid.ado" 

local starting_year = 2005
local lifetime = 30
local ending_year = `starting_year' + `lifetime'
local emissions = "marginal"
local model = "mid"

tempname grid_by_year
postfile `grid_by_year' year break1 break2 break3 total_connected using "grid_by_year_v2.dta", replace

	forvalues y = `starting_year'(1)`ending_year'{
		stacked_graph 1, starting_year(`y') ext_year(`y') discount_rate(0.02) ef("`emissions'") type("uniform") geo("US") grid_specify("yes") model("`model'")
		if `y' <= 2020 {
			post `grid_by_year' (`y') (0) (`r(local_enviro_ext)' * ${cpi_2020}/${cpi_`y'}) ((`r(local_enviro_ext)' + `r(global_enviro_ext)') * ${cpi_2020}/${cpi_`y'}) ((`r(local_enviro_ext)' + `r(global_enviro_ext)') * ${cpi_2020}/${cpi_`y'})
		}
		
		if `y' > 2020 {
			post `grid_by_year' (`y') (0) (`r(local_enviro_ext)') (`r(local_enviro_ext)' + `r(global_enviro_ext)') (`r(local_enviro_ext)' + `r(global_enviro_ext)')
		}
		
		if `y' == `starting_year' {
			local y_max = (`r(local_enviro_ext)' + `r(global_enviro_ext)')*1.1
		}
	}
postclose `grid_by_year'
use grid_by_year_v2, clear
di in red `y_max'


tw (rarea break1 break2 year, color("115 175 235")) ///
   (rarea break2 break3 year, color("214 118 72")) ///
   (line total_connected year if year <= 2022, color("21 26 33") msize(tiny) lwidth(medium)) ///
   (line total_connected year if year > 2022, color("21 26 33") msize(tiny) lwidth(medium) lp(dash)), ///
   ytitle("Externality Value ($/KWh)", size(medsmall)) ///
   ylab(0(.05).25, nogrid format(%9.2f)) ///
   yscale(titlegap(+1) outergap(0)) ///
   xtitle("Year", size(medsmall)) ///
   xlab(`starting_year'(5)`ending_year') ///
   xscale(titlegap(+4) outergap(0)) ///
   xsize(6) ///
   plotregion(margin(b=0 l=0)) ///
   graphregion(color(white)) ///
   legend(off)
graph display, xsize(6) ysize(4)

graph export "`output_path'/Ap_Fig_2b_stacked_area.png", replace