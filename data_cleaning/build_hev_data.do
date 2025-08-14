
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

import excel using "${code_files}/1_assumptions/evs/10301_hev_sale_2-28-20.xlsx", clear first

ren B sales1999
ren C sales2000
ren D sales2001
ren E sales2002
ren F sales2003
ren G sales2004
ren H sales2005
ren I sales2006
ren J sales2007
ren K sales2008
ren L sales2009
ren M sales2010
ren N sales2011
ren O sales2012
ren P sales2013
ren Q sales2014
ren R sales2015
ren S sales2016
ren T sales2017
ren U sales2018
ren V sales2019

forv i = 1999(1)2019{
	gen price`i' = .
	gen batt_cap`i' = .
	gen msrp`i' = .
	gen mpg`i' = .
}

replace batt_cap2000 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight" // https://electronhybridsolution.com/product/honda-insight-1999-2006-remanufactured-hybrid-battery-rebuild-kit/
replace batt_cap2001 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2002 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2003 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2004 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2005 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"
replace batt_cap2006 = 6.5 * 144 / 1000 if Vehicle == "Honda Insight"

replace batt_cap2001 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius" // https://ennocar.com/product/ni-mh-273-6v-6-5ah-prismatic-hybrid-car-battery-toyota-prius-gen1-2000-2001-2002-2003/
replace batt_cap2002 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2003 = 6.5 * 273.6 / 1000 if Vehicle == "Toyota Prius"
replace batt_cap2004 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius" // https://poweringautos.com/what-is-the-capacity-prius-car-battery/
replace batt_cap2005 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius" 
replace batt_cap2006 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Prius"

replace batt_cap2003 = 6.5 * 144 / 1000 if Vehicle == "Honda Civic" // https://ihybridbattery.com/product/honda-civic-g1-hybrid-battery-2003-2005/
replace batt_cap2004 = 6.5 * 144 / 1000 if Vehicle == "Honda Civic"
replace batt_cap2005 = 6 * 144 / 1000 if Vehicle == "Honda Civic" // https://hondanews.com/en-US/honda-automobiles/releases/release-e23d1cf6dc1ef9a37d3be9004c34c347-2005-honda-civic-hybrid-specifications
replace batt_cap2006 = 5.5 * 158 / 1000 if Vehicle == "Honda Civic" // https://hondanews.com/en-US/honda-automobiles/releases/release-591334b5ff2cd7fdfabb17004c34c1b5-2006-honda-civic-sedan-and-civic-hybrid-specifications

replace batt_cap2005 = 5.5 * 330 / 1000 if Vehicle == "Ford Escape/Mercury Mariner" // https://en.wikipedia.org/wiki/Ford_Escape#2004%E2%80%932006_(ZB)
replace batt_cap2006 = 5.5 * 330 / 1000 if Vehicle == "Ford Escape/Mercury Mariner"

replace batt_cap2005 = 6 * 144 / 1000 if Vehicle == "Honda Accord" // https://avt.inl.gov/sites/default/files/pdf/hev/batteryaccord1096.pdf
replace batt_cap2006 = 6 * 144 / 1000 if Vehicle == "Honda Accord"

replace batt_cap2006 = 6.5 * 288 / 1000 if Vehicle == "Toyota Highlander" // https://www.besthybridbatteries.com/products/toyota-highlander-2006-2007-hybrid-battery

replace batt_cap2006 = 6.5 * 288 / 1000 if Vehicle == "Lexus RX 450h" // http://www.ae.pwr.wroc.pl/filez/20110606092430_HEV_Toyota.pdf

preserve

* Importing Table 4 from Kelley Blue Book

	import excel using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.xlsx", ///
		clear sheet("Table 4") cellrange(A3) firstrow
	keep A G  // Keep vehicle names and 2020 sales
	rename A vehicle_raw
	rename G sales2020
	destring sales2020, replace force
	drop if missing(vehicle_raw) | vehicle_raw == ""
	
    tempfile table4_data
    save "`table4_data'", replace	
	
	* Importing Table 5 from Kelley Blue Book
	
	import excel using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.xlsx", ///
		clear sheet("Table 5") cellrange(A3) firstrow
	keep A G  // Keep vehicle names and 2020 sales
	rename A vehicle_raw
	rename G sales2020
	destring sales2020, replace force
	drop if missing(vehicle_raw) | vehicle_raw == ""
	append using "`table4_data'"
	
    // Standardize vehicle names
    gen Vehicle = vehicle_raw
    replace Vehicle = "Acura MDX Hybrid" if vehicle_raw == "Acura MDX"
    replace Vehicle = "Acura NSX" if vehicle_raw == "Acura NS-X"  
	replace Vehicle = "Audi Q5 Hybrid" if vehicle_raw == "Audi Q5"  
    replace Vehicle = "Ford Escape/Mercury Mariner" if vehicle_raw == "Ford Escape"
    replace Vehicle = "Ford Fusion & Milan" if vehicle_raw == "Ford Fusion"
    replace Vehicle = "Hyundai Ioniq Hybrid" if vehicle_raw == "Hyundai Ioniq"
    replace Vehicle = "Kia Optima" if vehicle_raw == "Kia Optima/K5"
    replace Vehicle = "Lexus LC500h" if vehicle_raw == "Lexus LC"
    replace Vehicle = "Lexus LS 500h" if vehicle_raw == "Lexus LS"
    replace Vehicle = "Lexus NX Hybrid" if vehicle_raw == "Lexus NX"
    replace Vehicle = "Lexus RX 450h" if vehicle_raw == "Lexus RX"
	replace Vehicle = "Lexus  ES Hybrid" if vehicle_raw == "Lexus ES"
	replace Vehicle = "Toyota Prius" if vehicle_raw == "Toyota Prius / Prius Prime"


	save "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.dta", replace

restore
	
merge 1:1 Vehicle using "${code_files}/1_assumptions/evs/Q4-2021-Kelley-Blue-Book-Sales-Report-Electrified-Light-Vehicles.dta", gen(source) keep(1 2 3)

drop if Vehicle == "Total"

gen batt_cap2020 = .
gen mpg2020 = .

replace batt_cap2020 = 1.3 if Vehicle == "Acura RLX" | Vehicle == "Acura NSX" // https://www.autoweb.com/acura/nsx/2020 and https://en.wikipedia.org/wiki/Acura_RLX
replace batt_cap2020 = 1.1 if Vehicle == "Ford Escape/Mercury Mariner" // https://www.caranddriver.com/news/a27006951/2020-ford-escape-hybrid-plug-in-photos-info/
replace batt_cap2020 = 1.1 if Vehicle == "Ford Explorer" // https://www.caranddriver.com/news/a27006951/2020-ford-escape-hybrid-plug-in-photos-info/
replace batt_cap2020 = 1.4 if Vehicle == "Ford Fusion & Milan" // https://www.holzhauers.com/blog/2020/september/9/everything-you-need-to-know-about-the-ford-fusion-hybrid-battery.htm
replace batt_cap2020 = 1.3 if Vehicle == "Honda Accord" // https://www.caranddriver.com/honda/accord/specs/2020/honda_accord_honda-accord-hybrid_2020
replace batt_cap2020 = 1.2 if Vehicle == "Honda Insight" // https://www.topspeed.com/real-cost-replacing-honda-insight-hybrid-battery/
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Toyota RAV4" // https://www.guideautoweb.com/en/articles/53908/2020-toyota-rav4-hybrid-the-best-rav4-you-can-buy/
replace batt_cap2020 = 6.5 * 288 / 1000 if Vehicle == "Toyota Highlander" // https://assets.sia.toyota.com/publications/en/om-s/OM0E037U/pdf/OM0E037U.pdf p. 508
replace batt_cap2020 = ((3.6 * 207.2 + 6.5 * 201.6) / 1000) / 2 if Vehicle == "Toyota Prius" // https://www.velocityjournal.com/journal/2020/toyota/33872/reviews/310.html
replace batt_cap2020 = ((4  * 259 + 6.5 * 244.8) / 1000) / 2 if Vehicle == "Toyota Camry" // avg of AXVH70 and AXVH71 models, https://assets.sia.toyota.com/publications/en/om-s/OM06233U/pdf/OM06233U.pdf p. 524
replace batt_cap2020 = 6.5 * 201.6 / 1000 if Vehicle == "Toyota Corolla" // https://assets.sia.toyota.com/publications/en/om-s/OM12K81U/pdf/OM12K81U.pdf, p. 498
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Toyota Avalon" // https://assets.sia.toyota.com/publications/en/om-s/OM07017U/pdf/OM07017U.pd, p. 502
replace batt_cap2020 = 6.5 * 240 / 1000 if Vehicle == "Kia Niro" // https://www.kniro.net/description_and_operation-724.html
replace batt_cap2020 = 6.5 * 288 / 1000 if Vehicle == "Lexus RX 450h" // https://assets.sia.toyota.com/publications/en/om-s/OM0E059U/pdf/OM0E059U.pdf, p. 466
replace batt_cap2020 = 6.5 * 270 / 1000 if Vehicle == "Kia Optima" // https://www.kiamedia.com/us/en/models/optima-hybrid/2020/specifications
replace batt_cap2020 = 6.5 * 216 / 1000 if Vehicle == "Lexus UX" // https://www.okacc.com/product/216v-6-5ah-nimh-hybrid-car-battery-replacement-for-lexus-ux-250h-2019/
replace batt_cap2020 = 6.5 * 244.8 / 1000 if Vehicle == "Lexus NX Hybrid" | Vehicle == "Lexus ES Hybrid" // https://assets.sia.toyota.com/publications/en/om-s/OM0E059U/pdf/OM0E059U.pdf, p. 402
replace batt_cap2020 = 3.6 * 310.8 / 1000 if Vehicle == "Lexus LS 500h" | Vehicle == "Lexus LC500h" // https://www.caranddriver.com/reviews/a32132012/2020-lexus-ls500h-drive/ and https://www.caranddriver.com/lexus/lc
replace batt_cap2020 = 1.56 if Vehicle == "Hyundai Ioniq Hybrid" // https://www.encycarpedia.com/us/hyundai/16-ioniq-hybrid-hatch
replace batt_cap2020 = 1.62 if Vehicle == "Hyundai Sonata" // https://www.motortrend.com/reviews/2020-hyundai-sonata-hybrid-first-drive
replace batt_cap2020 = 1 if Vehicle == "Lincoln MKZ" // https://www.cars.com/research/compare/?vehicles=lincoln-mkz-2020,lincoln-mkz_hybrid-2020

*** All msrp info is from edmunds unless otherwise noted

gen msrp2020 = .
replace msrp2020 = (36750 + 42500) / 2 if Vehicle == "Lincoln MKZ" //https://www.edmunds.com/lincoln/mkz/2020/features-specs/
replace msrp2020 = (24325 + 25535 + 26935 + 28375 + 29375 + 32500) / 6 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2020/features-specs/
replace msrp2020 = 52530 if Vehicle == "Ford Explorer" //https://www.edmunds.com/ford/explorer/2020/features-specs/
replace msrp2020 = (28265 + 33550) / 2 if Vehicle == "Ford Escape/Mercury Mariner" //https://www.edmunds.com/ford/escape/2020/features-specs/
replace msrp2020 = 97510 if Vehicle == "Lexus LC500h" //https://www.edmunds.com/lexus/lc500h/2020/features-specs/
replace msrp2020 = 80010 if Vehicle == "Lexus LS 500h" //https://www.edmunds.com/lexus/ls500h/2020/features-specs/
replace msrp2020 = (22930 + 24310 + 28340) / 3 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2020/features-specs/
replace msrp2020 = 157500 if Vehicle == "Acura NSX" //https://www.edmunds.com/acura/nsx/2020/features-specs/
replace msrp2020 = 61900 if Vehicle == "Acura RLX" //https://www.edmunds.com/acura/rlx/2020/features-specs/
replace msrp2020 = (24975 + 27785 + 27785 + 28875 + 31375 + 32315 + 32315 + 33375 + 37205) / 9  if Vehicle == "Honda Accord" // https://hondanews.com/en-US/honda-automobiles/releases/release-807c080220275f828905387c4f006348-2020-honda-accord-pricing-and-epa-ratings-172020#:~:text=Included%20Divisions,Cookie%20Preferences
replace msrp2020 = 23100 if Vehicle == "Toyota Corolla" // https://www.worldtoyota.com/2020-toyota-corolla-hybrid-research/#:~:text=ft%20@%203%2C600%20rpm-,TRANSMISSION,for%202%20years/unlimited%20miles.
replace msrp2020 = (28430 + 30130 + 32730) / 3 if Vehicle == "Toyota Camry" //https://www.seegertoyota.com/research-camry.html
replace msrp2020 = (28000 + 31630 + 34595) / 3 if Vehicle == "Ford Fusion & Milan" //https://www.cars.com/research/ford-fusion_hybrid-2020/
replace msrp2020 = (34500 + 36500 + 39700) / 3 if Vehicle == "Lexus UX" //https://www.cars.com/research/lexus-ux_250h-2020/
replace msrp2020 = (23200 + 25150 + 28400 + 31200) / 4 if Vehicle == "Hyundai Ioniq Hybrid" //https://www.edmunds.com/hyundai/ioniq-hybrid/2020/features-specs/
replace msrp2020 = (24590 + 25990 + 28290 + 30790 + 32790) / 5 if Vehicle == "Kia Niro" //https://www.edmunds.com/kia/niro/2020/features-specs/
replace msrp2020 = (37000 + 39500 + 43300) / 3  if Vehicle == "Toyota Avalon" //https://www.toyotaplace.com/2020-avalon-hybrid/
replace msrp2020 = (41810 + 44665 + 45660) / 3 if Vehicle == "Lexus ES Hybrid" //https://www.cars.com/research/lexus-es_300h-2020/
replace msrp2020 = (39070 + 46160) / 2 if Vehicle == "Lexus NX Hybrid" //https://www.edmunds.com/lexus/nx-300h/2020/features-specs/
replace msrp2020 = (28350 + 29645 + 34300 + 36880) / 4 if Vehicle == "Toyota RAV4" //https://www.carvertoyota.com/2020-rav4-hybrid/
replace msrp2020 = (27750 + 29900 + 35300) / 3 if Vehicle == "Hyundai Sonata" //https://www.cars.com/research/hyundai-sonata_hybrid-2020/
replace msrp2020 = 29310 if Vehicle == "Kia Optima" //https://www.cars.com/research/kia-optima_hybrid-2020/
replace msrp2020 = (46800 + 50600 + 52920) / 3 if Vehicle == "Lexus RX 450h" //https://www.edmunds.com/lexus/rx-450h/2020/features-specs/
replace msrp2020 = (38200 + 41000 + 45050 + 48250) / 4 if Vehicle == "Toyota Highlander" //https://www.toyotaofsaratogasprings.com/2020-highlander-hybrid/
replace msrp2020 = (69000 + 73600 + 79700) / 3 if Vehicle == "Audi A7" //https://www.edmunds.com/audi/a7/2020/features-specs/
//replace msrp2020 = (43450 + 44465 + 46950 + 49750) / 4 if Vehicle == "Jeep Wrangler" XX no jeep wrangler hybrid in 2020
replace msrp2020 = 85200 if Vehicle == "Audi A8" //https://media.audiusa.com/releases/383
replace msrp2020 = 52530 if Vehicle == "Ford Explorer" //https://www.edmunds.com/ford/explorer/2020/features-specs/
replace msrp2020 = (90900 + 96150) / 2 if Vehicle == "Land Rover Range Rover" //https://media.jaguarlandrover.com/en-us/news/2019/04/2020-range-rover-offers-straight-six-performance-and-efficient-mild-hybrid-refinement
replace msrp2020 = 53000 if Vehicle == "Acura MDX Hybrid" //https://www.edmunds.com/acura/mdx/2020/st-401818478/features-specs/

replace msrp2000 = 20495 if Vehicle == "Honda Insight" // https://www.kbb.com/honda/insight/2000/
replace msrp2001 = 18980 if Vehicle == "Honda Insight" //https://hondanews.com/en-US/honda-automobiles/releases/release-098c5538bed9019c638afd004c34c826-2001-honda-insight-prices-and-epa-data
replace msrp2001 = 19995 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2001/review/
replace msrp2002 = 19080 if Vehicle == "Honda Insight" //https://www.cars.com/research/honda-insight-2002/
replace msrp2002 = 19995 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2002/review/
replace msrp2003 = 19080 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2003/review/
replace msrp2003 = 19995 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2003/review/
replace msrp2004 = 19650 if Vehicle == "Honda Civic" //https://www.edmunds.com/honda/civic/2004/features-specs/
replace msrp2004 = 19180 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2004/review/
replace msrp2004 = 20295 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2004/review/
replace msrp2005 = 26830 if Vehicle == "Ford Escape/Mercury Mariner" //https://www.edmunds.com/ford/escape/2005/features-specs/
replace msrp2005 = 19900 if Vehicle == "Honda Civic" //https://www.edmunds.com/honda/civic/2005/review/
replace msrp2005 = 19330 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2005/review/
replace msrp2005 = 21275 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2005/review/
replace msrp2006 = 44660 if Vehicle == "Lexus RX 450h" //https://www.edmunds.com/lexus/rx-400h/2006/review/
replace msrp2006 = 30990 if Vehicle == "Honda Accord" //https://hondanews.com/en-US/honda-automobiles/releases/release-62d354a9c0790131b8228e004c34c067-honda-announces-pricing-for-redesigned-2006-accord-hybrid
replace msrp2006 = 26900 if Vehicle == "Ford Escape/Mercury Mariner"
replace msrp2006 = 19330 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2006/review/
replace msrp2006 = 21725 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2006/review/

replace mpg2000 = 53 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2000/features-specs/

replace mpg2001 = (53 + 47) / 3 if Vehicle == "Honda Insight" // https://www.edmunds.com/honda/insight/2001/features-specs/
replace mpg2001 = 41 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2001/review/

replace mpg2002 = (53 + 47) / 3 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2002/features-specs/
replace mpg2002 = 41 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2002/review/

replace mpg2003 = (53 + 47) / 3 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2003/features-specs/
replace mpg2003 = 41 if Vehicle == "Honda Civic" //https://www.edmunds.com/honda/civic/2003/features-specs/
replace mpg2003 = 41 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2003/review/

replace mpg2004 = (52 + 47) / 3 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2004/features-specs/
replace mpg2004 = 40 if Vehicle == "Honda Civic" //https://www.edmunds.com/honda/civic/2004/features-specs/
replace mpg2004 = 46 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2004/review/

replace mpg2005 = (52 + 47) / 2 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2005/features-specs/
replace mpg2005 = 28 if Vehicle == "Honda Accord" // https://www.fueleconomy.gov/feg/noframes/21539.shtml
replace mpg2005 = (29 + 27) / 2 if Vehicle == "Ford Escape/Mercury Mariner" //https://www.edmunds.com/ford/escape/2005/features-specs/
replace mpg2005 = 40 if Vehicle == "Honda Civic" //https://www.edmunds.com/honda/civic/2005/features-specs/
replace mpg2005 = 46 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2005/review/

replace mpg2006 = (52 + 47) / 2 if Vehicle == "Honda Insight" //https://www.edmunds.com/honda/insight/2006/features-specs/
replace mpg2006 = 25 if Vehicle == "Honda Accord" //https://www.fueleconomy.gov/feg/noframes/22676.shtml
replace mpg2006 = (27 + 25) / 2 if Vehicle == "Lexus RX 450h" //https://www.kbb.com/lexus/rx/2006/rx-400h-sport-utility-4d/
replace mpg2006 = (29 + 27) / 2 if Vehicle == "Ford Escape/Mercury Mariner" //https://www.edmunds.com/ford/escape-hybrid/2006/mpg/?style=100531499
replace mpg2006 = 42 if Vehicle == "Honda Civic" // https://www.edmunds.com/honda/civic/2006/review/
replace mpg2006 = (27 + 26) / 2 if Vehicle == "Toyota Highlander"
replace mpg2006 = 46 if Vehicle == "Toyota Prius" //https://www.edmunds.com/toyota/prius/2006/review/

sort sales2020

// All MPG numbers come from fueleconomy.gov
replace mpg2020 = 24 if Vehicle == "Audi A7" //https://fueleconomy.gov/feg/Find.do?action=sbs&id=42295
replace mpg2020 = 30 if Vehicle == "Lexus LC500h" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41552
replace mpg2020 = (28 + 26) / 2 if Vehicle == "Lexus LS 500h" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42131&id=42132
replace mpg2020 = (21 + 21 + 20) / 3 if Vehicle == "Jeep Wrangler" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42906&id=42908&id=43801
replace mpg2020 = (21 + 18) / 2 if Vehicle == "Audi A8" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42241&id=42306
replace mpg2020 = 21 if Vehicle == "Acura NSX" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42192
replace mpg2020 = 28 if Vehicle == "Acura RLX" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41718
replace mpg2020 = 42 if Vehicle == "Kia Optima" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41437
replace mpg2020 = (18 + 24) / 2 if Vehicle == "Land Rover Range Rover" // https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41636&id=41634
replace mpg2020 = 27 if Vehicle == "Acura MDX Hybrid" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41665
replace mpg2020 = (28 + 26) / 2 if Vehicle == "Lexus LS 500h" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42131&id=42132
replace mpg2020 = 41 if Vehicle == "Lincoln MKZ" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41808
replace mpg2020 = (52 + 47) / 2 if Vehicle == "Hyundai Sonata" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42475&id=42476
replace mpg2020 = (44 + 43) / 2 if Vehicle == "Toyota Avalon" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41813&id=41814
replace mpg2020 = 44 if Vehicle == "Lexus ES Hybrid" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41913
replace mpg2020 = (28 + 25) / 2 if Vehicle == "Ford Explorer" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41939&id=41937
replace mpg2020 = 31 if Vehicle == "Lexus NX Hybrid" //https://www.edmunds.com/lexus/nx-300h/2020/review/
replace mpg2020 = (42 + 39) / 2 if Vehicle == "Lexus UX" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42222&id=42223
replace mpg2020 = (58 + 55) / 2 if Vehicle == "Hyundai Ioniq Hybrid" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42243&id=42242
replace mpg2020 = (30 + 29) / 2 if Vehicle == "Lexus RX 450h" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41974&id=41975
replace mpg2020 = (50 + 49 + 43) / 3 if Vehicle == "Kia Niro" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42307&id=42308&id=42309
replace mpg2020 = (52 + 48) / 2 if Vehicle == "Honda Insight" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41648&id=41649
replace mpg2020 = 52 if Vehicle == "Toyota Corolla" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41214
replace mpg2020 = 48 if Vehicle == "Honda Accord" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42135
replace mpg2020 = (42 + 41) / 2 if Vehicle == "Ford Fusion & Milan" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41802&id=41803
replace mpg2020 = (41 + 40) / 2 if Vehicle == "Ford Escape/Mercury Mariner" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42258&id=42253
replace mpg2020 = (52 + 46) / 2 if Vehicle == "Toyota Camry" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42016&id=42017
replace mpg2020 = (56 + 52 + 50 + 46) / 4 if Vehicle == "Toyota Prius" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=41915&id=41917&id=41916&id=41716
replace mpg2020 = (36 + 35 + 35) / 3 if Vehicle == "Toyota Highlander" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42477&id=42478&id=42479
replace mpg2020 = 40 if Vehicle == "Toyota RAV4" //https://www.fueleconomy.gov/feg/Find.do?action=sbs&id=42187

forv i = 1999(1)2020{
	gen sales_msrp`i' = sales`i'
	gen sales_mpg`i' = sales`i'
	ren sales`i' sales_batt_cap`i'
	replace sales_msrp`i' = 0 if missing(msrp`i')
	replace sales_mpg`i' = 0 if missing(mpg`i')
	replace sales_batt_cap`i' = 0 if missing(batt_cap`i')
}

forv i = 1999(1)2020{
	egen msrp_N`i' = total(sales_msrp`i')
	egen batt_cap_N`i' = total(sales_batt_cap`i')
	egen mpg_N`i' = total(sales_mpg`i')
	egen msrp_weighted_avg`i' = total(sales_msrp`i' * msrp`i')
	replace msrp_weighted_avg`i' = msrp_weighted_avg`i' / msrp_N`i'
	egen batt_cap_weighted_avg`i' = total(sales_batt_cap`i' * batt_cap`i')
	replace batt_cap_weighted_avg`i' = batt_cap_weighted_avg`i' / batt_cap_N`i'
	egen mpg_weighted_avg`i' = total(sales_mpg`i' * mpg`i')
	replace mpg_weighted_avg`i' = mpg_weighted_avg`i' / mpg_N`i'
}


duplicates drop batt_cap_weighted_avg2001 batt_cap_weighted_avg2002, force

* reshape long batt_cap_weighted_avg msrp_weighted_avg mpg_weighted_avg, i(Vehicle) j(year)
reshape long msrp_N batt_cap_N mpg_N batt_cap_weighted_avg msrp_weighted_avg mpg_weighted_avg, i(Vehicle) j(year)
* keep year batt_cap_weighted* msrp_weighted* mpg_weighted*
keep year msrp_N batt_cap_N mpg_N batt_cap_weighted_avg msrp_weighted_avg mpg_weighted_avg


ren msrp_weighted_avg msrp
ren batt_cap_weighted_avg batt_cap 
ren mpg_weighted_avg mpg 
gen mpg_cf = 1 / ((1 / mpg) - -0.000011 * 100) // formula and -0.000011 come from Muehlegger & Rapson (2023), assuming difference between HEV mpg and counterfactual mpg is the same over time

save "${code_files}/1_assumptions/evs/processed/hev_data.dta", replace


















