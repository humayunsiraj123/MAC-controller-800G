# Clean previous library
if {![info exists MODE]} { set MODE "" }
if {[file exists work]} { vdel -all }
vlib work
vmap work work

# Compile RTL
vlog -sv +incdir+../rtl ../rtl/crc32_pkg.sv ../rtl/fifo/sfifo.sv ../rtl/fifo/sfifo_cntrlr.sv ../rtl/fifo/two_port_mem.sv ../rtl/fifo/fwt_fifo_wrapper.sv  ../rtl/crc_compute_engine.sv   ../rtl/mac_bw_monitor.sv ../rtl/mac_tx_scoreboard.sv  ../rtl/mac_tx_scoreboard_simple.sv   ../rtl/mac_controller.sv   
#../rtl/tbps_crc_axis.sv 

# Compile testbench
vlog -sv +incdir+../rtl tb.sv

switch -- $MODE {
    "FULL_BEATS"  { vlog -sv +define+FULL_BEATS  +incdir+../rtl tb.sv }
    "SMALL_FRAME" { vlog -sv +define+SMALL_FRAME +incdir+../rtl tb.sv }
    "PERF"        { vlog -sv +define+PERF +incdir+../rtl tb.sv }
    "PERF1"        { vlog -sv +define+PERF1 +incdir+../rtl tb.sv }
    "PERF2"        { vlog -sv +define+PERF2 +incdir+../rtl tb.sv }
    default       { vlog -sv                      +incdir+../rtl tb.sv }
}


# Load design
# -voptargs="+acc" preserves all signal visibility for the wave window
# -suppress 12110 silences the deprecation warning
vsim -voptargs="+acc" -suppress 12110 work.tb

# Add all signals
#add wave -r /*
do wave.do
# Run
run -all