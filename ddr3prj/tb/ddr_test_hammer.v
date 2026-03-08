`timescale 1ps/1ps

module ddr_test_hammer(
    input               clk,
    input               rst_n,
    input               enable,
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
    input               rd_data_end,

    output reg          done,
    output reg          fail
);

    localparam [2:0] CMD_WRITE = 3'b000;
    localparam [2:0] CMD_READ  = 3'b001;

    localparam [4:0]
        S_IDLE          = 5'd0,
        S_WAIT_CAL      = 5'd1,
        S_INIT_VICTIM   = 5'd2,
        S_INIT_AGGR_A   = 5'd3,
        S_INIT_AGGR_B   = 5'd4,
        S_HAMMER_A      = 5'd5,
        S_HAMMER_A_WAIT = 5'd6,
        S_HAMMER_B      = 5'd7,
        S_HAMMER_B_WAIT = 5'd8,
        S_CHECK_VICTIM  = 5'd9,
        S_WAIT_RD       = 5'd10,
        S_DONE          = 5'd11,
        S_FAIL          = 5'd12;

    reg [4:0]  state;
    reg [31:0] cnt;
    reg [31:0] hammer_iter;
    reg [31:0] hammer_limit;

    reg [27:0] victim_addr;
    reg [27:0] aggr_a_addr;
    reg [27:0] aggr_b_addr;

    reg [127:0] victim_pattern;
    reg [127:0] aggr_pattern;
    reg [127:0] rd_capture;

    integer error_bits;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            cnt           <= 32'd0;
            hammer_iter   <= 32'd0;
            hammer_limit  <= 32'd10000;

            victim_addr   <= 28'h0001000;
            aggr_a_addr   <= 28'h0000FF0;
            aggr_b_addr   <= 28'h0001010;

            victim_pattern<= 128'h0000_0000_0000_0000_0000_0000_0000_0000;
            aggr_pattern  <= 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;

            cmd           <= 3'b000;
            cmd_en        <= 1'b0;
            addr          <= 28'd0;

            wr_data       <= 128'd0;
            wr_data_en    <= 1'b0;
            wr_data_end   <= 1'b0;
            wr_data_mask  <= 16'h0000;

            done          <= 1'b0;
            fail          <= 1'b0;
            error_bits    <= 0;
        end else begin
            cmd_en      <= 1'b0;
            wr_data_en  <= 1'b0;
            wr_data_end <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    fail <= 1'b0;
                    if (enable) begin
                        if (!$value$plusargs("HAMMER_ITER=%d", hammer_limit))
                            hammer_limit <= 32'd10000;
                        state <= S_WAIT_CAL;
                    end
                end

                S_WAIT_CAL: begin
                    if (init_calib_complete) begin
                        $display("[%0t] INFO: HAMMER test start", $time);
                        hammer_iter <= 32'd0;
                        error_bits  <= 0;
                        state <= S_INIT_VICTIM;
                    end
                end

                S_INIT_VICTIM: begin
                    if (cmd_ready && wr_data_rdy) begin
                        cmd          <= CMD_WRITE;
                        cmd_en       <= 1'b1;
                        addr         <= victim_addr;
                        wr_data      <= victim_pattern;
                        wr_data_en   <= 1'b1;
                        wr_data_end  <= 1'b1;
                        wr_data_mask <= 16'h0000;
                        $display("[%0t] INFO: init victim addr=%h data=%h", $time, victim_addr, victim_pattern);
                        state <= S_INIT_AGGR_A;
                    end
                end

                S_INIT_AGGR_A: begin
                    if (cmd_ready && wr_data_rdy) begin
                        cmd          <= CMD_WRITE;
                        cmd_en       <= 1'b1;
                        addr         <= aggr_a_addr;
                        wr_data      <= aggr_pattern;
                        wr_data_en   <= 1'b1;
                        wr_data_end  <= 1'b1;
                        wr_data_mask <= 16'h0000;
                        state <= S_INIT_AGGR_B;
                    end
                end

                S_INIT_AGGR_B: begin
                    if (cmd_ready && wr_data_rdy) begin
                        cmd          <= CMD_WRITE;
                        cmd_en       <= 1'b1;
                        addr         <= aggr_b_addr;
                        wr_data      <= aggr_pattern;
                        wr_data_en   <= 1'b1;
                        wr_data_end  <= 1'b1;
                        wr_data_mask <= 16'h0000;
                        state <= S_HAMMER_A;
                    end
                end

                S_HAMMER_A: begin
                    if (cmd_ready) begin
                        cmd    <= CMD_READ;
                        cmd_en <= 1'b1;
                        addr   <= aggr_a_addr;
                        state  <= S_HAMMER_A_WAIT;
                    end
                end

                S_HAMMER_A_WAIT: begin
                    if (rd_data_valid) begin
                        state <= S_HAMMER_B;
                    end
                end

                S_HAMMER_B: begin
                    if (cmd_ready) begin
                        cmd    <= CMD_READ;
                        cmd_en <= 1'b1;
                        addr   <= aggr_b_addr;
                        state  <= S_HAMMER_B_WAIT;
                    end
                end

                S_HAMMER_B_WAIT: begin
                    if (rd_data_valid) begin
                        hammer_iter <= hammer_iter + 1'b1;
                        if (hammer_iter >= hammer_limit - 1) begin
                            $display("[%0t] INFO: hammer iteration done = %0d", $time, hammer_limit);
                            state <= S_CHECK_VICTIM;
                        end else begin
                            state <= S_HAMMER_A;
                        end
                    end
                end

                S_CHECK_VICTIM: begin
                    if (cmd_ready) begin
                        cmd    <= CMD_READ;
                        cmd_en <= 1'b1;
                        addr   <= victim_addr;
                        state  <= S_WAIT_RD;
                    end
                end

                S_WAIT_RD: begin
                    if (rd_data_valid) begin
                        rd_capture = rd_data;
                        error_bits = 0;
                        for (i = 0; i < 128; i = i + 1) begin
                            if (rd_capture[i] !== victim_pattern[i])
                                error_bits = error_bits + 1;
                        end

                        $display("[%0t] INFO: victim readback=%h expected=%h error_bits=%0d",
                                 $time, rd_capture, victim_pattern, error_bits);

                        if (error_bits == 0) begin
                            $display("[%0t] PASS: HAMMER test no bit flip detected", $time);
                            state <= S_DONE;
                        end else begin
                            $display("[%0t] FAIL: HAMMER test detected %0d bit flips", $time, error_bits);
                            state <= S_FAIL;
                        end
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                end

                S_FAIL: begin
                    done <= 1'b1;
                    fail <= 1'b1;
                end

                default: state <= S_FAIL;
            endcase
        end
    end

endmodule