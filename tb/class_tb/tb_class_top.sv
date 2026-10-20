// =============================================================================
// Top-Level Testbench: tb_class_top
// Description: Instantiates DUT and executes Class-Based Verification Environment
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

`include "fifo_env.sv"

module tb_class_top;

    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned ADDR_WIDTH = 4;
    localparam int unsigned DEPTH      = 1 << ADDR_WIDTH;

    // Independent Asynchronous Clocks
    // wclk: 100 MHz (10ns), rclk: 66.6 MHz (15ns)
    localparam time WCLK_PERIOD = 10ns;
    localparam time RCLK_PERIOD = 15ns;

    logic wclk = 0;
    logic rclk = 0;

    // Clock Generation
    always #(WCLK_PERIOD / 2) wclk = ~wclk;
    always #(RCLK_PERIOD / 2) rclk = ~rclk;

    // Interface instantiation
    fifo_if #(DATA_WIDTH) intf (
        .wclk (wclk),
        .rclk (rclk)
    );

    // DUT instantiation
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .wclk   (intf.wclk),
        .wrst_n (intf.wrst_n),
        .winc   (intf.winc),
        .wdata  (intf.wdata),
        .wfull  (intf.wfull),
        .rclk   (intf.rclk),
        .rrst_n (intf.rrst_n),
        .rinc   (intf.rinc),
        .rdata  (intf.rdata),
        .rempty (intf.rempty)
    );

    // Environment handle
    fifo_env #(DATA_WIDTH) env;

    initial begin
        $dumpfile("waves/dump_class_tb.vcd");
        $dumpvars(0, tb_class_top);

        $display("\n=================================================================");
        $display("[TB_CLASS_TOP] Launching SystemVerilog Class-Based Test Environment");
        $display("  Configuration: DATA_WIDTH=%0d, ADDR_WIDTH=%0d (DEPTH=%0d)",
                 DATA_WIDTH, ADDR_WIDTH, DEPTH);
        $display("  Clock Rates: wclk=100MHz (%0t), rclk=66.6MHz (%0t)", 
                 WCLK_PERIOD, RCLK_PERIOD);
        $display("=================================================================");

        // Construct and build environment
        env = new(intf);
        env.build();

        // Execute reset sequence
        env.reset();

        // Launch infrastructure (monitors, drivers, scoreboard)
        env.start_infrastructure();

        // ---------------------------------------------------------------------
        // Test Sequence 1: Corner-case Data Patterns (Zeros, Ones, 0xAA, 0x55, Walking 1/0)
        // ---------------------------------------------------------------------
        $display("\n[STAGE 1] Testing Corner-Case Data Patterns (24 items)...");
        env.gen.gen_pattern_writes(24);
        env.gen.gen_reads(24);

        // Wait until all 24 items are processed
        wait(env.scb.rd_count == 24);
        $display("[STAGE 1] Completed.");

        // ---------------------------------------------------------------------
        // Test Sequence 2: Multiple Wraparound Stress (64 items through Depth=16 FIFO)
        // ---------------------------------------------------------------------
        $display("\n[STAGE 2] Testing Pointer Wraparound Stress (64 items across 4 buffer cycles)...");
        env.gen.gen_writes(64);
        env.gen.gen_reads(64);

        wait(env.scb.rd_count == 88);
        $display("[STAGE 2] Completed.");

        // ---------------------------------------------------------------------
        // Test Sequence 3: Randomized Bursts & Concurrent Simultaneous Read/Write
        // ---------------------------------------------------------------------
        $display("\n[STAGE 3] Testing Concurrent Traffic & Random Stalls (100 items)...");
        env.gen.gen_writes(100);
        env.gen.gen_reads(100);

        wait(env.scb.rd_count == 188);
        $display("[STAGE 3] Completed.");

        // Allow pipeline and synchronizers to settle into quiet state
        repeat (10) @(posedge rclk);

        // Scoreboard Final Assessment
        env.scb.report();

        $finish;
    end

endmodule

`default_nettype wire
