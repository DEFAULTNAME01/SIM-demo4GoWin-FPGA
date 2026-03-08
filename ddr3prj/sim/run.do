transcript on
onbreak {resume}
onerror {puts "TCL ERROR OCCURRED"; error}

#transcript on
#onbreak {quit -f}
#onerror {quit -f}

set REFROOT  D:/ddr3prj/database/Gowin_DDR3_Memory_Interface_RefDesign/DDR3_MC_PHY_1vs4_5a25k
set USERROOT D:/ddr3prj

cd $USERROOT

if {[file exists work]} {
    vdel -lib work -all
}

vlib work
vmap work work

# -------------------------------------------------
# 1) 官方 primitive 仿真文件
# -------------------------------------------------
vlog -sv D:/ddr3prj/database/Gowin_DDR3_Memory_Interface_RefDesign/DDR3_MC_PHY_1vs4_5a25k/tb/prim_sim.v

# -------------------------------------------------
# 2) 官方 DQS 加密仿真模型（GW5A-25K）
# -------------------------------------------------
vlog -sv D:/ddr3prj/database/Gowin_DDR3_Memory_Interface_RefDesign/DDR3_MC_PHY_1vs4_5a25k/simulation/modesim_sim/dqs_25k_modelsim.vp

# -------------------------------------------------
# 3) 你的 PLL + DDR3 IP 网表(使用tb时钟)
# -------------------------------------------------
#vlog -sv D:/ddr3prj/fpga_project_ddr3test/src/gowin_pll/gowin_pll.v
vlog -sv D:/ddr3prj/fpga_project_ddr3test/src/ddr3_memory_interface/ddr3_memory_interface.vo

# -------------------------------------------------
# 4) 你原有目录中的 Micron DDR3 模型MT41K128M16JT-125:k
# -------------------------------------------------
vlog -sv -mfcu \
    +incdir+D:/ddr3prj/micron-ddr3-sdram-verilog-model \
    +define+den2048Mb \
    +define+sg25 \
    +define+x16 \
    D:/ddr3prj/micron-ddr3-sdram-verilog-model/ddr3.v

# -------------------------------------------------
# 5) 你的 testbench
# -------------------------------------------------
vlog -sv D:/ddr3prj/tb/ddr_test_hammer.v
vlog -sv D:/ddr3prj/tb/ddr_test_faultscan.v
vlog -sv D:/ddr3prj/tb/safe_wrapper.v
vlog -sv D:/ddr3prj/tb/native_tester.v
vlog -sv D:/ddr3prj/tb/tb_top.v


# -------------------------------------------------
# 6) 仿真 参数化运行
# -------------------------------------------------
#vsim work.tb_top
#vsim work.tb_top +TESTCASE=FAULTSCAN +PATTERN=0 +INJECT=0 +SEED=12345
vsim work.tb_top +TESTCASE=HAMMER +HAMMER_ITER=50000

view wave
view structure
view signals

add wave -r /*

# 官方模板时长
run 100ms
