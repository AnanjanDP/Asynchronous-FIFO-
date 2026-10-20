// =============================================================================
// Module: async_fifo_sva
// Description: Concurrent SystemVerilog Assertions (SVA) for Asynchronous FIFO
//
// Verification Intent:
// - Formal and dynamic protocol invariant checking.
// - Clean separation between Write Clock Domain (wclk) and Read Clock Domain (rclk).
// - Validates that illegal operations are rejected and pointers obey CDC Gray invariants.
//
// CDC Assertion Note:
// Cross-domain properties cannot use synchronous concurrent assertions directly
// across two asynchronous clocks. Instead, assertions are strictly partitioned by
// domain, sampling local registered values and synchronized Gray pointers.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module async_fifo_sva #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned ADDR_WIDTH = 4
)(
    // Write Domain Signals
    input logic                  wclk,
    input logic                  wrst_n,
    input logic                  winc,
    input logic                  wfull,
    input logic [ADDR_WIDTH:0]   wbin,
    input logic [ADDR_WIDTH:0]   wptr,
    input logic [ADDR_WIDTH:0]   wq2_rptr,

    // Read Domain Signals
    input logic                  rclk,
    input logic                  rrst_n,
    input logic                  rinc,
    input logic                  rempty,
    input logic [ADDR_WIDTH:0]   rbin,
    input logic [ADDR_WIDTH:0]   rptr,
    input logic [ADDR_WIDTH:0]   rq2_wptr
);

    // =========================================================================
    // 1. WRITE CLOCK DOMAIN ASSERTIONS (Clocked on wclk)
    // =========================================================================

    // Property 1: Overflow Protection
    // An attempted write while FULL must NOT advance the write binary counter.
    property p_no_write_on_full;
        @(posedge wclk) disable iff (!wrst_n)
        (wfull && winc) |=> (wbin == $past(wbin));
    endproperty
    a_no_write_on_full: assert property (p_no_write_on_full)
        else $error("[SVA_FAIL][wclk] Write pointer advanced during FULL condition!");

    // Property 2: Write Pointer Increments on Accepted Write
    // An accepted write (winc && !wfull) MUST increment wbin by exactly 1.
    property p_wbin_inc_on_write;
        @(posedge wclk) disable iff (!wrst_n)
        (!wfull && winc) |=> (wbin == ($past(wbin) + 1'b1));
    endproperty
    a_wbin_inc_on_write: assert property (p_wbin_inc_on_write)
        else $error("[SVA_FAIL][wclk] Write pointer failed to increment on accepted write!");

    // Property 3: Write Pointer Stable when Idle
    // When no accepted write occurs, wbin must remain unchanged.
    property p_wbin_stable_when_idle;
        @(posedge wclk) disable iff (!wrst_n)
        (!winc || wfull) |=> (wbin == $past(wbin));
    endproperty
    a_wbin_stable_when_idle: assert property (p_wbin_stable_when_idle)
        else $error("[SVA_FAIL][wclk] Write pointer changed without accepted write!");

    // Property 4: Gray Code Single-Bit Transition (Hamming Distance <= 1)
    // The Gray write pointer must toggle at most 1 bit per clock edge.
    property p_wptr_gray_hamming;
        @(posedge wclk) disable iff (!wrst_n)
        $onehot0(wptr ^ $past(wptr));
    endproperty
    a_wptr_gray_hamming: assert property (p_wptr_gray_hamming)
        else $error("[SVA_FAIL][wclk] Gray write pointer transitioned by >1 bit! Hamming violation.");

    // Property 5: Write Domain Reset Check
    property p_wfull_reset;
        @(posedge wclk)
        !wrst_n |-> (wfull == 1'b0 && wbin == '0 && wptr == '0);
    endproperty
    a_wfull_reset: assert property (p_wfull_reset)
        else $error("[SVA_FAIL][wclk] Write domain failed to hold reset state!");


    // =========================================================================
    // 2. READ CLOCK DOMAIN ASSERTIONS (Clocked on rclk)
    // =========================================================================

    // Property 6: Underflow Protection
    // An attempted read while EMPTY must NOT advance the read binary counter.
    property p_no_read_on_empty;
        @(posedge rclk) disable iff (!rrst_n)
        (rempty && rinc) |=> (rbin == $past(rbin));
    endproperty
    a_no_read_on_empty: assert property (p_no_read_on_empty)
        else $error("[SVA_FAIL][rclk] Read pointer advanced during EMPTY condition!");

    // Property 7: Read Pointer Increments on Accepted Read
    // An accepted read (rinc && !rempty) MUST increment rbin by exactly 1.
    property p_rbin_inc_on_read;
        @(posedge rclk) disable iff (!rrst_n)
        (!rempty && rinc) |=> (rbin == ($past(rbin) + 1'b1));
    endproperty
    a_rbin_inc_on_read: assert property (p_rbin_inc_on_read)
        else $error("[SVA_FAIL][rclk] Read pointer failed to increment on accepted read!");

    // Property 8: Read Pointer Stable when Idle
    // When no accepted read occurs, rbin must remain unchanged.
    property p_rbin_stable_when_idle;
        @(posedge rclk) disable iff (!rrst_n)
        (!rinc || rempty) |=> (rbin == $past(rbin));
    endproperty
    a_rbin_stable_when_idle: assert property (p_rbin_stable_when_idle)
        else $error("[SVA_FAIL][rclk] Read pointer changed without accepted read!");

    // Property 9: Gray Code Single-Bit Transition (Hamming Distance <= 1)
    // The Gray read pointer must toggle at most 1 bit per clock edge.
    property p_rptr_gray_hamming;
        @(posedge rclk) disable iff (!rrst_n)
        $onehot0(rptr ^ $past(rptr));
    endproperty
    a_rptr_gray_hamming: assert property (p_rptr_gray_hamming)
        else $error("[SVA_FAIL][rclk] Gray read pointer transitioned by >1 bit! Hamming violation.");

    // Property 10: Read Domain Reset Check
    property p_rempty_reset;
        @(posedge rclk)
        !rrst_n |-> (rempty == 1'b1 && rbin == '0 && rptr == '0);
    endproperty
    a_rempty_reset: assert property (p_rempty_reset)
        else $error("[SVA_FAIL][rclk] Read domain failed to hold reset state (rempty must be 1)!");

endmodule

`default_nettype wire
