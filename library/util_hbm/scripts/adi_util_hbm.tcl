# density 4GB,8GB
proc ad_create_hbm {name {density "4GB"}} {
  global hbm_sim;
  if {$hbm_sim == 0} {
    ad_ip_instance hbm $name
    ad_ip_parameter $name CONFIG.USER_HBM_DENSITY $density
    ad_ip_parameter $name CONFIG.USER_APB_EN {false}
  } else {
    # Create data storage HMB controller model (AXI slave)
    ad_ip_instance axi_vip $name [list \
      INTERFACE_MODE {SLAVE} \
    ]
    adi_sim_add_define "HBM_AXI=$name"
  }
}

proc ad_create_util_hbm {name rx_tx_n src_width dst_width segments_per_master} {

  set axi_data_width 256

#  # Numeber of masters
#  if {$rx_tx_n == 1} {
#    set num_m [expr $src_width / $axi_data_width]
#  } else {
#    set num_m [expr $dst_width / $axi_data_width]
#  }

  ad_ip_instance util_hbm $name [list \
    HBM_SEGMENTS_PER_MASTER $segments_per_master \
    SRC_DATA_WIDTH $src_width \
    DST_DATA_WIDTH $dst_width  \
    AXI_DATA_WIDTH $axi_data_width \
  ]
    #NUM_M $num_m \

}

proc ad_connect_hbm {i_hbm i_util_hbm axi_clk axi_aresetn {first_master_index 0}} {
  global hbm_sim;

  set i_util_hbm_ip [get_bd_cells $i_util_hbm]
  set segments_per_master [get_property CONFIG.HBM_SEGMENTS_PER_MASTER $i_util_hbm_ip]
  set num_m [get_property CONFIG.NUM_M $i_util_hbm_ip]

  if {$hbm_sim == 0} {

    set i_hbm_ip [get_bd_cells $i_hbm]
    set num_stacks [get_property CONFIG.USER_HBM_STACK $i_hbm_ip]

    # 16 pseudo channels / sections / segments per stack
    set num_segments [expr $num_stacks*16]

    set totat_used_segments [expr $num_m * $segments_per_master]

    for {set i 0} {$i < $num_segments} {incr i} {

      set i_formatted [format "%02d" [expr $i+$first_master_index]]

      if {$i % $segments_per_master == 0 && $i < $totat_used_segments} {
        ad_ip_parameter $i_hbm CONFIG.USER_SAXI_${i_formatted} {true}
        ad_connect $i_util_hbm/MAXI_[expr $i/$segments_per_master] $i_hbm/SAXI_${i_formatted}
        ad_connect $i_hbm/AXI_${i_formatted}_ACLK $axi_clk
        ad_connect $i_hbm/AXI_${i_formatted}_ARESET_N $axi_aresetn
      } else {
        ad_ip_parameter $i_hbm CONFIG.USER_SAXI_${i_formatted} {false}
      }
    }
  } else {
    # Create smart connect
    ad_ip_instance smartconnect axi_hbm_interconnect [list \
      NUM_MI 1 \
      NUM_SI $num_m \
    ]
    # connect it to hbm vip
    ad_connect axi_hbm_interconnect/M00_AXI $i_hbm/S_AXI
    # connect smart connect to util_hbm
    for {set i 0} {$i < $num_m} {incr i} {
      set i_formatted [format "%02d" $i]
      ad_connect $i_util_hbm/MAXI_$i axi_hbm_interconnect/S${i_formatted}_AXI
    }
    ad_connect axi_hbm_interconnect/aclk $axi_clk
    ad_connect axi_hbm_interconnect/aresetn $axi_aresetn

    ad_connect $i_hbm/aclk $axi_clk
    ad_connect $i_hbm/aresetn $axi_aresetn
  }
  ad_connect $axi_clk $i_util_hbm/m_axi_aclk
  ad_connect $axi_aresetn $i_util_hbm/m_axi_aresetn
}

