`timescale 1ps/1ps

module ddr3_model_safe_wrapper #(
    parameter ADDR_WIDTH      = 14,
    parameter BA_WIDTH        = 3,
    parameter DQM_WIDTH       = 2,
    parameter ENABLE_DELAY_PS = 10000000   // 10 ns = 10000 ps; 这里先给 10 us 可改大
)(
    input  wire                    pll_lock,
    input  wire                    tb_rst_n,

    input  wire [ADDR_WIDTH-1:0]   dut_addr,
    input  wire [BA_WIDTH-1:0]     dut_ba,
    input  wire                    dut_cs_n,
    input  wire                    dut_ras_n,
    input  wire                    dut_cas_n,
    input  wire                    dut_we_n,
    input  wire                    dut_ck,
    input  wire                    dut_ck_n,
    input  wire                    dut_cke,
    input  wire                    dut_odt,
    input  wire                    dut_reset_n,
    input  wire [DQM_WIDTH-1:0]    dut_dqm,

    output wire [ADDR_WIDTH-1:0]   mem_addr,
    output wire [BA_WIDTH-1:0]     mem_ba,
    output wire                    mem_cs_n,
    output wire                    mem_ras_n,
    output wire                    mem_cas_n,
    output wire                    mem_we_n,
    output wire                    mem_ck,
    output wire                    mem_ck_n,
    output wire                    mem_cke,
    output wire                    mem_odt,
    output wire                    mem_reset_n,
    output wire [DQM_WIDTH-1:0]    mem_dqm,

    output wire                    model_enable
);

    reg model_enable_r;
    assign model_enable = model_enable_r;

    // initial begin
    //     model_enable_r = 1'b0;

    //     wait(pll_lock == 1'b1);
    //     wait(tb_rst_n == 1'b1);

    //     // 额外等待，避免 .vo 网表初期毛刺
    //     #(ENABLE_DELAY_PS);
    //     model_enable_r = 1'b1;
    // end
    initial begin
    model_enable_r = 1'b0;

    wait(pll_lock == 1'b1);
    wait(tb_rst_n == 1'b1);

    // 关键：等待 DUT 真正释放 DDR reset
    wait(dut_reset_n === 1'b1);

    // 再额外给一点余量，满足 CKE / reset 的稳定要求
    #(ENABLE_DELAY_PS);
    model_enable_r = 1'b1;
    end
    // ---------------------------------------------------------
    // 地址类：未知时给 0 即可
    // ---------------------------------------------------------
    assign mem_addr = model_enable_r ? dut_addr : {ADDR_WIDTH{1'b0}};
    assign mem_ba   = model_enable_r ? dut_ba   : {BA_WIDTH{1'b0}};
    assign mem_dqm  = model_enable_r ? dut_dqm  : {DQM_WIDTH{1'b0}};

    // ---------------------------------------------------------
    // 低有效命令线：未知态必须回到“非激活”=1
    // ---------------------------------------------------------
    assign mem_cs_n  = model_enable_r ? ((dut_cs_n  === 1'b0) ? 1'b0 : 1'b1) : 1'b1;
    assign mem_ras_n = model_enable_r ? ((dut_ras_n === 1'b0) ? 1'b0 : 1'b1) : 1'b1;
    assign mem_cas_n = model_enable_r ? ((dut_cas_n === 1'b0) ? 1'b0 : 1'b1) : 1'b1;
    assign mem_we_n  = model_enable_r ? ((dut_we_n  === 1'b0) ? 1'b0 : 1'b1) : 1'b1;

    // ---------------------------------------------------------
    // 高有效控制：未知态回 0
    // ---------------------------------------------------------
    assign mem_reset_n = model_enable_r ? ((dut_reset_n === 1'b1) ? 1'b1 : 1'b0) : 1'b0;
    assign mem_odt     = model_enable_r ? ((dut_odt     === 1'b1) ? 1'b1 : 1'b0) : 1'b0;

    // 只有 reset_n 明确为 1 后，才允许 CKE 为 1
    assign mem_cke     = model_enable_r
                       ? (((dut_cke === 1'b1) && (dut_reset_n === 1'b1)) ? 1'b1 : 1'b0)
                       : 1'b0;

    // ---------------------------------------------------------
    // 时钟：未使能前给一个稳定差分静态值
    // 使能后只把明确 1 当 1，其余为 0
    // ---------------------------------------------------------
    // assign mem_ck   = model_enable_r ? ((dut_ck   === 1'b1) ? 1'b1 : 1'b0) : 1'b0;
    // assign mem_ck_n = model_enable_r ? ((dut_ck_n === 1'b1) ? 1'b1 : 1'b0) : 1'b1;
    // assign mem_ck   = model_enable_r ? dut_ck   : 1'b0;
    // assign mem_ck_n = model_enable_r ? dut_ck_n : 1'b1;
    assign mem_ck   = dut_ck;
    assign mem_ck_n = dut_ck_n;

endmodule
// `timescale 1ns/1ps

// module ddr3_model_safe_wrapper (
//     input  wire pll_lock,
//     input  wire tb_rst_n,
//     input  wire O_ddr_reset_n,
//     input  wire O_ddr_cke,
//     input  wire O_ddr_clk,
//     input  wire O_ddr_clk_n,

//     output wire mem_rst_n_safe,
//     output wire mem_cke_safe,
//     output wire mem_ck_safe,
//     output wire mem_ck_n_safe
// );
//     // ---------------------------------------------------------
//     // 可选：等 testbench 外部复位和 pll_lock 都完成后，
//     // 再允许模型真正“看见”DDR输出，避免 .vo 在 t=0 的毛刺/X 态
//     // ---------------------------------------------------------
//      reg mem_model_enable;

//     initial begin
//         mem_model_enable = 1'b0;
//         wait(pll_lock == 1'b1);
//         wait(tb_rst_n == 1'b1);
//         #1_000;  // 1us 缓冲
//         mem_model_enable = 1'b1;
//     end
//     // ---------------------------------------------------------
//     // Safe clamp
//     // 只有明确为 1 时才输出 1，其余一律按 0 处理
//     // ---------------------------------------------------------
//     assign mem_rst_n_safe = (O_ddr_reset_n === 1'b1) ? 1'b1 : 1'b0;
//     assign mem_cke_safe   = ((O_ddr_cke === 1'b1) && (mem_rst_n_safe == 1'b1)) ? 1'b1 : 1'b0;
//     assign mem_ck_safe    = (O_ddr_clk   === 1'b1) ? 1'b1 : 1'b0;
//     assign mem_ck_n_safe  = (O_ddr_clk_n === 1'b1) ? 1'b1 : 1'b0;

// endmodule