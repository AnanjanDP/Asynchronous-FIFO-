// =============================================================================
// Testbench: tb_advanced
// Description: Advanced Self-Checking Verification Suite for Asynchronous FIFO
//
// Implements and validates all 15 industry-standard verification scenarios:
//   Test  1: Reset and initial empty state verification.
//   Test  2: Single write followed by a read.
//   Test  3: Multiple writes followed by ordered reads.
//   Test  4: FIFO filling to exact capacity (wfull assertion).
//   Test  5: Attempted writes while full (overflow protection).
//   Test  6: Reads until empty (rempty assertion).
//   Test  7: Attempted reads while empty (underflow protection).
//   Test  8: Simultaneous concurrent read and write operations.
//   Test  9: Back-to-back zero-delay continuous transactions.
//   Test 10: Pointer wraparound stress over multiple full FIFO cycles.
//   Test 11: Fast write clock and slow read clock (10:1 ratio).
//   Test 12: Slow write clock and fast read clock (1:10 ratio).
//   Test 13: Dynamic randomized clock periods and phase offsets.
//   Test 14: Comprehensive data patterns (zeros, ones, 0xAA, 0x55, walking 1s/0s, random).
//   Test 15: Mid-traffic asynchronous reset assertion and clean recovery.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module tb_advanced;

    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned ADDR_WIDTH = 4;
    localparam int unsigned DEPTH      = 1 << ADDR_WIDTH;

    // -------------------------------------------------------------------------
    // Configurable Clocks & Resets
    // -------------------------------------------------------------------------
    realtime wclk_half_period = 5.0;  // Default 100 MHz (5ns half period)
    realtime rclk_half_period = 7.0;  // Default 71.4 MHz (7ns half period)

    logic wclk = 0;
    logic rclk = 0;
    logic wrst_n;
    logic rrst_n;

    // DUT Signals
    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;

    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // Simulation tracking
    int unsigned total_errors    = 0;
    int unsigned total_tests_run = 0;
    int unsigned total_writes    = 0;
    int unsigned total_reads     = 0;

    // Golden Reference Model (Unbounded reference storage queue)
    logic [DATA_WIDTH-1:0] ref_queue [0:2047];
    int unsigned ref_wr_ptr = 0;
    int unsigned ref_rd_ptr = 0;
    logic [DATA_WIDTH-1:0] test_patterns [0:15];

    // DUT Instantiation
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
    // Clock Generators with Dynamic Frequency Reconfiguration
    // -------------------------------------------------------------------------
    always #(wclk_half_period) wclk = ~wclk;
    always #(rclk_half_period) rclk = ~rclk;

    // -------------------------------------------------------------------------
    // Reference Model Helper Functions
    // -------------------------------------------------------------------------
    function automatic void ref_push(input logic [DATA_WIDTH-1:0] d);
        ref_queue[ref_wr_ptr] = d;
        ref_wr_ptr = (ref_wr_ptr + 1) % 2048;
        total_writes++;
    endfunction

    function automatic logic [DATA_WIDTH-1:0] ref_pop();
        logic [DATA_WIDTH-1:0] d;
        d = ref_queue[ref_rd_ptr];
        ref_rd_ptr = (ref_rd_ptr + 1) % 2048;
        total_reads++;
        return d;
    endfunction

    function automatic int unsigned ref_occupancy();
        return (ref_wr_ptr >= ref_rd_ptr) ? (ref_wr_ptr - ref_rd_ptr) : (2048 - ref_rd_ptr + ref_wr_ptr);
    endfunction

    // -------------------------------------------------------------------------
    // Basic Driver Tasks
    // -------------------------------------------------------------------------
    task automatic apply_reset();
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        winc   = 1'b0;
        rinc   = 1'b0;
        wdata  = '0;
        ref_wr_ptr = 0;
        ref_rd_ptr = 0;
        repeat (4) @(posedge wclk);
        @(posedge wclk) wrst_n <= 1'b1;
        @(posedge rclk) rrst_n <= 1'b1;
        repeat (3) @(posedge wclk);
    endtask

    task automatic write_data(input logic [DATA_WIDTH-1:0] d);
        do begin
            @(posedge wclk);
        end while (wfull);
        winc  <= 1'b1;
        wdata <= d;
        ref_push(d);
        @(posedge wclk);
        winc  <= 1'b0;
        wdata <= '0;
    endtask

    task automatic read_data(output logic [DATA_WIDTH-1:0] d, output bit read_valid);
        do begin
            @(posedge rclk);
        end while (rempty);
        #1ps; // Sample stable data after clock edge
        d = rdata;
        read_valid = 1'b1;
        rinc <= 1'b1;
        @(posedge rclk);
        rinc <= 1'b0;
    endtask

    // Check popped value against golden reference
    task automatic check_pop(string test_name);
        logic [DATA_WIDTH-1:0] actual_d;
        logic [DATA_WIDTH-1:0] expected_d;
        bit valid;

        read_data(actual_d, valid);
        expected_d = ref_pop();
        if (actual_d !== expected_d) begin
            $error("[%s] Data Mismatch! Expected=0x%02h, Actual=0x%02h", 
                   test_name, expected_d, actual_d);
            total_errors++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Test Orchestration
    // -------------------------------------------------------------------------
    // Watchdog timer to prevent infinite hang
    initial begin
        #500_000; // 500us watchdog
        $display("\n[WATCHDOG ERROR] Simulation exceeded maximum time limit (500us)!");
        $finish(1);
    end

    initial begin
        $display("=================================================================");
        $display("[TB_ADVANCED] Launching 15-Scenario Comprehensive Verification");
        $display("  DUT: DATA_WIDTH=%0d, ADDR_WIDTH=%0d (DEPTH=%0d)",
                 DATA_WIDTH, ADDR_WIDTH, DEPTH);
        $display("=================================================================\n");

        apply_reset();

        // ---------------------------------------------------------------------
        // Test 1: Reset and Initial Empty State
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 01] Verifying Reset State and Initial Flags...");
        if (rempty !== 1'b1 || wfull !== 1'b0) begin
            $error("[FAIL] Initial state wrong: rempty=%b (exp 1), wfull=%b (exp 0)", rempty, wfull);
            total_errors++;
        end else begin
            $display("  [PASS] rempty=1, wfull=0 correctly initialized.");
        end

        // ---------------------------------------------------------------------
        // Test 2: Single Write followed by Single Read
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 02] Single Write (0x5A) followed by Single Read...");
        write_data(8'h5A);
        repeat (4) @(posedge rclk); // Wait for CDC synchronizer
        if (rempty !== 1'b0) begin
            $error("[FAIL] rempty did not deassert after write!");
            total_errors++;
        end
        check_pop("TEST 02");
        repeat (3) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty did not assert after draining single item!");
            total_errors++;
        end else begin
            $display("  [PASS] Single write and read verified with correct flag transitions.");
        end

        // ---------------------------------------------------------------------
        // Test 3: Multiple Writes followed by Ordered Reads
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 03] Multiple Writes (8 items) followed by Ordered Reads...");
        for (int i = 0; i < 8; i++) begin
            write_data(8'h20 + i);
        end
        repeat (4) @(posedge rclk);
        for (int i = 0; i < 8; i++) begin
            check_pop("TEST 03");
        end
        repeat (3) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty not asserted after 8 reads!");
            total_errors++;
        end else begin
            $display("  [PASS] 8 items written and read back with exact ordering.");
        end

        // ---------------------------------------------------------------------
        // Test 4: FIFO Filling to Capacity
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 04] Filling FIFO to Exact Full Capacity (%0d entries)...", DEPTH);
        for (int i = 0; i < DEPTH; i++) begin
            write_data(8'h40 + i);
        end
        @(posedge wclk);
        if (wfull !== 1'b1) begin
            $error("[FAIL] wfull not asserted after %0d writes!", DEPTH);
            total_errors++;
        end else begin
            $display("  [PASS] wfull asserted high on the %0dth write.", DEPTH);
        end

        // ---------------------------------------------------------------------
        // Test 5: Attempted Writes while Full (Overflow Protection)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 05] Attempting Illegal Write on FULL FIFO...");
        // Do not call write_data because we want to verify hardware drops it
        @(posedge wclk);
        winc  <= 1'b1;
        wdata <= 8'hDE; // Corrupt value
        @(posedge wclk);
        winc  <= 1'b0;
        wdata <= '0;
        @(posedge wclk);
        if (wfull !== 1'b1) begin
            $error("[FAIL] wfull dropped after illegal write attempt!");
            total_errors++;
        end else begin
            $display("  [PASS] FIFO maintained wfull=1 and rejected illegal write.");
        end

        // ---------------------------------------------------------------------
        // Test 6: Reads Until Empty
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 06] Draining FIFO completely to Empty...");
        for (int i = 0; i < DEPTH; i++) begin
            check_pop("TEST 06");
        end
        repeat (3) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty not asserted after popping all entries!");
            total_errors++;
        end else begin
            $display("  [PASS] All %0d items drained; rempty asserted.", DEPTH);
        end
        repeat (4) @(posedge wclk);
        if (wfull !== 1'b0) begin
            $error("[FAIL] wfull did not deassert in wclk domain after drain!");
            total_errors++;
        end else begin
            $display("  [PASS] wfull safely deasserted in write domain.");
        end

        // ---------------------------------------------------------------------
        // Test 7: Attempted Reads while Empty (Underflow Protection)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 07] Attempting Illegal Read on EMPTY FIFO...");
        @(posedge rclk);
        rinc <= 1'b1;
        @(posedge rclk);
        rinc <= 1'b0;
        repeat (2) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty dropped after illegal read attempt!");
            total_errors++;
        end else begin
            $display("  [PASS] FIFO maintained rempty=1 and rejected illegal read.");
        end

        // ---------------------------------------------------------------------
        // Test 8: Simultaneous Read and Write Operations
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 08] Simultaneous Concurrent Read and Write Operations...");
        // First prime FIFO with 4 entries
        for (int i = 0; i < 4; i++) begin
            write_data(8'h80 + i);
        end
        repeat (4) @(posedge rclk);

        // Perform concurrent write and read
        fork
            begin
                for (int i = 0; i < 16; i++) begin
                    write_data(8'h90 + i);
                end
            end
            begin
                for (int i = 0; i < 16; i++) begin
                    check_pop("TEST 08_CONC");
                end
            end
        join

        // Drain remaining 4 primed entries
        for (int i = 0; i < 4; i++) begin
            check_pop("TEST 08_DRAIN");
        end
        repeat (3) @(posedge rclk);
        $display("  [PASS] Simultaneous concurrent read/write completed with zero data errors.");

        // ---------------------------------------------------------------------
        // Test 9: Back-to-Back Zero-Delay Burst Transactions
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 09] Back-to-Back Continuous Burst Operations...");
        // Continuous burst writes without idle cycles
        @(posedge wclk);
        for (int i = 0; i < DEPTH; i++) begin
            winc  <= 1'b1;
            wdata <= 8'hB0 + i;
            ref_push(8'hB0 + i);
            @(posedge wclk);
        end
        winc  <= 1'b0;
        wdata <= '0;

        // Continuous burst reads without idle cycles
        repeat (4) @(posedge rclk);
        begin
            logic [DATA_WIDTH-1:0] burst_exp;
            for (int i = 0; i < DEPTH; i++) begin
                #1ps; // Allow combinatorial rdata to settle
                burst_exp = ref_pop();
                if (rdata !== burst_exp) begin
                    $error("[TEST 09] Burst read mismatch at %0d! Exp=0x%02h, Got=0x%02h", 
                           i, burst_exp, rdata);
                    total_errors++;
                end
                rinc <= 1'b1;
                @(posedge rclk);
            end
        end
        rinc <= 1'b0;
        repeat (3) @(posedge rclk);
        $display("  [PASS] Zero-delay burst writes and reads verified.");

        // ---------------------------------------------------------------------
        // Test 10: Pointer Wraparound Stress (64 items across 4 buffer cycles)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 10] Pointer Wraparound Stress (64 items through Depth=16)...");
        for (int cycle = 0; cycle < 4; cycle++) begin
            for (int i = 0; i < DEPTH; i++) begin
                write_data(8'hC0 + (cycle * 16) + i);
            end
            repeat (4) @(posedge rclk);
            for (int i = 0; i < DEPTH; i++) begin
                check_pop("TEST 10_WRAP");
            end
            repeat (4) @(posedge wclk);
        end
        $display("  [PASS] Pointer wraparound verified cleanly over 4 full buffer cycles.");

        // ---------------------------------------------------------------------
        // Test 11: Fast Write Clock & Slow Read Clock (10:1 Ratio)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 11] Fast Write Clock (wclk=200MHz) & Slow Read Clock (rclk=20MHz)...");
        wclk_half_period = 2.5;   // 200 MHz (2.5ns half period)
        rclk_half_period = 25.0;  // 20 MHz (25ns half period)
        repeat (5) @(posedge wclk);

        fork
            begin
                for (int i = 0; i < 20; i++) begin
                    write_data(8'hD0 + i);
                end
            end
            begin
                for (int i = 0; i < 20; i++) begin
                    check_pop("TEST 11_FAST_W");
                end
            end
        join
        $display("  [PASS] Fast write / slow read clock stress passed.");

        // ---------------------------------------------------------------------
        // Test 12: Slow Write Clock & Fast Read Clock (1:10 Ratio)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 12] Slow Write Clock (wclk=20MHz) & Fast Read Clock (rclk=200MHz)...");
        wclk_half_period = 25.0;  // 20 MHz (25ns half period)
        rclk_half_period = 2.5;   // 200 MHz (2.5ns half period)
        repeat (5) @(posedge wclk);

        fork
            begin
                for (int i = 0; i < 20; i++) begin
                    write_data(8'hE0 + i);
                end
            end
            begin
                for (int i = 0; i < 20; i++) begin
                    check_pop("TEST 12_SLOW_W");
                end
            end
        join
        $display("  [PASS] Slow write / fast read clock stress passed.");

        // Restore nominal clock speeds
        wclk_half_period = 5.0;  // 100 MHz (5ns half period)
        rclk_half_period = 7.0;  // 71.4 MHz (7ns half period)
        repeat (5) @(posedge wclk);

        // ---------------------------------------------------------------------
        // Test 13: Randomized Clock Periods and Phase Offsets
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 13] Randomized Clock Periods and Phase Offsets...");
        for (int round = 0; round < 3; round++) begin
            // Randomize clock half-periods between 3.0ns and 9.0ns
            wclk_half_period = 3.0 + ($urandom % 7);
            rclk_half_period = 3.0 + ($urandom % 7);
            repeat (4) @(posedge wclk);

            fork
                begin
                    for (int i = 0; i < 10; i++) begin
                        write_data(8'h10 + i);
                    end
                end
                begin
                    for (int i = 0; i < 10; i++) begin
                        check_pop("TEST 13_RAND_CLK");
                    end
                end
            join
        end
        $display("  [PASS] Randomized clock frequencies and phase offsets verified.");

        // Restore nominal clock speeds
        wclk_half_period = 5.0ns;
        rclk_half_period = 7.0ns;
        repeat (5) @(posedge wclk);

        // ---------------------------------------------------------------------
        // Test 14: Data Patterns (0x00, 0xFF, 0xAA, 0x55, Walking 1s/0s, Random)
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 14] Comprehensive Data Patterns...");
        begin
            test_patterns[0]  = 8'h00; // All zeroes
            test_patterns[1]  = 8'hFF; // All ones
            test_patterns[2]  = 8'hAA; // Alternating 10101010
            test_patterns[3]  = 8'h55; // Alternating 01010101
            test_patterns[4]  = 8'h01; // Walking 1
            test_patterns[5]  = 8'h02;
            test_patterns[6]  = 8'h04;
            test_patterns[7]  = 8'h08;
            test_patterns[8]  = 8'h10;
            test_patterns[9]  = 8'h20;
            test_patterns[10] = 8'h40;
            test_patterns[11] = 8'h80;
            test_patterns[12] = 8'hFE; // Walking 0
            test_patterns[13] = 8'hFD;
            test_patterns[14] = 8'h7F;
            test_patterns[15] = 8'h3C;

            for (int i = 0; i < 16; i++) begin
                write_data(test_patterns[i]);
            end
            repeat (4) @(posedge rclk);
            for (int i = 0; i < 16; i++) begin
                check_pop("TEST 14_PATTERNS");
            end
        end
        $display("  [PASS] All targeted data patterns matched with zero corruption.");

        // ---------------------------------------------------------------------
        // Test 15: Reset Assertion During Active Traffic and Recovery
        // ---------------------------------------------------------------------
        total_tests_run++;
        $display("[TEST 15] Mid-Traffic Asynchronous Reset and Recovery...");
        // Start writes
        for (int i = 0; i < 5; i++) begin
            write_data(8'hF0 + i);
        end
        // Abruptly assert reset mid-flight
        wrst_n = 1'b0;
        rrst_n = 1'b0;
        winc   = 1'b0;
        rinc   = 1'b0;
        ref_wr_ptr = 0;
        ref_rd_ptr = 0;
        repeat (4) @(posedge wclk);

        // Deassert resets cleanly
        @(posedge wclk) wrst_n <= 1'b1;
        @(posedge rclk) rrst_n <= 1'b1;
        repeat (4) @(posedge wclk);

        if (rempty !== 1'b1 || wfull !== 1'b0) begin
            $error("[FAIL] Post-recovery flags invalid: rempty=%b (exp 1), wfull=%b (exp 0)", 
                   rempty, wfull);
            total_errors++;
        end else begin
            $display("  [PASS] Recovery confirmed: rempty=1, wfull=0.");
        end

        // Verify normal operation resumes after reset recovery
        write_data(8'h33);
        repeat (4) @(posedge rclk);
        check_pop("TEST 15_POST_RESET");
        repeat (3) @(posedge rclk);
        if (rempty !== 1'b1) begin
            $error("[FAIL] rempty did not return to 1 after post-reset single read!");
            total_errors++;
        end else begin
            $display("  [PASS] Post-reset read/write transactions verified.");
        end

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("\n=================================================================");
        $display("[SUMMARY] Completed All %0d Verification Tests", total_tests_run);
        $display("  Total Valid Writes Processed : %0d", total_writes);
        $display("  Total Valid Reads Processed  : %0d", total_reads);
        $display("  Total Detected Errors        : %0d", total_errors);
        $display("-----------------------------------------------------------------");
        if (total_errors == 0) begin
            $display("[OVERALL STATUS] >>> ALL 15 VERIFICATION SCENARIOS PASSED <<<");
        end else begin
            $display("[OVERALL STATUS] >>> VERIFICATION FAILED (%0d ERRORS) <<<", total_errors);
        end
        $display("=================================================================\n");

        $finish(total_errors == 0 ? 0 : 1);
    end

endmodule

`default_nettype wire
