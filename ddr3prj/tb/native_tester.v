`timescale 1ps/1ps

module native_tester(
    input               clk,
    input               rst_n,
    input               init_calib_complete,

    input               cmd_ready,
    output wire [2:0]   cmd,
    output wire         cmd_en,
    output wire [27:0]  addr,

    input               wr_data_rdy,
    output wire [127:0] wr_data,
    output wire         wr_data_en,
    output wire         wr_data_end,
    output wire [15:0]  wr_data_mask,

    input      [127:0]  rd_data,
    input               rd_data_valid,
    input               rd_data_end
);

    reg hammer_enable;
    reg faultscan_enable;
    string testcase_str;

    // hammer outputs
    wire [2:0]   hammer_cmd;
    wire         hammer_cmd_en;
    wire [27:0]  hammer_addr;
    wire [127:0] hammer_wr_data;
    wire         hammer_wr_data_en;
    wire         hammer_wr_data_end;
    wire [15:0]  hammer_wr_data_mask;
    wire         hammer_done;
    wire         hammer_fail;

    // faultscan outputs
    wire [2:0]   fault_cmd;
    wire         fault_cmd_en;
    wire [27:0]  fault_addr;
    wire [127:0] fault_wr_data;
    wire         fault_wr_data_en;
    wire         fault_wr_data_end;
    wire [15:0]  fault_wr_data_mask;
    wire         fault_done;
    wire         fault_fail;

    initial begin
        hammer_enable    = 1'b0;
        faultscan_enable = 1'b0;

        if (!$value$plusargs("TESTCASE=%s", testcase_str))
            testcase_str = "FAULTSCAN";

        #1;
        if (testcase_str == "HAMMER") begin
            hammer_enable    = 1'b1;
            faultscan_enable = 1'b0;
            $display("[%0t] INFO: TESTCASE = HAMMER", $time);
        end else begin
            hammer_enable    = 1'b0;
            faultscan_enable = 1'b1;
            $display("[%0t] INFO: TESTCASE = FAULTSCAN", $time);
        end
    end

    ddr_test_hammer u_hammer (
        .clk            (clk),
        .rst_n          (rst_n),
        .enable         (hammer_enable),
        .init_calib_complete(init_calib_complete),

        .cmd_ready      (cmd_ready),
        .cmd            (hammer_cmd),
        .cmd_en         (hammer_cmd_en),
        .addr           (hammer_addr),

        .wr_data_rdy    (wr_data_rdy),
        .wr_data        (hammer_wr_data),
        .wr_data_en     (hammer_wr_data_en),
        .wr_data_end    (hammer_wr_data_end),
        .wr_data_mask   (hammer_wr_data_mask),

        .rd_data        (rd_data),
        .rd_data_valid  (rd_data_valid),
        .rd_data_end    (rd_data_end),

        .done           (hammer_done),
        .fail           (hammer_fail)
    );

    ddr_test_faultscan u_faultscan (
        .clk            (clk),
        .rst_n          (rst_n),
        .enable         (faultscan_enable),
        .init_calib_complete(init_calib_complete),

        .cmd_ready      (cmd_ready),
        .cmd            (fault_cmd),
        .cmd_en         (fault_cmd_en),
        .addr           (fault_addr),

        .wr_data_rdy    (wr_data_rdy),
        .wr_data        (fault_wr_data),
        .wr_data_en     (fault_wr_data_en),
        .wr_data_end    (fault_wr_data_end),
        .wr_data_mask   (fault_wr_data_mask),

        .rd_data        (rd_data),
        .rd_data_valid  (rd_data_valid),
        .rd_data_end    (rd_data_end),

        .done           (fault_done),
        .fail           (fault_fail)
    );

    assign cmd          = hammer_enable ? hammer_cmd          : fault_cmd;
    assign cmd_en       = hammer_enable ? hammer_cmd_en       : fault_cmd_en;
    assign addr         = hammer_enable ? hammer_addr         : fault_addr;
    assign wr_data      = hammer_enable ? hammer_wr_data      : fault_wr_data;
    assign wr_data_en   = hammer_enable ? hammer_wr_data_en   : fault_wr_data_en;
    assign wr_data_end  = hammer_enable ? hammer_wr_data_end  : fault_wr_data_end;
    assign wr_data_mask = hammer_enable ? hammer_wr_data_mask : fault_wr_data_mask;

    always @(posedge clk) begin
        if (hammer_done) begin
            if (hammer_fail)
                $display("[%0t] ERROR: HAMMER test fail", $time);
            else
                $display("[%0t] INFO: HAMMER test done", $time);
            $stop;
        end

        if (fault_done) begin
            if (fault_fail)
                $display("[%0t] ERROR: FAULTSCAN test finished with detected error(s)", $time);
            else
                $display("[%0t] INFO: FAULTSCAN test done", $time);
            $stop;
        end
    end

endmodule