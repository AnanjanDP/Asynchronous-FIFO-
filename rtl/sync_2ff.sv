// =============================================================================
// Module: sync_2ff
// Description: Parameterized 2-Stage Flip-Flop Synchronizer for CDC
//
// Features:
// - ASYNC_REG attribute to prevent shift-register (SRL) synthesis extraction
//   and force placement in the same physical slice/tile.
// - Asynchronous active-low reset.
// - Synchronizes a multi-bit Gray-coded pointer across asynchronous clock domains.
//
// Engineering Note:
// This synchronizer relies on the input signal having a Hamming distance of 1
// (Gray code). Only 1 bit must transition per destination clock edge.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module sync_2ff #(
    parameter int unsigned WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);

    // Synthesis attributes to prevent SRL inference and maintain physical proximity
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage1;
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_stage1 <= '0;
            sync_stage2 <= '0;
        end else begin
            sync_stage1 <= din;
            sync_stage2 <= sync_stage1;
        end
    end

    assign dout = sync_stage2;

endmodule

`default_nettype wire
