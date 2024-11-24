

global maindir "${dropbox_me}/Regulation"
global working "${dropbox_me}/Regulation/publication_bias"

global raw_data   "${maindir}/code_files/2a_causal_estimates_papers/uncorrected"


local policy_list rggi  bev_state levin_gas /// 
                  jet_fuel retrofit_res ct_solar opower_ng federal_ev hev_usa ///
                  hev_usa_i hev_usa_s hybrid_cr hybrid_de muehl_efmp li_gas gelman_gas ///
                  cog_gas small_gas_lr sent_ch_gas su_gas manzan_gas h_gas_01_06 k_gas_15_22 ///
                  dk_gas park_gas wap hancevic_rf ihwap ihwap_nb ihwap_lb ihwap_hb hitaj_ptc ///
                  shirmali_ptc metcalf_ptc ne_solar hughes_csi pless_ho pless_tpo c4a_fridge ///
                  c4a_cw c4a_dw rebate_es ca_electric care esa_fridge audit_nudge opower_e her_compiled ///
                  solarize c4c_federal c4c_texas baaqmd rao_crude dahl_diesel 
  
 
local filelist : dir "$raw_data" files "*.csv"



foreach policy of local policy_list {
  local policy_list_csv `policy_list_csv' `policy'.csv
}

local filelistfinal: list filelist & policy_list_csv

clear 

foreach file of local filelistfinal {
  preserve
    import delimited using "${raw_data}/`file'", clear
    g paper = "`file'"
    tempfile toappend
    save `toappend'
  restore 
  append using `toappend', force
}

drop if se == 0 // ask about these 
drop if mi(t_stat) & mi(se) & mi(p_value) 
replace se = abs(pe/t_stat) if mi(se) // confirm absolute value issue here
encode paper, gen(cluster_id) 
g include = 1 
keep pe se cluster_id include
order pe se cluster_id include 

export delimited using "${working}/data/to_upload.csv", replace novar nolab

