`timescale 1ps/1ps

module ddr_test_faultscan(
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
        S_IDLE      = 5'd0,
        S_WAIT_CAL  = 5'd1,
        S_WRITE     = 5'd2,
        S_GAP       = 5'd3,
        S_READ      = 5'd4,
        S_WAIT_RD   = 5'd5,
        S_DONE      = 5'd6,
        S_FAIL      = 5'd7;

    reg [4:0] state;
    reg [31:0] cnt;

    reg [27:0] test_addr;
    reg [127:0] expected_data;
    reg [127:0] compare_data;

    integer pattern_mode;      // 0=random 1=all0 2=all1
    integer inject_enable;     // 0/1
    integer inject_mode;       // 0=fixed bit 1=random bit
    integer inject_bit;        // fixed bit index
    integer seed;
    integer rand_bit;
    integer i;
    integer error_bits;

    function [127:0] make_pattern;
        input integer mode;
        input integer local_seed;
        reg [31:0] r0, r1, r2, r3;
        begin
            case (mode)
                1: make_pattern = 128'h0;
                2: make_pattern = {128{1'b1}};
                default: begin
                    r0 = $random(local_seed);
                    r1 = $random(local_seed ^ 32'h13579BDF);
                    r2 = $random(local_seed ^ 32'h2468ACE0);
                    r3 = $random(local_seed ^ 32'hA5A55A5A);
                    make_pattern = {r0, r1, r2, r3};
                end
            endcase
        end
    endfunction

    function [127:0] inject_fault;
        input [127:0] din;
        input integer do_inject;
        input integer mode;
        input integer fixed_bit;
        input integer local_seed;
        reg [127:0] tmp;
        integer bitpos;
        begin
            tmp = din;
            if (do_inject != 0) begin
                if (mode == 0) begin
                    bitpos = fixed_bit;
                end else begin
                    bitpos = ($random(local_seed) & 32'h7fffffff) % 128;
                end
                tmp[bitpos] = ~tmp[bitpos];
                $display("[%0t] INFO: inject fault bit=%0d", $time, bitpos);
            end
            inject_fault = tmp;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            cnt           <= 32'd0;
            test_addr     <= 28'h0000020;
            expected_data <= 128'd0;
            compare_data  <= 128'd0;

            cmd           <= 3'b000;
            cmd_en        <= 1'b0;
            addr          <= 28'd0;

            wr_data       <= 128'd0;
            wr_data_en    <= 1'b0;
            wr_data_end   <= 1'b0;
            wr_data_mask  <= 16'h0000;

            pattern_mode  <= 0;
            inject_enable <= 0;
            inject_mode   <= 0;
            inject_bit    <= 0;
            seed          <= 32'h12345678;

            done          <= 1'b0;
            fail          <= 1'b0;
        end else begin
            cmd_en      <= 1'b0;
            wr_data_en  <= 1'b0;
            wr_data_end <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    fail <= 1'b0;
                    if (enable) begin
                        if (!$value$plusargs("PATTERN=%d", pattern_mode))
                            pattern_mode <= 0;
                        if (!$value$plusargs("INJECT=%d", inject_enable))
                            inject_enable <= 0;
                        if (!$value$plusargs("INJECT_MODE=%d", inject_mode))
                            inject_mode <= 0;
                        if (!$value$plusargs("INJECT_BIT=%d", inject_bit))
                            inject_bit <= 0;
                        if (!$value$plusargs("SEED=%d", seed))
                            seed <= 32'h12345678;
                        if (!$value$plusargs("TEST_ADDR=%h", test_addr))
                            test_addr <= 28'h0000020;
                        state <= S_WAIT_CAL;
                    end
                end

                S_WAIT_CAL: begin
                    if (init_calib_complete) begin
                        expected_data <= make_pattern(pattern_mode, seed);
                        $display("[%0t] INFO: FAULTSCAN start addr=%h pattern=%h",
                                 $time, test_addr, make_pattern(pattern_mode, seed));
                        state <= S_WRITE;
                    end
                end

                S_WRITE: begin
                    if (cmd_ready && wr_data_rdy) begin
                        cmd          <= CMD_WRITE;
                        cmd_en       <= 1'b1;
                        addr         <= test_addr;
                        wr_data      <= expected_data;
                        wr_data_en   <= 1'b1;
                        wr_data_end  <= 1'b1;
                        wr_data_mask <= 16'h0000;
                        state <= S_GAP;
                        cnt   <= 32'd0;
                    end
                end

                S_GAP: begin
                    cnt <= cnt + 1'b1;
                    if (cnt == 32'd16)
                        state <= S_READ;
                end

                S_READ: begin
                    if (cmd_ready) begin
                        cmd    <= CMD_READ;
                        cmd_en <= 1'b1;
                        addr   <= test_addr;
                        state  <= S_WAIT_RD;
                        cnt    <= 32'd0;
                    end
                end

                S_WAIT_RD: begin
                    cnt <= cnt + 1'b1;
                    if (rd_data_valid) begin
                        compare_data = inject_fault(rd_data, inject_enable, inject_mode, inject_bit, seed);
                        error_bits = 0;
                        for (i = 0; i < 128; i = i + 1) begin
                            if (compare_data[i] !== expected_data[i])
                                error_bits = error_bits + 1;
                        end

                        $display("[%0t] INFO: readback raw=%h compare=%h expected=%h error_bits=%0d",
                                 $time, rd_data, compare_data, expected_data, error_bits);

                        if (error_bits == 0) begin
                            $display("[%0t] PASS: FAULTSCAN no error detected", $time);
                            state <= S_DONE;
                        end else begin
                            $display("[%0t] INFO: FAULTSCAN detected %0d error bits", $time, error_bits);
                            state <= S_FAIL;
                        end
                    end else if (cnt == 32'd2000) begin
                        $display("[%0t] FAIL: timeout waiting rd_data_valid", $time);
                        state <= S_FAIL;
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