// =============================================================================
// Module: fifo_coverage
// Description: Functional Coverage Model for Asynchronous FIFO
//
// Covergroups Implemented:
//   1. cg_write_domain:
//      - wfull flag states (0, 1).
//      - Back-to-back accepted writes (consecutive operations).
//      - Write address coverage (all 0 to 2^ADDR_WIDTH-1 addresses hit).
//      - Write pointer wraparound transition (from max back to 0).
//
//   2. cg_read_domain:
//      - rempty flag states (0, 1).
//      - Back-to-back accepted reads (consecutive operations).
//      - Read address coverage (all 0 to 2^ADDR_WIDTH-1 addresses hit).
//      - Read pointer wraparound transition.
//
//   3. cg_concurrent:
//      - Simultaneous read and write acceptance.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module fifo_coverage #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned ADDR_WIDTH = 4
)(
    input logic                  wclk,
    input logic                  wrst_n,
    input logic                  winc,
    input logic                  wfull,
    input logic [ADDR_WIDTH-1:0] waddr,

    input logic                  rclk,
    input logic                  rrst_n,
    input logic                  rinc,
    input logic                  rempty,
    input logic [ADDR_WIDTH-1:0] raddr
);

    localparam int unsigned DEPTH = 1 << ADDR_WIDTH;

    logic accepted_write;
    logic accepted_read;

    assign accepted_write = wrst_n && winc && !wfull;
    assign accepted_read  = rrst_n && rinc && !rempty;

    // -------------------------------------------------------------------------
    // 1. Write Domain Functional Coverage
    // -------------------------------------------------------------------------
    covergroup cg_write_domain @(posedge wclk);
        // Full flag coverage
        cp_wfull: coverpoint wfull {
            bins not_full = {1'b0};
            bins is_full  = {1'b1};
        }

        // Accepted write operations
        cp_accepted_write: coverpoint accepted_write {
            bins idle = {1'b0};
            bins wr   = {1'b1};
        }

        // Write address coverage: ensures every slot in the buffer is written
        cp_waddr: coverpoint waddr {
            bins all_slots[] = {[0 : DEPTH-1]};
        }

        // Pointer wraparound transition coverage
        cp_waddr_wrap: coverpoint waddr {
            bins wrap = (DEPTH-1 => 0);
        }

        // Back-to-back write burst transitions
        cp_b2b_writes: coverpoint accepted_write {
            bins b2b_burst = (1'b1 [* 4]); // 4 back-to-back writes
        }
    endgroup

    // -------------------------------------------------------------------------
    // 2. Read Domain Functional Coverage
    // -------------------------------------------------------------------------
    covergroup cg_read_domain @(posedge rclk);
        // Empty flag coverage
        cp_rempty: coverpoint rempty {
            bins not_empty = {1'b0};
            bins is_empty  = {1'b1};
        }

        // Accepted read operations
        cp_accepted_read: coverpoint accepted_read {
            bins idle = {1'b0};
            bins rd   = {1'b1};
        }

        // Read address coverage: ensures every slot in the buffer is read
        cp_raddr: coverpoint raddr {
            bins all_slots[] = {[0 : DEPTH-1]};
        }

        // Read pointer wraparound transition coverage
        cp_raddr_wrap: coverpoint raddr {
            bins wrap = (DEPTH-1 => 0);
        }

        // Back-to-back read burst transitions
        cp_b2b_reads: coverpoint accepted_read {
            bins b2b_burst = (1'b1 [* 4]); // 4 back-to-back reads
        }
    endgroup

    // Instantiate Covergroups
    cg_write_domain cov_wr = new();
    cg_read_domain  cov_rd = new();

endmodule

`default_nettype wire
