transcript on
# 切换到工程根目录

cd D:/ddr3prj

# 删除旧的work库
if {[file exists work]} {
    vdel -lib work -all
}
# 创建work库
vlib work
vmap work work

# compile micron DDR3 model
vlog -sv -mfcu {
+incdir+./micron-ddr3-sdram-verilog-model
+define+den1024Mb
+define+sg25
+define+x16
./micron-ddr3-sdram-verilog-model/ddr3.v
./micron-ddr3-sdram-verilog-model/tb.v
}
# compile Micron示例testbench


# run simulation
vsim work.tb -voptargs=+acc
# 添加波形
add wave -r /*
# 运行
run -all