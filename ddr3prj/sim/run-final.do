transcript on
cd D:/ddr3prj

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# Gowin GW5A simulation primitives
vlog -sv C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_sim.v
vlog -sv C:/Gowin/Gowin_V1.9.11.03_Education_x64/IDE/simlib/gw5a/prim_tsim.v

# Gowin DDR3 IP netlist
vlog -sv ./fpga_project_ddr3test/src/ddr3_memory_interface/ddr3_memory_interface.vo

# Micron DDR3 model
vlog -sv -mfcu +incdir+./micron-ddr3-sdram-verilog-model +define+den1024Mb +define+sg25 +define+x16 ./micron-ddr3-sdram-verilog-model/ddr3.v

# 你自己的 testbench（后面补）
# vlog -sv ./tb/tb_top.v
# vlog -sv ./tb/native_tester.v

# vsim work.tb_top -voptargs=+acc
# add wave -r /*
# run 1 ms