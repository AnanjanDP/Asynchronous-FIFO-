// =============================================================================
// Testbench: tb_basic
// Description: Directed, self-checking basic smoke testbench for async_fifo
//
// Test Scenarios Covered:
//   1. Power-on reset & initial flag verification (rempty=1, wfull=0).
//   2. Single write followed by CDC synchronization and single read.
//   3. Sequential burst writes to fill FIFO to capacity (16 entries).
//   4. Overflow attempt: write to full FIFO (verify write rejected).
//   5. Sequential burst reads to empty FIFO (verify data ordering & integrity).
//   6. Underflow attempt: read from empty FIFO (verify read rejected).
//   7. VCD waveform dumping for GTKWave inspection.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_basic;

    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned ADDR_WIDTH = 4;
    localparam int unsigned DEPTH      = 1 << ADDR_WIDTH;

    // Asymmetric clock periods (asynchronous clocks)
    // wclk = 100 MHz (10ns period), rclk = 71.4 MHz (14ns period)
    localparam time WCLK_PERIOD = 10ns;
    localparam time RCLK_PERIOD = 14ns;

    // DUT Signals
    logic                  wclk;
    logic                  wrst_n;
    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;

    logic                  rclk;
    logic                  rrst_n;
    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // Test tracking
    int unsigned error_count = 0;
    int unsigned test_count  = 0;

    // Instantiate DUT
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    // -------------------------------------------------------------------------
    // Clock Generation (Independent asynchronous clocks with phase offsets)
    // -------------------------------------------------------------------------
    initial begin
        wclk = 1'b0;
        forever #(WCLK_PERIOD / 2) wclk = ~wclk;
    end

    initial begin
        rclk = 1'b0;
        #2ns; // Initial phase offset between domains
        forever #(RCLK_PERIOD / 2) rclk = ~rclk;
    end

    // -------------------------------------------------------------------------
    // Helper Tasks for Synchronous Driving
    // -------------------------------------------------------------------------
    task automatic write_byte(input logic [DATA_WIDTH-1:0] data);
        @(posedge wclk);
        winc  <= 1'b1;
        wdata <= data;
        @(posedge wclk);
        winc  <= 1'b0;
        wdata <= '0;
    endtask

    // Use standard array model for reference storage
    logic [DATA_WIDTH-1:0] read_val;
    logic [DATA_WIDTH-1:0] expected_mem [0:DEPTH-1];
    int exp_wr_idx;
    int exp_rd_idx;

    // Helper task with correct FWFT sampling
    task automatic read_byte_fwft(output logic [DATA_WIDTH-1:0] data);
        @(posedge rclk);
        data = rdata;  // Sample data at head of FIFO
        rinc <= 1'b1;  // Request pop
        @(posedge rclk);
        rinc <= 1'b0;
    endtask

    initial begin
        // Configure waveform dump
        $dumpfile("waves/dump_basic.vcd");
        $dumpvars(0, tb_basic);

        $display("-----------------------------------------------------------------");
        $display("[TB_BASIC] Starting Asynchronous FIFO Directed Smoke Test Suite");
        $display("  Configuration: DATA_WIDTH=%0d, ADDR_WIDTH=%0d (DEPTH=%0d)", 
                 DATA_WIDTH, ADDR_WIDTH, DEPTH);
        $display("  Clocks: wclk period = %0t, rclk period = %0t", WCLK_PERIOD, RCLK_PERIOD);
        $display("-----------------------------------------------------------------");

        // Initialization
        winc       = 1'b0;
        wdata      = '0;
        wrst_n     = 1'b0;
        rinc       = 1'b0;
        rrst_n     = 1'b0;
        exp_wr_idx = 0;
        exp_rd_idx = 0;

        // Apply reset for 4 clock periods
        #(WCLK_PERIOD * 4);
        @(posedge wclk) wrst_n <= 1'b1;
        @(posedge rclk) rrst_n <= 1'b1;
        #(WCLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // Test 1: Reset state verification
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 1] Verifying Reset States...");
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty not asserted after reset! rempty=%b", rempty);
            error_count++;
        end else begin
            $display("[PASS] rempty asserted high after reset.");
        end

        if (wfull !== 1'b0) begin
            $error("[FAIL] wfull asserted after reset! wfull=%b", wfull);
            error_count++;
        end else begin
            $display("[PASS] wfull asserted low after reset.");
        end

        // ---------------------------------------------------------------------
        // Test 2: Single Write followed by Single Read
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 2] Single Write (0xA5) and Readback...");
        write_byte(8'hA5);

        // Wait for 2-FF synchronizer latency into rclk domain (at least 3 rclk cycles)
        repeat (4) @(posedge rclk);

        if (rempty !== 1'b0) begin
            $error("[FAIL] rempty failed to deassert after write! rempty=%b", rempty);
            error_count++;
        end else begin
            $display("[PASS] rempty successfully deasserted after write.");
        end

        // Check FWFT / combinational read data
        if (rdata !== 8'hA5) begin
            $error("[FAIL] rdata mismatch before pop! expected=0xA5, got=0x%02h", rdata);
            error_count++;
        end else begin
            $display("[PASS] rdata correctly reflects 0xA5 at head of FIFO.");
        end

        // Pop data
        read_byte_fwft(read_val);
        repeat (3) @(posedge rclk);

        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty failed to assert after popping only element! rempty=%b", rempty);
            error_count++;
        end else begin
            $display("[PASS] rempty asserted after reading only element.");
        end

        // ---------------------------------------------------------------------
        // Test 3: Fill FIFO to full capacity (DEPTH = 16)
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 3] Filling FIFO to full capacity (%0d writes)...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            logic [DATA_WIDTH-1:0] test_val;
            test_val = 8'h10 + i;
            expected_mem[i] = test_val;
            write_byte(test_val);
        end

        // Wait 1 cycle for wfull flag to update
        @(posedge wclk);
        if (wfull !== 1'b1) begin
            $error("[FAIL] wfull not asserted after %0d writes! wfull=%b", DEPTH, wfull);
            error_count++;
        end else begin
            $display("[PASS] wfull asserted high after %0d writes.", DEPTH);
        end

        // ---------------------------------------------------------------------
        // Test 4: Attempt write when full (Overflow guard check)
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 4] Attempting illegal write when FULL...");
        write_byte(8'hFF); // Should be dropped/ignored
        @(posedge wclk);
        if (wfull !== 1'b1) begin
            $error("[FAIL] wfull dropped unexpectedly after overflow attempt!");
            error_count++;
        end else begin
            $display("[PASS] FIFO maintained wfull=1 and rejected illegal write.");
        end

        // ---------------------------------------------------------------------
        // Test 5: Drain FIFO to empty and verify ordering
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 5] Draining FIFO and verifying FIFO ordering...");
        for (int i = 0; i < DEPTH; i++) begin
            logic [DATA_WIDTH-1:0] exp;
            exp = expected_mem[i];
            read_byte_fwft(read_val);
            if (read_val !== exp) begin
                $error("[FAIL] Data mismatch at index %0d! Expected=0x%02h, Got=0x%02h", 
                       i, exp, read_val);
                error_count++;
            end else begin
                $display("  [POP %02d] Data match: 0x%02h", i, read_val);
            end
        end

        // Allow CDC synchronizer to update rempty in rclk domain
        repeat (3) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty not asserted after draining all %0d items! rempty=%b", 
                   DEPTH, rempty);
            error_count++;
        end else begin
            $display("[PASS] All %0d items popped in exact order. rempty=1 verified.", DEPTH);
        end

        // Also check that write domain sees wfull drop after synchronization
        repeat (4) @(posedge wclk);
        if (wfull !== 1'b0) begin
            $error("[FAIL] wfull failed to drop after drain! wfull=%b", wfull);
            error_count++;
        end else begin
            $display("[PASS] wfull dropped to 0 in wclk domain after drain.");
        end

        // ---------------------------------------------------------------------
        // Test 6: Attempt read when empty (Underflow guard check)
        // ---------------------------------------------------------------------
        test_count++;
        $display("\n[TEST 6] Attempting illegal read when EMPTY...");
        read_byte_fwft(read_val);
        repeat (2) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty dropped after illegal read attempt!");
            error_count++;
        end else begin
            $display("[PASS] FIFO maintained rempty=1 and rejected illegal read.");
        end

        // ---------------------------------------------------------------------
        // Summary & Exit Code
        // ---------------------------------------------------------------------
        $display("\n=================================================================");
        if (error_count == 0) begin
            $display("[RESULT] ALL %0d TESTS PASSED SUCCESSFULLY! (Zero errors)", test_count);
        end else begin
            $display("[RESULT] TEST SUITE FAILED with %0d errors across %0d tests.", 
                     error_count, test_count);
        end
        $display("=================================================================\n");

        $finish(error_count == 0 ? 0 : 1);
    end

endmodule

`default_nettype wire
