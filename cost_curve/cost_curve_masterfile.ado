
cap program drop cost_curve_masterfile

program define cost_curve_masterfile   , rclass
version 17

syntax [anything],   demand_elas(real) discount_rate(real)  farmer(real)  curr_prod(real)  cum_prod(real) price(real)   enviro(string) [fcr(real 0)  tmax(real 10000) markup(real 0) passthrough(real -1) subsidy_max(real 0) subsidy_end(real 0) graph graphfit replace nopresubsidy start_year(real 2020) scc(real 0) new_car(real 0) time_path_age(real 17) vmt(real 0.61544408) ev_grid(string) ]  
if "`anything'"=="" local anything NA

local randid = runiformint(0,100000)
local filename `: di %tcCCYYNNDD!THHMMSSSS clock("`c(current_date)'`c(current_time)'", "DMYhms")'
local filename = "`filename'" + "_"  + "`randid'"


if `fcr'==0 & `demand_elas'*`farmer'>1 di as error "Epsilon*theta is greater than 1. Implied solution is in the complex plane"
if `demand_elas'>0 di as error "Demand elasticity is positive" 
if `demand_elas'>0 e 

if `farmer'>0 di as error "Learning by doing elasticity is positive"
if `curr_prod'>`cum_prod' di as error "Current production exceeds cumulative production. Check if inputs are flipped"
preserve
    qui {
        if strpos("`enviro'","constant")>0  {
            local enviro_ext = subinstr("`enviro'","constant_","",.)
            local enviro_cons_early = `enviro_ext' 
            local enviro_cons_late= `enviro_ext'
            local enviro_slope_early= 0
            local enviro_slope_late = 0
            local enviro_extra = 0 
            local enviro_end = 0 
            local enviro_cap = 0 
            local baseyear 2010
            local cut_year 0 
        } 
        else if strpos("`enviro'","ev")>0 {
			
            if "`ev_grid'" == "" {
                local ev_grid = "US"
            }
            local type = subinstr("`enviro'","ev_","",.)
            
			if `vmt' == 1 {
				local vmt_ind = `vmt'
			}
			
			else {
				local vmt_ind = round(`vmt', 3)
			}
			
            
			if "${renewables_loop}" != "yes" {
				use "${assumptions}/timepaths/ev_externalities_time_path_scc`scc'_age`time_path_age'_vmt`vmt_ind'_grid`ev_grid'.dta", clear 
			}
			
			if "${renewables_loop}" == "yes" {
				use "${assumptions}/timepaths/ev_externalities_time_path_scc`scc'_age`time_path_age'_vmt`vmt_ind'_grid`ev_grid'_${renewables_percent}.dta", clear 
			}
			
            if `start_year' <2011 di as error "Start year cannot be before 2011"
            assert `start_year'>2010

            *ren *_new_* *_*
            replace year = year - 2010

            g year_log = log(year)

            g year_log_early = cond(year<10, year_log,0)
            g year_log_late = cond(year>=10, year_log,0)
            g early = cond(year<10, 1,0)
            g late = cond(year>=10,1,0)
            local target = log(10)
            constraint 1 early + year_log_early*`target'  = late + year_log_late*`target'
            if `new_car'==1 local vehicle_type  new
            else local vehicle_type  clean
            cnsreg benefits_`type'_`vehicle_type'_car_cf early late year_log_early year_log_late , constraint(1) nocons
            local enviro_cons_early = _b[early]
            local enviro_cons_late= _b[late]
            local enviro_slope_early= _b[year_log_early]
            local enviro_slope_late = _b[year_log_late]
            local enviro_extra = 0 
            local enviro_end = 0 
            local enviro_cap = 0 

            local baseyear 2010
            local cut_year 10


            if "`graphfit'"=="graphfit" {
                qui su year 
                local maxyear = r(max)
                tw (scatter benefits_`type'_`vehicle_type'_car_cf year) (function y = `enviro_cons_early'*(x<=`cut_year') + /// 
                `enviro_cons_late'*(x>`cut_year') + `enviro_slope_early'*log(x)*(x<=`cut_year') + `enviro_slope_late'*log(x)*(x>`cut_year')  , range( 1 `maxyear' )) 
                graph export "${output_fig}/time_paths/fit_`enviro'_`scc'_`time_path_age'_`start_year'.pdf", replace
            }
        }

        else if strpos("`enviro'","solar")>0| strpos("`enviro'","wind")>0 | strpos("`enviro'","solar_div10")>0 {
            local infile = subinstr("`enviro'","_div10","",.)
            local infile = subinstr("`infile'","_local","",.)
            local infile = subinstr("`infile'","_global","",.)
			
			*If it's clean grid, override to 0 after it runs
			if ("${change_grid}" == "" | "${change_grid}" == "clean") & "${renewables_loop}" != "yes" & "${solar_output_change}" != "yes" & "${wind_emissions_change}" != "yes" & "${lifetime_change}" != "yes" & "${no_cap_reduction}" != "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'.dta", clear 
			}
			
			if "${change_grid}" != "" & "${change_grid}" != "clean" & "${renewables_loop}" != "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_${change_grid}.dta", clear 
			}
			
			if "${renewables_loop}" == "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_${renewables_percent}.dta", clear 
			}
			
			if "${solar_output_change}" == "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_output${output_scalar}.dta", clear 
			}
			
			if "${wind_emissions_change}" == "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_emissions_change${emissions_scalar}.dta", clear 
			}
			
			if "${lifetime_change}" == "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_lifetime_change${lifetime_scalar}.dta", clear 
			}
			
			if "${no_cap_reduction}" == "yes" {
				use "${assumptions}/timepaths/`infile'_externalities_time_path_scc`scc'_age`time_path_age'_capacity_reduction0.dta", clear 
			}
			
            if strpos("`enviro'","div10") >0 replace enviro_ext = enviro_ext/10
            if strpos("`enviro'","div10") >0 replace local_ext = local_ext/10
            if strpos("`enviro'","div10") >0 replace global_ext = global_ext/10
            if strpos("`enviro'","local") >0 local type local 
            else if strpos("`enviro'","global") >0 local type global 
            else local type enviro 
            qui su year 
            local baseyear = r(min)- 1
            replace year = year - `baseyear' 
            tsset year 
            gen local_min = `type'_ext< l.`type'_ext & f.`type'_ext > `type'_ext & !mi(f.`type'_ext) & !mi(l.`type'_ext)
            count if local_min==1
            if r(N) == 1  {
                qui su `type'_ext 
                qui su year if `type'_ext == r(min)
                local cut_year = r(mean)
                qui su year 
                local enviro_end  = r(max) 
                qui su `type'_ext if year == `enviro_end'
                local enviro_cap = r(mean)
                assert r(N)==1


                g year_sq = year^2 
                g early = cond(year<=`cut_year',1,0)
                g late = cond(year>`cut_year',1,0)
                g year_early = cond(year<=`cut_year',year,0)
                g year_late = cond(year>`cut_year',year,0)
                g year_sq_early = cond(year<=`cut_year',year_sq,0)

                constraint 1 early + year_early*`cut_year' + year_sq_early*`=`cut_year'^2' = late + year_late*`cut_year'
                constraint 2 late + year_late*`enviro_end' = `enviro_cap'
                cnsreg `type'_ext early late year_early year_late year_sq_early , nocons constraints(1 2 )   



                local enviro_cons_early = _b[early]
                local enviro_cons_late= _b[late]
                local enviro_slope_early= _b[year_early]
                local enviro_slope_late = _b[year_late]
                local enviro_extra = _b[year_sq_early]
            } 

            else if r(N)==2 {
                su year if local_min
                local cut_year = `r(min)'
                qui su year 
                local enviro_end  = r(max) 
                qui su `type'_ext if year == `enviro_end'
                local enviro_cap = r(mean)
                assert r(N)==1


                g year_sq = year^2 
                g early = cond(year<=`cut_year',1,0)
                g late = cond(year>`cut_year',1,0)
                g year_early = cond(year<=`cut_year',year,0)
                g year_late = cond(year>`cut_year',year,0)
                g year_sq_early = cond(year<=`cut_year',year_sq,0)

                constraint 1 early + year_early*`cut_year' + year_sq_early*`=`cut_year'^2' = late + year_late*`cut_year'
                constraint 2 late + year_late*`enviro_end' = `enviro_cap'
                    
                cnsreg `type'_ext early late year_early year_late year_sq_early , nocons constraints(1 2 )   


                local enviro_cons_early = _b[early]
                local enviro_cons_late= _b[late]
                local enviro_slope_early= _b[year_early]
                local enviro_slope_late = _b[year_late]
                local enviro_extra = _b[year_sq_early]


            }
            else if r(N)==0 {
                local cut_year = 30 
                qui su year 
                local enviro_end  = r(max) 
                qui su `type'_ext if year == `enviro_end'
                local enviro_cap = r(mean)
                assert r(N)==1


                g year_sq = year^2 
                g early = cond(year<=`cut_year',1,0)
                g late = cond(year>`cut_year',1,0)
                g year_early = cond(year<=`cut_year',year,0)
                g year_late = cond(year>`cut_year',year,0)
                g year_sq_early = cond(year<=`cut_year',year_sq,0)

                constraint 1 early + year_early*`cut_year' + year_sq_early*`=`cut_year'^2' = late + year_late*`cut_year'
                constraint 2 late + year_late*`enviro_end' = `enviro_cap'
                cnsreg `type'_ext early late year_early year_late year_sq_early , nocons constraints(1 2 )   



                local enviro_cons_early = _b[early]
                local enviro_cons_late= _b[late]
                local enviro_slope_early= _b[year_early]
                local enviro_slope_late = _b[year_late]
                local enviro_extra = _b[year_sq_early]
            }
            else {
                di as error "Either monotonic or super non-monotonic. Talk to Jack"
                exit
            }

            if "`graphfit'"=="graphfit" {
                qui su year 
                local maxyear = r(max)
                tw (scatter `type'_ext year) (function y = `enviro_cons_early'*(x<=`cut_year') + `enviro_cons_late'*(x>`cut_year') /// 
                + `enviro_slope_early'*(x)*(x<=`cut_year') +  `enviro_slope_late'*(x)*(x>=`cut_year') + `enviro_extra'*(x^2)*(x<=`cut_year'), range( 1 `maxyear' )) 
                graph export "${output_fig}/time_paths/fit_`enviro'_`scc'_`time_path_age'_`start_year'.pdf", replace
            }
        }
        else {
            di as error "Option enviro incorrectly specified"
        }
    }
    assert `start_year' > `baseyear'
    qui cd "${github}/cost_curve"

    local start_year_offset = `start_year' - `baseyear' 
    local cum_prod = `cum_prod' - `curr_prod'
    if "`presubsidy'"=="" local price = `price'+`passthrough'*`subsidy_max'
    local graphcmd 0 
    cap if "`graph'"=="graph" local graphcmd 1 


    qui cd "${github}/cost_curve"

    if `subsidy_end'==0 & `fcr'==0 {
        if  "`c(os)'" == "MacOSX" {
            qui shell  /usr/local/bin/wolframscript -file  ./cost_curve_simple_mac.wls `price' `demand_elas' `farmer' `cum_prod' `discount_rate' `curr_prod'    `enviro_cons_early' `enviro_cons_late' `enviro_slope_early' `enviro_slope_late'  `enviro_extra' `enviro_end' `enviro_cap' `subsidy_max' `markup' `passthrough'  `graphcmd' `tmax' `start_year_offset'   `cut_year' `anything' f`filename'
        }
        else {
            qui shell  cost_curve_simple.wls `price' `demand_elas' `farmer' `cum_prod' `discount_rate' `curr_prod'    `enviro_cons_early' `enviro_cons_late' `enviro_slope_early' `enviro_slope_late'  `enviro_extra' `enviro_end' `enviro_cap' `subsidy_max' `markup' `passthrough'  `graphcmd' `tmax' `start_year_offset'   `cut_year' `anything' f`filename'
        }	 
    } 

    else {
        if "`c(os)'" == "MacOSX" {
            * the MacOS has an issue where the version of terminal that runs inside applications doesn't by default have the path to the wolframscript. If wolframscript  is located elsewhere in your desktop this might require a different prefix than /usr/local/bin. Type "which wolframscript" in Terminal to get its location.  Note also that you typically need to use chmod to change permissions to allow reading .wls files. 
            qui shell   /usr/local/bin/wolframscript -file  ./cost_curve_masterfile_mac.wls `price' `fcr' `demand_elas' `farmer' `cum_prod' `discount_rate' `curr_prod' `tmax' `enviro_cons_early' `enviro_cons_late' `enviro_slope_early' `enviro_slope_late'  `enviro_extra'  `enviro_end' `enviro_cap'   `subsidy_max'  `subsidy_end' `markup' `passthrough'  `graphcmd'  `start_year_offset' `cut_year' `anything'  f`filename' 
        }
        else {
            qui shell  cost_curve_masterfile.wls `price' `fcr' `demand_elas' `farmer' `cum_prod' `discount_rate' `curr_prod' `tmax' `enviro_cons_early' `enviro_cons_late' `enviro_slope_early' `enviro_slope_late'  `enviro_extra'  `enviro_end' `enviro_cap'   `subsidy_max'  `subsidy_end' `markup' `passthrough'  `graphcmd'  `start_year_offset' `cut_year' `anything'  f`filename' 
        }

    }
    sleep 10000
    qui import delimited using "f`filename'.csv", clear

    qui su v1 in 1 
    local dynamic_cost = r(mean)
    qui su v1 in 2 
    local dynamic_profit = r(mean)
    qui su v1 in 3 
    local dynamic_enviro = r(mean)
    if _N == 4 qui su v1 in 4
    if _N == 4 local dynamic_fe = r(mean)
	
	*Override emissions to 0 if grid is clean
// 	if "${change_grid}" == "clean" {
//		
// 		local dynamic_enviro = 0
//		
// 	}
	
    return local cost_mvpf `dynamic_cost'
    return local enviro_mvpf `dynamic_enviro'
    return local firm_mvpf `dynamic_profit'
    return local dynamic_fe `dynamic_fe'

    if "`replace'"==""  {
        rm f`filename'.csv
    }

restore

if "`replace'" == "replace"  {
    qui { 
        import delimited using "f`filename'.csv", clear
        rm f`filename'.csv
        rename v1 value 
        g component = "DP" in 1 
        replace component = "Dpi" in 2
        replace component = "DE" in 3 
        cap replace component = "DFE" in 4 
    }
}

end
