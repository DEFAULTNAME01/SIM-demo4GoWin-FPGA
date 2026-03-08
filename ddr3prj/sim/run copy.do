transcript on
cd D:/ddr3prj

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# -------------------------------------------------
# 1) Gowin GW5A primitive simulation libraries
# -------------------------------------------------
vlog  C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_sim.vhd
vlog  C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_syn.vhd
vlog -sv C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_sim.v
vlog -sv +nospecify C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_tsim.v


# -------------------------------------------------
# 2) Gowin DDR3 IP netlist (.vo)
# -------------------------------------------------
vlog -sv ./fpga_project_ddr3test/src/ddr3_memory_interface/ddr3_memory_interface.vo

# -------------------------------------------------
# 3) Micron DDR3 x16 2Gb behavioral model
# -------------------------------------------------
vlog -sv -mfcu +incdir+./micron-ddr3-sdram-verilog-model +define+den2048Mb +define+sg25 +define+x16 ./micron-ddr3-sdram-verilog-model/ddr3.v

# -------------------------------------------------
# 4) Top testbench
# -------------------------------------------------
vlog -sv ./tb/safe_wrapper.v
vlog -sv ./tb/native_tester.v
vlog -sv ./tb/tb_top.v

# -------------------------------------------------
# 5) Run
# -------------------------------------------------
vsim work.tb_top -voptargs=+acc
add wave -r /*
run 105 ms