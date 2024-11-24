


if ("`c(username)'" == "sarahaa") { // Sarah
    global user = "C:/Users/sarahaa"
    global dropbox = "${user}/Dropbox (MIT)/Regulation"
    global github = "${user}/Documents/GitHub/mvpf-enviro"
}

if ("`c(username)'" == "sarah") { // Sarah's personal computer
	global user = "/Users/sarah"
	global dropbox = "${user}/Dropbox (MIT)/Regulation"
	global github = "${user}/Documents/GitHub/mvpf-enviro"
}

import excel "${code_files}/1_assumptions/evs/pop_by_state_2010_2019.xlsx", clear

ren D pop2010
ren E pop2011
ren F pop2012
ren G pop2013
ren H pop2014
ren I pop2015
ren J pop2016
ren K pop2017
ren L pop2018
ren M pop2019

drop if strpos(A,"table")
drop if strpos(A,"Annual")
drop if strpos(A,"Geographic")
drop if strpos(A,"United")
drop if strpos(A,"Northeast")
drop if strpos(A,"Midwest")
drop if A == "South"
drop if A == "West"
drop if missing(A)

ren A state
drop B C

replace state = substr(state,2,.)

drop if strpos(state, "Rico")
drop if strpos(state, "Citation")
drop if strpos(state, "Census")
drop if strpos(state, "Date")

destring pop2010, replace

save "${code_files}/1_assumptions/evs/processed/pop_by_state_2010_2019", replace

import excel "${code_files}/1_assumptions/evs/pop_by_state_2000_2009.xls", clear
drop if _n == 1
drop if strpos(A, "Intercensal")
drop if strpos(A, "Geographic")
drop if A == "Puerto Rico"
drop if strpos(A, "Question")
drop if strpos(A, "data")
drop if strpos(A, "applying")
drop if strpos(A, "Suggested")
drop if strpos(A, "Population")
drop if strpos(A, "Release")
drop if missing(A)
drop if strpos(A,"United")
drop if strpos(A,"Northeast")
drop if strpos(A,"Midwest")
drop if A == "South"
drop if A == "West"

ren A state
drop B

replace state = substr(state,2,.)

drop M N

ren C pop2000
ren D pop2001
ren E pop2002
ren F pop2003
ren G pop2004
ren H pop2005
ren I pop2006
ren J pop2007
ren K pop2008
ren L pop2009

destring pop2000, replace

save "${code_files}/1_assumptions/evs/processed/pop_by_state_2000_2009", replace

merge 1:1 state using "${code_files}/1_assumptions/evs/processed/pop_by_state_2010_2019"
drop _merge

save "${code_files}/1_assumptions/evs/processed/pop_by_state_2000_2019", replace


