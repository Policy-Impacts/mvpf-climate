	
local output_path "${output_fig}/figures_appendix"

drop _all

local state_list AL AZ AR CA CO CT DE FL GA ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY

local discount = ${discount_rate}

foreach s of local state_list {
	
	qui dynamic_grid 1000, starting_year(${today_year}) lifetime(1) discount_rate(`discount') ef("${replacement}") type("uniform") ///
		geo("`s'") grid_specify("yes") model("${grid_model}")
		
	local `s'_global = `r(global_enviro_ext)' 
	local `s'_local = `r(local_enviro_ext)'
	local `s'_carbon = `r(carbon_content)'	
	
}

gen state = ""
gen global_damages = .
gen local_damages = .
gen carbon_damages = .

foreach s of local state_list {
	insobs 1
	replace state = "`s'" if state == ""
		
	qui ds *_damages
	foreach var in `r(varlist)' {
		local name_ind = substr("`var'", 1, strlen("`var'") - 8)
		
		qui replace `var' = ``s'_`name_ind'' if state == "`s'"
	}	
}

gen environment_ext = global_damages + local_damages
gen region = 1
gen cutpoints = 1
replace cutpoints = 2 if environment_ext > 100
replace cutpoints = 3 if environment_ext > 140
replace cutpoints = 4 if environment_ext > 160
replace cutpoints = 5 if environment_ext > 190 

maptile environment_ext, ///
		geography(state) ///
		fc(OrRd) ///
		mapif(region == 1) ///
		cutvalues(100 140 160 190) ///
		twopt(legend(order(6 "190 - 200" 5 "160 - 190" 4 "140 - 160" 3 "100 - 140" 2 "90 - 100") size(9pt) title("Externality ($/MWh)", size(small) margin(small))))
graph export "`output_path'/Ap_Fig_2_map.png", replace
cap graph export "`output_path'/Ap_Fig_2_map.wmf", replace


