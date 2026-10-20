// =============================================================================
// Class: fifo_scoreboard
// Description: Golden Reference Scoreboard for Asynchronous FIFO Verification
//
// Key Features:
// - True asynchronous scoreboarding: Write and Read transactions arrive via
//   independent mailboxes in their respective clock domains.
// - Reference Model: Maintains an ideal unbounded SystemVerilog queue.
// - Checks:
//     1. Data Integrity: Verifies that popped data matches pushed data bit-for-bit.
//     2. Strict FIFO Ordering: Ensures no reordering or inversion occurs.
//     3. No Loss / Duplication: Every written item is popped exactly once.
//     4. Underflow Guard: Flags if a read occurs when the reference model is empty.
// =============================================================================

`ifndef FIFO_SCOREBOARD_SV
`define FIFO_SCOREBOARD_SV

`include "fifo_item.sv"

class fifo_scoreboard #(parameter int unsigned DATA_WIDTH = 8);

    mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx;
    mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx;

    // Golden Reference Queue
    logic [DATA_WIDTH-1:0] golden_queue[$];

    // Statistics Counters
    int unsigned wr_count       = 0;
    int unsigned rd_count       = 0;
    int unsigned match_count    = 0;
    int unsigned mismatch_count = 0;
    int unsigned underflow_err  = 0;

    function new(mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx,
                 mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx);
        this.wr_mbx = wr_mbx;
        this.rd_mbx = rd_mbx;
    endfunction

    // Run parallel listener threads for asynchronous domain events
    virtual task run();
        fork
            process_writes();
            process_reads();
        join
    endtask

    // Thread 1: Process incoming write domain transactions
    virtual task process_writes();
        fifo_item#(DATA_WIDTH) item;
        forever begin
            wr_mbx.get(item);
            golden_queue.push_back(item.data);
            wr_count++;
        end
    endtask

    // Thread 2: Process incoming read domain transactions
    virtual task process_reads();
        fifo_item#(DATA_WIDTH) item;
        logic [DATA_WIDTH-1:0] expected_data;

        forever begin
            rd_mbx.get(item);
            rd_count++;

            if (golden_queue.size() == 0) begin
                $error("[SCOREBOARD_ERROR] Read observed when golden reference model is EMPTY! Got=0x%02h", 
                       item.data);
                underflow_err++;
            end else begin
                expected_data = golden_queue.pop_front();
                if (item.data === expected_data) begin
                    match_count++;
                end else begin
                    $error("[SCOREBOARD_ERROR] Data mismatch! Exp=0x%02h, Got=0x%02h (Item #%0d)", 
                           expected_data, item.data, rd_count);
                    mismatch_count++;
                end
            end
        end
    endtask

    // Comprehensive final report
    virtual function void report();
        $display("\n=================================================================");
        $display("[SCOREBOARD] Final Asynchronous Verification Report");
        $display("-----------------------------------------------------------------");
        $display("  Total Accepted Writes (wclk) : %0d", wr_count);
        $display("  Total Accepted Reads  (rclk) : %0d", rd_count);
        $display("  Data Integrity Matches       : %0d", match_count);
        $display("  Data Mismatches              : %0d", mismatch_count);
        $display("  Underflow Violations         : %0d", underflow_err);
        $display("  Items Remaining in Queue     : %0d", golden_queue.size());
        $display("-----------------------------------------------------------------");

        if (mismatch_count == 0 && underflow_err == 0 && (wr_count == rd_count)) begin
            $display("[STATUS] SCOREBOARD VERIFICATION PASSED (Zero data errors)");
        end else begin
            $display("[STATUS] SCOREBOARD VERIFICATION FAILED (Errors detected)");
        end
        $display("=================================================================\n");
    endfunction

endclass

`endif // FIFO_SCOREBOARD_SV
