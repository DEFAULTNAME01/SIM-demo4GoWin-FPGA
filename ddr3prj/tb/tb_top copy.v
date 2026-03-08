`timescale 1ps/1ps

module tb_top;

    // =========================================================
    // Clock / Reset
    // =========================================================
    reg clk;          // user/controller side clock
    //reg memory_clk_raw;
    // 400 MHz memory clock (2.5ns period)
  
    //wire memory_clk;   
    reg memory_clk;
    reg pll_lock;
    reg rst_n;
    wire         pll_stop;
    wire         clk_out;
    wire         ddr_rst;
    wire         init_calib_complete;
    // 100 MHz controller clock
    initial begin
    clk = 1'b0;
    forever #5_000 clk = ~clk;   // 10ns period
    end


    initial begin
        memory_clk = 1'b0;
        forever #1_250 memory_clk = ~memory_clk;   // 400 MHz, timescale=1ps/1ps
    end
    // initial begin
    // memory_clk_raw = 1'b0;
    // forever #1_250 memory_clk_raw = ~memory_clk_raw;   // 2.5ns period
    // end
    // GW5A: pll_stop 为 active-low 控制信号
    // emulate GW5A memory_clk gating by pll_stop (active-low)
    // assign memory_clk = (~pll_stop) ? memory_clk_raw : 1'b0;

    // reset / pll lock sequence
    initial begin
        pll_lock = 1'b0;
        rst_n    = 1'b0;
        //上电等待DDR3内部就绪
        #300_000_000; // 300us
        pll_lock = 1'b1;
        repeat(24) @(posedge clk);
        //#1_000_000;      // 1us
        rst_n    = 1'b1;
    end

    // =========================================================
    // Gowin DDR3 user/native interface
    // 当前阶段全部保持空闲
    // =========================================================
   

    // wire         cmd_ready;
    // reg  [2:0]   cmd;
    // reg          cmd_en;
    // reg  [27:0]  addr;

    // wire         wr_data_rdy;
    // reg  [127:0] wr_data;
    // reg          wr_data_en;
    // reg          wr_data_end;
    // reg  [15:0]  wr_data_mask;

    wire         cmd_ready;
    wire [2:0]   cmd;
    wire         cmd_en;
    wire [27:0]  addr;

    wire         wr_data_rdy;
    wire [127:0] wr_data;
    wire         wr_data_en;
    wire         wr_data_end;
    wire [15:0]  wr_data_mask;
    

    wire [127:0] rd_data;
    wire         rd_data_valid;
    wire         rd_data_end;

    reg          sr_req;
    reg          ref_req;
    wire         sr_ack;
    wire         ref_ack;
    reg          burst;
    
    initial begin
    sr_req  = 1'b0;
    ref_req = 1'b0;
    burst   = 1'b0;
    end

    // =========================================================
    // DDR3 physical interface
    // =========================================================
    wire [13:0] O_ddr_addr;
    wire [2:0]  O_ddr_ba;
    wire        O_ddr_cs_n;
    wire        O_ddr_ras_n;
    wire        O_ddr_cas_n;
    wire        O_ddr_we_n;
    wire        O_ddr_clk;
    wire        O_ddr_clk_n;
    wire        O_ddr_cke;
    wire        O_ddr_odt;
    wire        O_ddr_reset_n;
    wire [1:0]  O_ddr_dqm;
    wire [15:0] IO_ddr_dq;
    wire [1:0]  IO_ddr_dqs;
    wire [1:0]  IO_ddr_dqs_n;

    // =========================================================
    // 默认空闲输入
    // =========================================================
    // initial begin
    //     cmd          = 3'b000;
    //     cmd_en       = 1'b0;
    //     addr         = 28'd0;

    //     wr_data      = 128'd0;
    //     wr_data_en   = 1'b0;
    //     wr_data_end  = 1'b0;
    //     wr_data_mask = 16'h0000;

    //     sr_req       = 1'b0;
    //     ref_req      = 1'b0;

    //     // 先固定为 1，后续 tester 再按协议调整
    //     burst        = 1'b1;
    // end
    
    // =========================================================
    //tester 例化
    // =========================================================
    //先别让 tester 打断仿真，注释掉
    wire ui_clk   = clk_out;
    wire ui_rst_n = ~ddr_rst;   // 若 ddr_rst 为高有效复位
    // native_tester u_tester (
    //     .clk               (ui_clk),
    //     .rst_n             (rst_n),
    //     .init_calib_complete(init_calib_complete),

    //     .cmd_ready         (cmd_ready),
    //     .cmd               (cmd),
    //     .cmd_en            (cmd_en),
    //     .addr              (addr),

    //     .wr_data_rdy       (wr_data_rdy),
    //     .wr_data           (wr_data),
    //     .wr_data_en        (wr_data_en),
    //     .wr_data_end       (wr_data_end),
    //     .wr_data_mask      (wr_data_mask),

    //     .rd_data           (rd_data),
    //     .rd_data_valid     (rd_data_valid),
    //     .rd_data_end       (rd_data_end)
    // );

    // =========================================================
    // DUT : Gowin DDR3 Interface
    // 这里默认你在 run.do 里编译的是 .vo 网表
    // =========================================================
    DDR3_Memory_Interface_Top u_ddr3 (
        .clk                 (clk),
        .pll_stop            (pll_stop),
        .memory_clk          (memory_clk),
        .pll_lock            (pll_lock),
        .rst_n               (rst_n),
        .clk_out             (clk_out),
        .ddr_rst             (ddr_rst),
        .init_calib_complete (init_calib_complete),

        .cmd_ready           (cmd_ready),
        .cmd                 (cmd),
        .cmd_en              (cmd_en),
        .addr                (addr),

        .wr_data_rdy         (wr_data_rdy),
        .wr_data             (wr_data),
        .wr_data_en          (wr_data_en),
        .wr_data_end         (wr_data_end),
        .wr_data_mask        (wr_data_mask),

        .rd_data             (rd_data),
        .rd_data_valid       (rd_data_valid),
        .rd_data_end         (rd_data_end),

        .sr_req              (sr_req),
        .ref_req             (ref_req),
        .sr_ack              (sr_ack),
        .ref_ack             (ref_ack),

        .burst               (burst),

        .O_ddr_addr          (O_ddr_addr),
        .O_ddr_ba            (O_ddr_ba),
        .O_ddr_cs_n          (O_ddr_cs_n),
        .O_ddr_ras_n         (O_ddr_ras_n),
        .O_ddr_cas_n         (O_ddr_cas_n),
        .O_ddr_we_n          (O_ddr_we_n),
        .O_ddr_clk           (O_ddr_clk),
        .O_ddr_clk_n         (O_ddr_clk_n),
        .O_ddr_cke           (O_ddr_cke),
        .O_ddr_odt           (O_ddr_odt),
        .O_ddr_reset_n       (O_ddr_reset_n),
        .O_ddr_dqm           (O_ddr_dqm),
        .IO_ddr_dq           (IO_ddr_dq),
        .IO_ddr_dqs          (IO_ddr_dqs),
        .IO_ddr_dqs_n        (IO_ddr_dqs_n)
    );

    // =========================================================
    // Micron DDR3 x16 behavioral model
    // 编译时必须使用:
    // +define+den2048Mb +define+sg25 +define+x16
    // =========================================================
    wire mem_rst_n_safe;
    wire mem_cke_safe;
    wire mem_ck_safe;
    wire mem_ck_n_safe;
    wire [13:0] mem_addr;
    wire [2:0]  mem_ba;
    wire        mem_cs_n;
    wire        mem_ras_n;
    wire        mem_cas_n;
    wire        mem_we_n;
    wire        mem_ck;
    wire        mem_ck_n;
    wire        mem_cke;
    wire        mem_odt;
    wire        mem_reset_n;
    wire [1:0]  mem_dqm;
    wire        mem_model_enable;

    ddr3_model_safe_wrapper #(
        .ADDR_WIDTH      (14),
        .BA_WIDTH        (3),
        .DQM_WIDTH       (2),
        .ENABLE_DELAY_PS (10000000)   // 10us
    ) u_safe_wrapper (
        .pll_lock    (pll_lock),
        .tb_rst_n    (rst_n),

        .dut_addr    (O_ddr_addr),
        .dut_ba      (O_ddr_ba),
        .dut_cs_n    (O_ddr_cs_n),
        .dut_ras_n   (O_ddr_ras_n),
        .dut_cas_n   (O_ddr_cas_n),
        .dut_we_n    (O_ddr_we_n),
        .dut_ck      (O_ddr_clk),
        .dut_ck_n    (O_ddr_clk_n),
        .dut_cke     (O_ddr_cke),
        .dut_odt     (O_ddr_odt),
        .dut_reset_n (O_ddr_reset_n),
        .dut_dqm     (O_ddr_dqm),

        .mem_addr    (mem_addr),
        .mem_ba      (mem_ba),
        .mem_cs_n    (mem_cs_n),
        .mem_ras_n   (mem_ras_n),
        .mem_cas_n   (mem_cas_n),
        .mem_we_n    (mem_we_n),
        .mem_ck      (mem_ck),
        .mem_ck_n    (mem_ck_n),
        .mem_cke     (mem_cke),
        .mem_odt     (mem_odt),
        .mem_reset_n (mem_reset_n),
        .mem_dqm     (mem_dqm),

        .model_enable(mem_model_enable)
    );
    ddr3 u_mem (
    .rst_n   (mem_reset_n),
    .ck      (mem_ck),
    .ck_n    (mem_ck_n),
    .cke     (mem_cke),
    .cs_n    (mem_cs_n),
    .ras_n   (mem_ras_n),
    .cas_n   (mem_cas_n),
    .we_n    (mem_we_n),
    .ba      (mem_ba),
    .addr    (mem_addr),
    .dm_tdqs (mem_dqm),
    .dq      (IO_ddr_dq),
    .dqs     (IO_ddr_dqs),
    .dqs_n   (IO_ddr_dqs_n),
    .tdqs_n  (),
    .odt     (mem_odt)
);
initial begin
    wait(mem_model_enable == 1'b1);
    $display("[%0t] INFO: safe_wrapper model_enable asserted", $time);
end
initial begin
    $monitor("[%0t] mem_reset_n=%b mem_cke=%b mem_cs_n=%b mem_ras_n=%b mem_cas_n=%b mem_we_n=%b init_calib_complete=%b",
             $time,
             mem_reset_n, mem_cke, mem_cs_n, mem_ras_n, mem_cas_n, mem_we_n,
             init_calib_complete);
end
// initial begin
//     $monitor("[%0t] RAW dut_reset_n=%b dut_cke=%b dut_cs_n=%b dut_ras_n=%b dut_cas_n=%b dut_we_n=%b pll_stop=%b clk_out=%b ddr_rst=%b init_calib_complete=%b",
//              $time,
//              O_ddr_reset_n, O_ddr_cke,
//              O_ddr_cs_n, O_ddr_ras_n, O_ddr_cas_n, O_ddr_we_n,
//              pll_stop, clk_out, ddr_rst, init_calib_complete);
// end
    // =========================================================
    // 仿真放行：功能仿真时强制校准完成
    // =========================================================
    // initial begin
    //     #1600000;  // 1.6 ms
    //     force u_ddr3.init_calib_complete = 1'b1;
    //     $display("[%0t] INFO: force init_calib_complete = 1 for functional simulation", $time);
    //     //#1000;
    //     //release u_ddr3.init_calib_complete;
    // end

    // =========================================================
    // 观察初始化/校准
    // =========================================================
    initial begin
        $display("[%0t] INFO: tb_top start", $time);

        wait(rst_n == 1'b1);
        $display("[%0t] INFO: rst_n released", $time);

        wait(pll_lock == 1'b1);
        $display("[%0t] INFO: pll_lock asserted", $time);
        

        // 等待校准完成，超时则报 warning
        fork
            begin : WAIT_CAL_DONE
                wait(init_calib_complete == 1'b1);
                $display("[%0t] INFO: DDR3 init/calib complete", $time);
            end
            begin : TIMEOUT_GUARD
                 #(64'd100_000_000_000);// 1000 ms
                if (init_calib_complete !== 1'b1)
                    $display("[%0t] WARN: DDR3 init/calib not complete within timeout", $time);
            end
        join_any
        disable WAIT_CAL_DONE;
        disable TIMEOUT_GUARD;

        // #10_000;
        // $stop;
        // =========================================================
        //#5_000_000;
        #(64'd100_000_000_000);
        $display("[%0t] INFO: tb_top timeout stop", $time);
        $stop;
    end

endmodule