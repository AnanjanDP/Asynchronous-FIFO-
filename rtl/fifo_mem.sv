// =============================================================================
// Module: fifo_mem
// Description: Parameterized Dual-Port Storage Array for Asynchronous FIFO
//
// Synthesizable Memory Model:
// - True dual-port storage (1 write port, 1 read port).
// - Synchronous write on wclk qualified by wclken (winc & ~wfull).
// - Asynchronous/combinational read port based on raddr.
//   This provides zero-latency read access as soon as raddr is presented.
//
// ASIC Foundry Note:
// In an ASIC standard cell synthesis flow, this infers a flip-flop/latch array.
// For large depths (e.g., Depth >= 64 or 128), a dedicated foundry dual-port
// SRAM macro (1W1R) would be substituted. Commercial SRAMs have synchronous
// read latency (typically 1 clock cycle), which requires an output skid buffer
// or First-Word Fall-Through (FWFT) wrapper.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module fifo_mem #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned ADDR_WIDTH = 4
)(
    // Write Port (wclk domain)
    input  logic                    wclk,
    input  logic                    wclken,
    input  logic [ADDR_WIDTH-1:0]   waddr,
    input  logic [DATA_WIDTH-1:0]   wdata,

    // Read Port (rclk domain)
    input  logic [ADDR_WIDTH-1:0]   raddr,
    output logic [DATA_WIDTH-1:0]   rdata
);

    localparam int unsigned DEPTH = 1 << ADDR_WIDTH;

    // Parameter sanity checks
    initial begin
        if (DATA_WIDTH < 1) $fatal(1, "[fifo_mem] DATA_WIDTH must be >= 1");
        if (ADDR_WIDTH < 1) $fatal(1, "[fifo_mem] ADDR_WIDTH must be >= 1");
    end

    // Storage array
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Synchronous write operation
    always_ff @(posedge wclk) begin
        if (wclken) begin
            mem[waddr] <= wdata;
        end
    end

    // Continuous combinational read
    assign rdata = mem[raddr];

endmodule

`default_nettype wire
