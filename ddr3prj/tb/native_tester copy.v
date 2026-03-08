`timescale 1ps/1ps
// 注意：clk 应为 DDR3 IP 输出的 clk_out
// rst_n 应为与 IP 内部状态一致的用户侧复位
module native_tester(
    input               clk,
    input               rst_n,
    input               init_calib_complete,

    input               cmd_ready,
    output reg  [2:0]   cmd,
    output reg          cmd_en,
    output reg  [27:0]  addr,

    input               wr_data_rdy,
    output reg  [127:0] wr_data,
    output reg          wr_data_en,
    output reg          wr_data_end,
    output reg  [15:0]  wr_data_mask,

    input      [127:0]  rd_data,
    input               rd_data_valid,
    input               rd_data_end
);

    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;

    localparam [3:0]
        S_IDLE      = 4'd0,
        S_WAIT_CAL  = 4'd1,
        S_WRITE     = 4'd2,
        S_WAIT_GAP  = 4'd3,
        S_READ      = 4'd4,
        S_WAIT_RD   = 4'd5,
        S_DONE      = 4'd6,
        S_FAIL      = 4'd7;

    reg [3:0]  state;
    reg [31:0] cnt;

    reg [27:0]  test_addr;
    reg [127:0] expected_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            cnt           <= 32'd0;

            cmd           <= 3'b000;
            cmd_en        <= 1'b0;
            addr          <= 28'd0;

            wr_data       <= 128'd0;
            wr_data_en    <= 1'b0;
            wr_data_end   <= 1'b0;
            wr_data_mask  <= 16'h0000;

            test_addr     <= 28'h0000010;
            expected_data <= 128'h11223344_55667788_99AABBCC_DDEEFF00;
        end
        else begin
            cmd_en      <= 1'b0;
            wr_data_en  <= 1'b0;
            wr_data_end <= 1'b0;

            case (state)
                S_IDLE: begin
                    state <= S_WAIT_CAL;
                end

                S_WAIT_CAL: begin
                    if (init_calib_complete) begin
                        $display("[%0t] INFO: tester start after calib complete", $time);
                        cnt   <= 32'd0;
                        state <= S_WRITE;
                    end
                end

                // 按手册：写命令和地址有效时 cmd_en=1；
                // 对你这组参数，一次 BL8 写恰好 1 个 128bit beat，
                // 所以 wr_data_en / wr_data_end 同拍拉高
                S_WRITE: begin
                    if (cmd_ready && wr_data_rdy) begin
                        cmd          <= CMD_WRITE;
                        cmd_en       <= 1'b1;
                        addr         <= test_addr;

                        wr_data      <= expected_data;
                        wr_data_en   <= 1'b1;
                        wr_data_end  <= 1'b1;
                        wr_data_mask <= 16'h0000;

                        $display("[%0t] INFO: WRITE cmd+data issued addr=%h data=%h",
                                 $time, test_addr, expected_data);

                        cnt   <= 32'd0;
                        state <= S_WAIT_GAP;
                    end
                end

                // 给控制器一点调度余量
                S_WAIT_GAP: begin
                    cnt <= cnt + 1'b1;
                    if (cnt == 32'd16) begin
                        state <= S_READ;
                    end
                end

                S_READ: begin
                    if (cmd_ready) begin
                        cmd    <= CMD_READ;
                        cmd_en <= 1'b1;
                        addr   <= test_addr;

                        $display("[%0t] INFO: READ cmd issued addr=%h",
                                 $time, test_addr);

                        cnt   <= 32'd0;
                        state <= S_WAIT_RD;
                    end
                end

                S_WAIT_RD: begin
                    cnt <= cnt + 1'b1;

                    if (rd_data_valid) begin
                        $display("[%0t] INFO: READ returned data=%h end=%b",
                                 $time, rd_data, rd_data_end);

                        if (rd_data === expected_data) begin
                            $display("[%0t] PASS: DDR3 readback matched", $time);
                            state <= S_DONE;
                        end
                        else begin
                            $display("[%0t] FAIL: DDR3 readback mismatch exp=%h got=%h",
                                     $time, expected_data, rd_data);
                            state <= S_FAIL;
                        end
                    end
                    else if (cnt == 32'd2000) begin
                        $display("[%0t] FAIL: timeout waiting rd_data_valid", $time);
                        state <= S_FAIL;
                    end
                end

                S_DONE: begin
                    $display("[%0t] INFO: tester done", $time);
                    $stop;
                end

                S_FAIL: begin
                    $display("[%0t] ERROR: tester fail", $time);
                    $stop;
                end

                default: begin
                    state <= S_FAIL;
                end
            endcase
        end
    end

endmodule