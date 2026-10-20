// =============================================================================
// Module: wptr_full
// Description: Write Pointer & Full Flag Generation Logic
//
// Features:
// - Generates binary address (waddr) for memory write port.
// - Maintains binary counter (wbin) and Gray-coded pointer (wptr).
// - Receives synchronized Gray-coded read pointer (wq2_rptr) from rclk domain.
// - Computes registered glitch-free wfull flag.
// - Prevents overflow: suppresses pointer increments when wfull is active.
//
// Full Condition in Gray Code:
// When write wraps around read by exactly one full buffer (Depth = 2^ADDR_WIDTH):
// - The MSB is inverted: wptr[ADDR_WIDTH] != wq2_rptr[ADDR_WIDTH]
// - The 2nd MSB is inverted: wptr[ADDR_WIDTH-1] != wq2_rptr[ADDR_WIDTH-1]
// - All lower bits are identical: wptr[ADDR_WIDTH-2:0] == wq2_rptr[ADDR_WIDTH-2:0]
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module wptr_full #(
    parameter int unsigned ADDR_WIDTH = 4
)(
    input  logic                    wclk,
    input  logic                    wrst_n,
    input  logic                    winc,
    input  logic [ADDR_WIDTH:0]     wq2_rptr, // Synchronized read pointer (Gray)
    output logic                    wfull,
    output logic [ADDR_WIDTH-1:0]   waddr,
    output logic [ADDR_WIDTH:0]     wptr      // Write pointer (Gray)
);

    logic [ADDR_WIDTH:0] wbin;
    logic [ADDR_WIDTH:0] wbin_next;
    logic [ADDR_WIDTH:0] wptr_next;
    logic                wfull_val;

    // 1. Binary increment logic (guarded against overflow)
    assign wbin_next = wbin + (winc & ~wfull);

    // 2. Binary-to-Gray conversion
    assign wptr_next = (wbin_next >> 1) ^ wbin_next;

    // 3. Memory address derived from lower binary bits
    assign waddr = wbin[ADDR_WIDTH-1:0];

    // 4. Gray-code Full Flag Comparison (parameter-safe for ADDR_WIDTH >= 1)
    generate
        if (ADDR_WIDTH > 1) begin : gen_multi_bit_full
            assign wfull_val = (wptr_next == {~wq2_rptr[ADDR_WIDTH : ADDR_WIDTH-1],
                                               wq2_rptr[ADDR_WIDTH-2 : 0]});
        end else begin : gen_single_bit_full
            // When ADDR_WIDTH == 1 (Depth = 2, pointer width = 2), both bits are inverted
            assign wfull_val = (wptr_next == ~wq2_rptr[1:0]);
        end
    endgenerate

    // 5. Sequential registers for pointers and registered wfull
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= '0;
            wptr  <= '0;
            wfull <= 1'b0; // FIFO must power up / reset into NOT-FULL state
        end else begin
            wbin  <= wbin_next;
            wptr  <= wptr_next;
            wfull <= wfull_val;
        end
    end

endmodule

`default_nettype wire
