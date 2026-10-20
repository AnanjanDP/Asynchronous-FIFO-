// =============================================================================
// Module: rptr_empty
// Description: Read Pointer & Empty Flag Generation Logic
//
// Features:
// - Generates binary address (raddr) for memory read port.
// - Maintains binary counter (rbin) and Gray-coded pointer (rptr).
// - Receives synchronized Gray-coded write pointer (rq2_wptr) from wclk domain.
// - Computes registered glitch-free rempty flag.
// - Prevents underflow: suppresses pointer increments when rempty is active.
//
// Empty Condition:
// The FIFO is empty when the read pointer reaches the synchronized write pointer:
//   rempty_val = (rptr_next == rq2_wptr);
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module rptr_empty #(
    parameter int unsigned ADDR_WIDTH = 4
)(
    input  logic                    rclk,
    input  logic                    rrst_n,
    input  logic                    rinc,
    input  logic [ADDR_WIDTH:0]     rq2_wptr, // Synchronized write pointer (Gray)
    output logic                    rempty,
    output logic [ADDR_WIDTH-1:0]   raddr,
    output logic [ADDR_WIDTH:0]     rptr      // Read pointer (Gray)
);

    logic [ADDR_WIDTH:0] rbin;
    logic [ADDR_WIDTH:0] rbin_next;
    logic [ADDR_WIDTH:0] rptr_next;
    logic                rempty_val;

    // 1. Binary increment logic (guarded against underflow)
    assign rbin_next = rbin + (rinc & ~rempty);

    // 2. Binary-to-Gray conversion
    assign rptr_next = (rbin_next >> 1) ^ rbin_next;

    // 3. Memory address derived from lower binary bits
    assign raddr = rbin[ADDR_WIDTH-1:0];

    // 4. Empty flag comparison (evaluated using next pointer value)
    assign rempty_val = (rptr_next == rq2_wptr);

    // 5. Sequential registers for pointers and registered rempty
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= '0;
            rptr   <= '0;
            rempty <= 1'b1; // FIFO must power up / reset into EMPTY state
        end else begin
            rbin   <= rbin_next;
            rptr   <= rptr_next;
            rempty <= rempty_val;
        end
    end

endmodule

`default_nettype wire
