`timescale 1ns/1ps

module tb_top;

    // =========================================================
    // Clock / Reset
    // =========================================================
    reg clk;          // user/controller side clock
    reg memory_clk;   // memory clock input for DDR IP
    reg pll_lock;
    reg rst_n;

    // 100 MHz controller clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 400 MHz memory clock (2.5ns period)
    initial begin
        memory_clk = 1'b0;
        forever #1.25 memory_clk = ~memory_clk;
    end

    // reset / pll lock sequence
    initial begin
        pll_lock = 1'b0;
        rst_n    = 1'b0;
        //上电等待DDR3内部就绪
        #300_000; // 300us
        pll_lock = 1'b1;
        #1_000;      // 1us
        rst_n    = 1'b1;
    end

    // =========================================================
    // Gowin DDR3 user/native interface
    // 当前阶段全部保持空闲
    // =========================================================
    wire         pll_stop;
    wire         clk_out;
    wire         ddr_rst;
    wire         init_calib_complete;

    wire         cmd_ready;
    reg  [2:0]   cmd;
    reg          cmd_en;
    reg  [27:0]  addr;

    wire         wr_data_rdy;
    reg  [127:0] wr_data;
    reg          wr_data_en;
    reg          wr_data_end;
    reg  [15:0]  wr_data_mask;

    wire [127:0] rd_data;
    wire         rd_data_valid;
    wire         rd_data_end;

    reg          sr_req;
    reg          ref_req;
    wire         sr_ack;
    wire         ref_ack;
    reg          burst;

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
    initial begin
        cmd          = 3'b000;
        cmd_en       = 1'b0;
        addr         = 28'd0;

        wr_data      = 128'd0;
        wr_data_en   = 1'b0;
        wr_data_end  = 1'b0;
        wr_data_mask = 16'h0000;

        sr_req       = 1'b0;
        ref_req      = 1'b0;

        // 先固定为 1，后续 tester 再按协议调整
        burst        = 1'b1;
    end

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
    ddr3 u_mem (
        .rst_n   (O_ddr_reset_n),
        .ck      (O_ddr_clk),
        .ck_n    (O_ddr_clk_n),
        .cke     (O_ddr_cke),
        .cs_n    (O_ddr_cs_n),
        .ras_n   (O_ddr_ras_n),
        .cas_n   (O_ddr_cas_n),
        .we_n    (O_ddr_we_n),
        .ba      (O_ddr_ba),
        .addr    (O_ddr_addr),
        .dm_tdqs (O_ddr_dqm),
        .dq      (IO_ddr_dq),
        .dqs     (IO_ddr_dqs),
        .dqs_n   (IO_ddr_dqs_n),
        .tdqs_n  (),
        .odt     (O_ddr_odt)
    );

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
                #2000000; // 2 ms
                if (init_calib_complete !== 1'b1)
                    $display("[%0t] WARN: DDR3 init/calib not complete within timeout", $time);
            end
        join_any
        disable WAIT_CAL_DONE;
        disable TIMEOUT_GUARD;

        #1000;
        $stop;
    end

endmodule