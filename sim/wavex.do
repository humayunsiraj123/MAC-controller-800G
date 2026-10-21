onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group TB -radix hexadecimal /tb/clk
add wave -noupdate -group TB -radix hexadecimal /tb/rst
add wave -noupdate -group TB -radix hexadecimal /tb/i_data_axis_tdata
add wave -noupdate -group TB -radix hexadecimal /tb/i_data_axis_tkeep
add wave -noupdate -group TB -radix hexadecimal /tb/i_data_axis_tlast
add wave -noupdate -group TB -radix hexadecimal /tb/i_data_axis_tvalid
add wave -noupdate -group TB -radix hexadecimal /tb/o_crc_axis_tdata
add wave -noupdate -group TB -radix hexadecimal /tb/o_crc_axis_tvalid
add wave -noupdate -group TB -radix hexadecimal /tb/ref_in
add wave -noupdate -group TB -radix hexadecimal /tb/ref_out
add wave -noupdate -group TB -radix hexadecimal /tb/crc_init_val
add wave -noupdate -group TB -radix hexadecimal /tb/xor_out
add wave -noupdate -group TB -radix hexadecimal /tb/pass_cnt
add wave -noupdate -group TB -radix hexadecimal /tb/fail_cnt
add wave -noupdate -expand -group DUT -radix hexadecimal /tb/dut/clk
add wave -noupdate -radix hexadecimal /tb/dut/rst
add wave -noupdate -radix hexadecimal /tb/dut/crc_init_val
add wave -noupdate -radix hexadecimal /tb/dut/xor_out
add wave -noupdate -radix hexadecimal /tb/dut/ref_in
add wave -noupdate -radix hexadecimal /tb/dut/ref_out
add wave -noupdate -radix hexadecimal /tb/dut/o_crc_axis_tdata
add wave -noupdate -radix hexadecimal /tb/dut/o_crc_axis_tvalid
add wave -noupdate /tb/dut/bp_user
add wave -noupdate -radix hexadecimal /tb/dut/i_data_axis_tdata
add wave -noupdate -radix hexadecimal /tb/dut/i_data_axis_tkeep
add wave -noupdate -radix hexadecimal /tb/dut/i_data_axis_tlast
add wave -noupdate -radix hexadecimal /tb/dut/i_data_axis_tvalid
add wave -noupdate -radix hexadecimal -childformat {{{/tb/dut/dbg_data_axis_tdata[15]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[14]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[13]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[12]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[11]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[10]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[9]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[8]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[7]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[6]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[5]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[4]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[3]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[2]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[1]} -radix hexadecimal} {{/tb/dut/dbg_data_axis_tdata[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/dbg_data_axis_tdata[15]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[14]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[13]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[12]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[11]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[10]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[9]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[8]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[7]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[6]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[5]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[4]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[3]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[2]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[1]} {-height 15 -radix hexadecimal} {/tb/dut/dbg_data_axis_tdata[0]} {-height 15 -radix hexadecimal}} /tb/dut/dbg_data_axis_tdata
add wave -noupdate -radix hexadecimal /tb/dut/dbg_data_axis_tkeep
add wave -noupdate -radix hexadecimal -childformat {{{/tb/dut/aligner[31]} -radix hexadecimal} {{/tb/dut/aligner[30]} -radix hexadecimal} {{/tb/dut/aligner[29]} -radix hexadecimal} {{/tb/dut/aligner[28]} -radix hexadecimal} {{/tb/dut/aligner[27]} -radix hexadecimal} {{/tb/dut/aligner[26]} -radix hexadecimal} {{/tb/dut/aligner[25]} -radix hexadecimal} {{/tb/dut/aligner[24]} -radix hexadecimal} {{/tb/dut/aligner[23]} -radix hexadecimal} {{/tb/dut/aligner[22]} -radix hexadecimal} {{/tb/dut/aligner[21]} -radix hexadecimal} {{/tb/dut/aligner[20]} -radix hexadecimal} {{/tb/dut/aligner[19]} -radix hexadecimal} {{/tb/dut/aligner[18]} -radix hexadecimal} {{/tb/dut/aligner[17]} -radix hexadecimal} {{/tb/dut/aligner[16]} -radix hexadecimal} {{/tb/dut/aligner[15]} -radix hexadecimal} {{/tb/dut/aligner[14]} -radix hexadecimal} {{/tb/dut/aligner[13]} -radix hexadecimal} {{/tb/dut/aligner[12]} -radix hexadecimal} {{/tb/dut/aligner[11]} -radix hexadecimal} {{/tb/dut/aligner[10]} -radix hexadecimal} {{/tb/dut/aligner[9]} -radix hexadecimal} {{/tb/dut/aligner[8]} -radix hexadecimal} {{/tb/dut/aligner[7]} -radix hexadecimal} {{/tb/dut/aligner[6]} -radix hexadecimal} {{/tb/dut/aligner[5]} -radix hexadecimal} {{/tb/dut/aligner[4]} -radix hexadecimal} {{/tb/dut/aligner[3]} -radix hexadecimal} {{/tb/dut/aligner[2]} -radix hexadecimal} {{/tb/dut/aligner[1]} -radix hexadecimal} {{/tb/dut/aligner[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/aligner[31]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[30]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[29]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[28]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[27]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[26]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[25]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[24]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[23]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[22]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[21]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[20]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[19]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[18]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[17]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[16]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[15]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[14]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[13]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[12]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[11]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[10]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[9]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[8]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[7]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[6]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[5]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[4]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[3]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[2]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[1]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[0]} {-height 15 -radix hexadecimal}} /tb/dut/aligner
add wave -noupdate -radix hexadecimal /tb/dut/aligner_ofst_c
add wave -noupdate -radix hexadecimal /tb/dut/aligner_ofst
add wave -noupdate -radix hexadecimal /tb/dut/extr_offset
add wave -noupdate -radix hexadecimal /tb/dut/sof_ofst
add wave -noupdate -radix unsigned -childformat {{{/tb/dut/fcs_ofst[7]} -radix unsigned} {{/tb/dut/fcs_ofst[6]} -radix unsigned} {{/tb/dut/fcs_ofst[5]} -radix unsigned} {{/tb/dut/fcs_ofst[4]} -radix unsigned} {{/tb/dut/fcs_ofst[3]} -radix unsigned} {{/tb/dut/fcs_ofst[2]} -radix unsigned} {{/tb/dut/fcs_ofst[1]} -radix unsigned} {{/tb/dut/fcs_ofst[0]} -radix unsigned}} -subitemconfig {{/tb/dut/fcs_ofst[7]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[6]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[5]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[4]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[3]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[2]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[1]} {-height 15 -radix unsigned} {/tb/dut/fcs_ofst[0]} {-height 15 -radix unsigned}} /tb/dut/fcs_ofst
add wave -noupdate -radix hexadecimal /tb/dut/ipg_ofst
add wave -noupdate -radix unsigned /tb/dut/byte_cnt
add wave -noupdate -radix unsigned /tb/dut/byte_cnt_c
add wave -noupdate -radix unsigned /tb/dut/byte_cnt_r
add wave -noupdate -radix unsigned /tb/dut/byte_cnt_avl
add wave -noupdate -radix unsigned /tb/dut/ln_cnt_avl
add wave -noupdate -radix hexadecimal /tb/dut/tlast_lch
add wave -noupdate -radix hexadecimal /tb/dut/arst_n
add wave -noupdate -radix hexadecimal /tb/dut/curr_beat_ln
add wave -noupdate /tb/dut/halt_wr
add wave -noupdate /tb/dut/halt_wr_r
add wave -noupdate /tb/dut/bp_user
add wave -noupdate /tb/dut/i_tready
add wave -noupdate /tb/dut/i_tready_r
add wave -noupdate /tb/bp_user
add wave -noupdate -radix hexadecimal -childformat {{{/tb/dut/aligned[15]} -radix hexadecimal} {{/tb/dut/aligned[14]} -radix hexadecimal} {{/tb/dut/aligned[13]} -radix hexadecimal} {{/tb/dut/aligned[12]} -radix hexadecimal} {{/tb/dut/aligned[11]} -radix hexadecimal} {{/tb/dut/aligned[10]} -radix hexadecimal} {{/tb/dut/aligned[9]} -radix hexadecimal} {{/tb/dut/aligned[8]} -radix hexadecimal} {{/tb/dut/aligned[7]} -radix hexadecimal} {{/tb/dut/aligned[6]} -radix hexadecimal} {{/tb/dut/aligned[5]} -radix hexadecimal} {{/tb/dut/aligned[4]} -radix hexadecimal} {{/tb/dut/aligned[3]} -radix hexadecimal} {{/tb/dut/aligned[2]} -radix hexadecimal} {{/tb/dut/aligned[1]} -radix hexadecimal} {{/tb/dut/aligned[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb/dut/aligned[15]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[14]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[13]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[12]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[11]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[10]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[9]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[8]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[7]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[6]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[5]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[4]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[3]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[2]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[1]} {-height 15 -radix hexadecimal} {/tb/dut/aligned[0]} {-height 15 -radix hexadecimal}} /tb/dut/aligned
add wave -noupdate /tb/dut/wr_vld
add wave -noupdate -radix unsigned /tb/dut/sof_ofst_r
add wave -noupdate -radix unsigned /tb/dut/fcs_ofst_r
add wave -noupdate /tb/dut/sof
add wave -noupdate -radix hexadecimal /tb/dut/wr
add wave -noupdate -radix hexadecimal /tb/dut/wr_data
add wave -noupdate -radix hexadecimal /tb/dut/full
add wave -noupdate -radix hexadecimal /tb/dut/tfull
add wave -noupdate -radix hexadecimal /tb/dut/ovf
add wave -noupdate -radix hexadecimal /tb/dut/rd
add wave -noupdate -radix hexadecimal /tb/dut/rd_data
add wave -noupdate -radix hexadecimal /tb/dut/empty
add wave -noupdate -radix hexadecimal /tb/dut/tempty
add wave -noupdate -radix hexadecimal /tb/dut/udf
add wave -noupdate -radix hexadecimal /tb/dut/num_vld
add wave -noupdate -radix hexadecimal /tb/dut/init_done
add wave -noupdate -radix hexadecimal /tb/dut/sec
add wave -noupdate -radix hexadecimal /tb/dut/ded
add wave -noupdate -radix hexadecimal /tb/dut/cr_wr_en
add wave -noupdate -radix hexadecimal /tb/dut/cr_rd_en
add wave -noupdate -radix hexadecimal /tb/dut/cr_wr_data
add wave -noupdate -radix hexadecimal /tb/dut/cr_rd_data
add wave -noupdate -radix hexadecimal /tb/dut/cr_full
add wave -noupdate -radix hexadecimal /tb/dut/cr_empty
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/clk
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/arst_n
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/wr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/wr_data
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/full
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/tfull
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/ovf
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/rd
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/rd_data
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/empty
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/tempty
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/udf
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/num_vld
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/init_done
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sec
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/ded
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/wr_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/rd_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/clk
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/arst_n
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/wr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/wr_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/full
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/tfull
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/ovf
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/rd
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/rd_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/empty
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/tempty
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/udf
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/num_vld
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/sfifo_cntrlr_inst/entries
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/rd_clk
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/wr_clk
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/arst_n
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/me
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/wr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/wr_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/wr_data
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/rd
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/rd_addr
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/rd_data
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/init_done
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/sec
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/ded
add wave -noupdate -group DATA_BUFF -radix hexadecimal /tb/dut/data_buff/two_port_mem_inst/init_cnt
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/clk
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/arst_n
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/wr_data
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/wr_en
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/full
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/rd_data
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/rd_en
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/empty
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/sc_rd_data
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/sc_rd_en
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/sc_empty
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/middle_reg
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/middle_valid
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/tfull
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/ovf
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/tempty
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/udf
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/num_vld
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/init_done
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/sec
add wave -noupdate -group CNTRL_BUFF -radix hexadecimal /tb/dut/ctrl_buff/ded
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/clk
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/arst_n
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/wr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/wr_data
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/full
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/tfull
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/ovf
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/rd
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/rd_data
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/empty
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/tempty
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/udf
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/num_vld
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/init_done
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sec
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/ded
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/wr_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/rd_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/clk
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/arst_n
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/wr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/wr_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/full
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/tfull
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/ovf
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/rd
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/rd_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/empty
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/tempty
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/udf
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/num_vld
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/sfifo_cntrlr_inst/entries
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/rd_clk
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/wr_clk
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/arst_n
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/me
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/wr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/wr_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/wr_data
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/rd
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/rd_addr
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/rd_data
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/init_done
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/sec
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/ded
add wave -noupdate -group S_FIFO -radix hexadecimal /tb/dut/ctrl_buff/sfifo/two_port_mem_inst/init_cnt
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/clk
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/rst
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_init_val
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/xor_out
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/ref_in
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/ref_out
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/din
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/byteEn
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/dlast
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/flitEn
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_out
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_out_vld
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_pipe_wire
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_pipe_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/dlast_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/flitEn_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/din_masked
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_fwd
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/dlast_fwd
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/flitEn_fwd
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/mask_in_byte
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_int
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/din_refin
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal -childformat {{{/tb/dut/u_tbps_crc/crc_refout[31]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[30]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[29]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[28]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[27]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[26]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[25]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[24]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[23]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[22]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[21]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[20]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[19]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[18]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[17]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[16]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[15]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[14]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[13]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[12]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[11]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[10]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[9]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[8]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[7]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[6]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[5]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[4]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[3]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[2]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[1]} -radix hexadecimal} {{/tb/dut/u_tbps_crc/crc_refout[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/u_tbps_crc/crc_refout[31]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[30]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[29]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[28]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[27]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[26]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[25]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[24]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[23]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[22]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[21]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[20]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[19]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[18]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[17]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[16]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[15]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[14]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[13]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[12]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[11]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[10]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[9]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[8]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[7]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[6]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[5]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[4]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[3]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[2]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[1]} {-height 15 -radix hexadecimal} {/tb/dut/u_tbps_crc/crc_refout[0]} {-height 15 -radix hexadecimal}} /tb/dut/u_tbps_crc/crc_refout
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal -childformat {{{/tb/dut/u_tbps_crc/data_pipe[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/u_tbps_crc/data_pipe[0]} {-height 15 -radix hexadecimal}} /tb/dut/u_tbps_crc/data_pipe
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/data_pipe_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_previous
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_wire
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_reg
add wave -noupdate -group TBPS_CRC_ -radix hexadecimal /tb/dut/u_tbps_crc/crc_vld_rev_reg
add wave -noupdate -radix hexadecimal -childformat {{{/tb/dut/aligner[31]} -radix hexadecimal -childformat {{{[63]} -radix hexadecimal} {{[62]} -radix hexadecimal} {{[61]} -radix hexadecimal} {{[60]} -radix hexadecimal} {{[59]} -radix hexadecimal} {{[58]} -radix hexadecimal} {{[57]} -radix hexadecimal} {{[56]} -radix hexadecimal} {{[55]} -radix hexadecimal} {{[54]} -radix hexadecimal} {{[53]} -radix hexadecimal} {{[52]} -radix hexadecimal} {{[51]} -radix hexadecimal} {{[50]} -radix hexadecimal} {{[49]} -radix hexadecimal} {{[48]} -radix hexadecimal} {{[47]} -radix hexadecimal} {{[46]} -radix hexadecimal} {{[45]} -radix hexadecimal} {{[44]} -radix hexadecimal} {{[43]} -radix hexadecimal} {{[42]} -radix hexadecimal} {{[41]} -radix hexadecimal} {{[40]} -radix hexadecimal} {{[39]} -radix hexadecimal} {{[38]} -radix hexadecimal} {{[37]} -radix hexadecimal} {{[36]} -radix hexadecimal} {{[35]} -radix hexadecimal} {{[34]} -radix hexadecimal} {{[33]} -radix hexadecimal} {{[32]} -radix hexadecimal} {{[31]} -radix hexadecimal} {{[30]} -radix hexadecimal} {{[29]} -radix hexadecimal} {{[28]} -radix hexadecimal} {{[27]} -radix hexadecimal} {{[26]} -radix hexadecimal} {{[25]} -radix hexadecimal} {{[24]} -radix hexadecimal} {{[23]} -radix hexadecimal} {{[22]} -radix hexadecimal} {{[21]} -radix hexadecimal} {{[20]} -radix hexadecimal} {{[19]} -radix hexadecimal} {{[18]} -radix hexadecimal} {{[17]} -radix hexadecimal} {{[16]} -radix hexadecimal} {{[15]} -radix hexadecimal} {{[14]} -radix hexadecimal} {{[13]} -radix hexadecimal} {{[12]} -radix hexadecimal} {{[11]} -radix hexadecimal} {{[10]} -radix hexadecimal} {{[9]} -radix hexadecimal} {{[8]} -radix hexadecimal} {{[7]} -radix hexadecimal} {{[6]} -radix hexadecimal} {{[5]} -radix hexadecimal} {{[4]} -radix hexadecimal} {{[3]} -radix hexadecimal} {{[2]} -radix hexadecimal} {{[1]} -radix hexadecimal} {{[0]} -radix hexadecimal}}} {{/tb/dut/aligner[30]} -radix hexadecimal} {{/tb/dut/aligner[29]} -radix hexadecimal} {{/tb/dut/aligner[28]} -radix hexadecimal} {{/tb/dut/aligner[27]} -radix hexadecimal} {{/tb/dut/aligner[26]} -radix hexadecimal} {{/tb/dut/aligner[25]} -radix hexadecimal} {{/tb/dut/aligner[24]} -radix hexadecimal} {{/tb/dut/aligner[23]} -radix hexadecimal} {{/tb/dut/aligner[22]} -radix hexadecimal} {{/tb/dut/aligner[21]} -radix hexadecimal} {{/tb/dut/aligner[20]} -radix hexadecimal} {{/tb/dut/aligner[19]} -radix hexadecimal} {{/tb/dut/aligner[18]} -radix hexadecimal} {{/tb/dut/aligner[17]} -radix hexadecimal} {{/tb/dut/aligner[16]} -radix hexadecimal} {{/tb/dut/aligner[15]} -radix hexadecimal} {{/tb/dut/aligner[14]} -radix hexadecimal} {{/tb/dut/aligner[13]} -radix hexadecimal} {{/tb/dut/aligner[12]} -radix hexadecimal} {{/tb/dut/aligner[11]} -radix hexadecimal} {{/tb/dut/aligner[10]} -radix hexadecimal} {{/tb/dut/aligner[9]} -radix hexadecimal} {{/tb/dut/aligner[8]} -radix hexadecimal} {{/tb/dut/aligner[7]} -radix hexadecimal} {{/tb/dut/aligner[6]} -radix hexadecimal} {{/tb/dut/aligner[5]} -radix hexadecimal} {{/tb/dut/aligner[4]} -radix hexadecimal} {{/tb/dut/aligner[3]} -radix hexadecimal} {{/tb/dut/aligner[2]} -radix hexadecimal} {{/tb/dut/aligner[1]} -radix hexadecimal} {{/tb/dut/aligner[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/aligner[31]} {-height 15 -radix hexadecimal -childformat {{{[63]} -radix hexadecimal} {{[62]} -radix hexadecimal} {{[61]} -radix hexadecimal} {{[60]} -radix hexadecimal} {{[59]} -radix hexadecimal} {{[58]} -radix hexadecimal} {{[57]} -radix hexadecimal} {{[56]} -radix hexadecimal} {{[55]} -radix hexadecimal} {{[54]} -radix hexadecimal} {{[53]} -radix hexadecimal} {{[52]} -radix hexadecimal} {{[51]} -radix hexadecimal} {{[50]} -radix hexadecimal} {{[49]} -radix hexadecimal} {{[48]} -radix hexadecimal} {{[47]} -radix hexadecimal} {{[46]} -radix hexadecimal} {{[45]} -radix hexadecimal} {{[44]} -radix hexadecimal} {{[43]} -radix hexadecimal} {{[42]} -radix hexadecimal} {{[41]} -radix hexadecimal} {{[40]} -radix hexadecimal} {{[39]} -radix hexadecimal} {{[38]} -radix hexadecimal} {{[37]} -radix hexadecimal} {{[36]} -radix hexadecimal} {{[35]} -radix hexadecimal} {{[34]} -radix hexadecimal} {{[33]} -radix hexadecimal} {{[32]} -radix hexadecimal} {{[31]} -radix hexadecimal} {{[30]} -radix hexadecimal} {{[29]} -radix hexadecimal} {{[28]} -radix hexadecimal} {{[27]} -radix hexadecimal} {{[26]} -radix hexadecimal} {{[25]} -radix hexadecimal} {{[24]} -radix hexadecimal} {{[23]} -radix hexadecimal} {{[22]} -radix hexadecimal} {{[21]} -radix hexadecimal} {{[20]} -radix hexadecimal} {{[19]} -radix hexadecimal} {{[18]} -radix hexadecimal} {{[17]} -radix hexadecimal} {{[16]} -radix hexadecimal} {{[15]} -radix hexadecimal} {{[14]} -radix hexadecimal} {{[13]} -radix hexadecimal} {{[12]} -radix hexadecimal} {{[11]} -radix hexadecimal} {{[10]} -radix hexadecimal} {{[9]} -radix hexadecimal} {{[8]} -radix hexadecimal} {{[7]} -radix hexadecimal} {{[6]} -radix hexadecimal} {{[5]} -radix hexadecimal} {{[4]} -radix hexadecimal} {{[3]} -radix hexadecimal} {{[2]} -radix hexadecimal} {{[1]} -radix hexadecimal} {{[0]} -radix hexadecimal}}} {/tb/dut/aligner[31][63]} {-radix hexadecimal} {/tb/dut/aligner[31][62]} {-radix hexadecimal} {/tb/dut/aligner[31][61]} {-radix hexadecimal} {/tb/dut/aligner[31][60]} {-radix hexadecimal} {/tb/dut/aligner[31][59]} {-radix hexadecimal} {/tb/dut/aligner[31][58]} {-radix hexadecimal} {/tb/dut/aligner[31][57]} {-radix hexadecimal} {/tb/dut/aligner[31][56]} {-radix hexadecimal} {/tb/dut/aligner[31][55]} {-radix hexadecimal} {/tb/dut/aligner[31][54]} {-radix hexadecimal} {/tb/dut/aligner[31][53]} {-radix hexadecimal} {/tb/dut/aligner[31][52]} {-radix hexadecimal} {/tb/dut/aligner[31][51]} {-radix hexadecimal} {/tb/dut/aligner[31][50]} {-radix hexadecimal} {/tb/dut/aligner[31][49]} {-radix hexadecimal} {/tb/dut/aligner[31][48]} {-radix hexadecimal} {/tb/dut/aligner[31][47]} {-radix hexadecimal} {/tb/dut/aligner[31][46]} {-radix hexadecimal} {/tb/dut/aligner[31][45]} {-radix hexadecimal} {/tb/dut/aligner[31][44]} {-radix hexadecimal} {/tb/dut/aligner[31][43]} {-radix hexadecimal} {/tb/dut/aligner[31][42]} {-radix hexadecimal} {/tb/dut/aligner[31][41]} {-radix hexadecimal} {/tb/dut/aligner[31][40]} {-radix hexadecimal} {/tb/dut/aligner[31][39]} {-radix hexadecimal} {/tb/dut/aligner[31][38]} {-radix hexadecimal} {/tb/dut/aligner[31][37]} {-radix hexadecimal} {/tb/dut/aligner[31][36]} {-radix hexadecimal} {/tb/dut/aligner[31][35]} {-radix hexadecimal} {/tb/dut/aligner[31][34]} {-radix hexadecimal} {/tb/dut/aligner[31][33]} {-radix hexadecimal} {/tb/dut/aligner[31][32]} {-radix hexadecimal} {/tb/dut/aligner[31][31]} {-radix hexadecimal} {/tb/dut/aligner[31][30]} {-radix hexadecimal} {/tb/dut/aligner[31][29]} {-radix hexadecimal} {/tb/dut/aligner[31][28]} {-radix hexadecimal} {/tb/dut/aligner[31][27]} {-radix hexadecimal} {/tb/dut/aligner[31][26]} {-radix hexadecimal} {/tb/dut/aligner[31][25]} {-radix hexadecimal} {/tb/dut/aligner[31][24]} {-radix hexadecimal} {/tb/dut/aligner[31][23]} {-radix hexadecimal} {/tb/dut/aligner[31][22]} {-radix hexadecimal} {/tb/dut/aligner[31][21]} {-radix hexadecimal} {/tb/dut/aligner[31][20]} {-radix hexadecimal} {/tb/dut/aligner[31][19]} {-radix hexadecimal} {/tb/dut/aligner[31][18]} {-radix hexadecimal} {/tb/dut/aligner[31][17]} {-radix hexadecimal} {/tb/dut/aligner[31][16]} {-radix hexadecimal} {/tb/dut/aligner[31][15]} {-radix hexadecimal} {/tb/dut/aligner[31][14]} {-radix hexadecimal} {/tb/dut/aligner[31][13]} {-radix hexadecimal} {/tb/dut/aligner[31][12]} {-radix hexadecimal} {/tb/dut/aligner[31][11]} {-radix hexadecimal} {/tb/dut/aligner[31][10]} {-radix hexadecimal} {/tb/dut/aligner[31][9]} {-radix hexadecimal} {/tb/dut/aligner[31][8]} {-radix hexadecimal} {/tb/dut/aligner[31][7]} {-radix hexadecimal} {/tb/dut/aligner[31][6]} {-radix hexadecimal} {/tb/dut/aligner[31][5]} {-radix hexadecimal} {/tb/dut/aligner[31][4]} {-radix hexadecimal} {/tb/dut/aligner[31][3]} {-radix hexadecimal} {/tb/dut/aligner[31][2]} {-radix hexadecimal} {/tb/dut/aligner[31][1]} {-radix hexadecimal} {/tb/dut/aligner[31][0]} {-radix hexadecimal} {/tb/dut/aligner[30]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[29]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[28]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[27]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[26]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[25]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[24]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[23]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[22]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[21]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[20]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[19]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[18]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[17]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[16]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[15]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[14]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[13]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[12]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[11]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[10]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[9]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[8]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[7]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[6]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[5]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[4]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[3]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[2]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[1]} {-height 15 -radix hexadecimal} {/tb/dut/aligner[0]} {-height 15 -radix hexadecimal}} /tb/dut/aligner
add wave -noupdate -radix hexadecimal /tb/dut/aligner_ofst_c
add wave -noupdate -radix hexadecimal /tb/dut/aligner_ofst
add wave -noupdate -radix hexadecimal /tb/dut/arst_n
add wave -noupdate -radix hexadecimal /tb/dut/aligner1
add wave -noupdate -radix hexadecimal /tb/dut/aligner2
add wave -noupdate -radix hexadecimal /tb/dut/aligner3
add wave -noupdate /tb/bp_user
add wave -noupdate /tb/dut/aligned
add wave -noupdate /tb/dut/wr_vld
add wave -noupdate /tb/dut/sof_ofst_r
add wave -noupdate /tb/dut/fcs_ofst_r
add wave -noupdate /tb/dut/sof
add wave -noupdate /tb/dut/extr_offset
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/byteEn
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/UNI_TABLE
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/CRC_TABLE
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/DATA_TABLE
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/DIV_PER_LVL
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/N_TERMS
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/BRANCH_ENABLE_TABLE
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/REVERT_TABLE
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/CRC_POLY
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/CRC_WIDTH
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/REV_PIPE_EN_ONEHOT
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/PIPE_LVL
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_pipe_wire
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_pipe_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/dlast_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/flitEn_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/din_masked
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_fwd
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/dlast_fwd
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/flitEn_fwd
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/mask_in_byte
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_int
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/din_refin
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_refout
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/data_pipe
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/data_pipe_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_previous
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_wire
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_rev_en_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_vld_rev_reg
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_out
add wave -noupdate -group CRC_MODULE -radix hexadecimal /tb/dut/u_tbps_crc/crc_out_vld
add wave -noupdate -radix hexadecimal /tb/dut/in_reg_axis_tdata
add wave -noupdate -radix hexadecimal /tb/dut/in_reg_axis_tkeep
add wave -noupdate -radix hexadecimal /tb/dut/in_reg_axis_tlast
add wave -noupdate -radix hexadecimal /tb/dut/in_reg_axis_tvalid
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/clk
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/arst_n
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_valid
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_data
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_tkeep
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_tlast
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc32_val
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc32_vld
add wave -noupdate -group CRC_ENGINE -radix hexadecimal -childformat {{{/tb/dut/crc_compute_engine/st_pipe_bus[4]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[3]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[2]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[1]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/crc_compute_engine/st_pipe_bus[4]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[3]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[2]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[1]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0]} {-height 15 -radix hexadecimal}} /tb/dut/crc_compute_engine/st_pipe_bus
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/byte_cnt
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/clk
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/arst_n
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_sof_in
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_valid
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_data
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_tkeep
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/i_tx_tlast
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc32_val
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc32_vld
add wave -noupdate -group CRC_ENGINE -radix hexadecimal -childformat {{{/tb/dut/crc_compute_engine/st_pipe_bus[4]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[3]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[2]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[1]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/st_pipe_bus[0]} -radix hexadecimal -childformat {{tvalid -radix hexadecimal} {tdata -radix hexadecimal} {tkeep -radix hexadecimal} {tlast -radix hexadecimal} {sof_vld -radix hexadecimal} {vbyte_cnt -radix hexadecimal}}}} -subitemconfig {{/tb/dut/crc_compute_engine/st_pipe_bus[4]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[3]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[2]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[1]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0]} {-height 15 -radix hexadecimal -childformat {{tvalid -radix hexadecimal} {tdata -radix hexadecimal} {tkeep -radix hexadecimal} {tlast -radix hexadecimal} {sof_vld -radix hexadecimal} {vbyte_cnt -radix hexadecimal}} -expand} {/tb/dut/crc_compute_engine/st_pipe_bus[0].tvalid} {-radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0].tdata} {-radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0].tkeep} {-radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0].tlast} {-radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0].sof_vld} {-radix hexadecimal} {/tb/dut/crc_compute_engine/st_pipe_bus[0].vbyte_cnt} {-radix hexadecimal}} /tb/dut/crc_compute_engine/st_pipe_bus
add wave -noupdate -group CRC_ENGINE -radix hexadecimal -childformat {{{/tb/dut/crc_compute_engine/stg_crc_bm[4]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_crc_bm[3]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_crc_bm[2]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_crc_bm[1]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_crc_bm[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb/dut/crc_compute_engine/stg_crc_bm[4]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_crc_bm[3]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_crc_bm[2]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_crc_bm[1]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_crc_bm[0]} {-height 15 -radix hexadecimal}} /tb/dut/crc_compute_engine/stg_crc_bm
add wave -noupdate -group CRC_ENGINE -radix hexadecimal -childformat {{{/tb/dut/crc_compute_engine/stg_acc_crc_bm[4]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_acc_crc_bm[3]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_acc_crc_bm[2]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_acc_crc_bm[1]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/stg_acc_crc_bm[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb/dut/crc_compute_engine/stg_acc_crc_bm[4]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_acc_crc_bm[3]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_acc_crc_bm[2]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_acc_crc_bm[1]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/stg_acc_crc_bm[0]} {-height 15 -radix hexadecimal}} /tb/dut/crc_compute_engine/stg_acc_crc_bm
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/byte_cnt
add wave -noupdate -group CRC_ENGINE -radix hexadecimal -childformat {{{/tb/dut/crc_compute_engine/crc_stat_am[31]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[30]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[29]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[28]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[27]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[26]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[25]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[24]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[23]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[22]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[21]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[20]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[19]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[18]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[17]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[16]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[15]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[14]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[13]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[12]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[11]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[10]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[9]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[8]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[7]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[6]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[5]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[4]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[3]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[2]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[1]} -radix hexadecimal} {{/tb/dut/crc_compute_engine/crc_stat_am[0]} -radix hexadecimal}} -subitemconfig {{/tb/dut/crc_compute_engine/crc_stat_am[31]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[30]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[29]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[28]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[27]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[26]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[25]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[24]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[23]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[22]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[21]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[20]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[19]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[18]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[17]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[16]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[15]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[14]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[13]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[12]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[11]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[10]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[9]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[8]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[7]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[6]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[5]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[4]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[3]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[2]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[1]} {-height 15 -radix hexadecimal} {/tb/dut/crc_compute_engine/crc_stat_am[0]} {-height 15 -radix hexadecimal}} /tb/dut/crc_compute_engine/crc_stat_am
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/merge_xor_mat
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc_stat_nxt
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/crc_stat
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/corr_mat
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/corr_crc
add wave -noupdate -group CRC_ENGINE -radix hexadecimal /tb/dut/crc_compute_engine/corr_vld_byte
add wave -noupdate -radix hexadecimal /tb/dut/crc_compute_engine/tlast_fnl_stg
add wave -noupdate /tb/dut/i_tready
add wave -noupdate /tb/dut/i_tready_r
add wave -noupdate /tb/dut/halt_wr_r
add wave -noupdate /tb/dut/halt_wr
add wave -noupdate /tb/dut/tlast_lch_r
add wave -noupdate -radix hexadecimal /tb/dut/pkt_ctrl_r
add wave -noupdate -radix hexadecimal /tb/dut/pkt_ctrl
add wave -noupdate -radix hexadecimal /tb/dut/i_tx_valid
add wave -noupdate -radix hexadecimal /tb/dut/i_tx_data
add wave -noupdate -radix hexadecimal /tb/dut/i_tx_tkeep
add wave -noupdate -radix hexadecimal /tb/dut/i_tx_tlast
add wave -noupdate -radix hexadecimal /tb/dut/crc32_val
add wave -noupdate -radix hexadecimal /tb/dut/crc32_vld
add wave -noupdate -radix hexadecimal /tb/dut/crc_wr_en
add wave -noupdate -radix hexadecimal /tb/dut/crc_rd_en
add wave -noupdate -radix hexadecimal /tb/dut/crc_wr_data
add wave -noupdate -radix hexadecimal /tb/dut/crc_rd_data
add wave -noupdate -radix hexadecimal /tb/dut/crc_full
add wave -noupdate -radix hexadecimal /tb/dut/crc_empty
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {12500 ps} 1} {{Cursor 2} {20697 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 255
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {7789 ps} {48225 ps}
