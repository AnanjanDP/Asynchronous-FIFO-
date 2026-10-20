// =============================================================================
// Module: async_fifo
// Description: Top-Level Parameterized Asynchronous FIFO
//
// Parameters:
//   DATA_WIDTH : Width of write and read data buses (default: 8)
//   ADDR_WIDTH : Address bit width, setting DEPTH = 2^ADDR_WIDTH (default: 4 -> 16 entries)
//
// Ports:
//   Write Domain:
//     wclk    : Write clock
//     wrst_n  : Active-low asynchronous write domain reset
//     winc    : Write enable / increment request
//     wdata   : Write data input [DATA_WIDTH-1:0]
//     wfull   : Synchronous write full flag (high indicates FIFO cannot accept data)
//
//   Read Domain:
//     rclk    : Read clock
//     rrst_n  : Active-low asynchronous read domain reset
//     rinc    : Read enable / increment request
//     rdata   : Read data output [DATA_WIDTH-1:0]
//     rempty  : Synchronous read empty flag (high indicates no valid data to read)
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

module async_fifo #(
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned ADDR_WIDTH = 4
)(
    // Write Domain
    input  logic                    wclk,
    input  logic                    wrst_n,
    input  logic                    winc,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic                    wfull,

    // Read Domain
    input  logic                    rclk,
    input  logic                    rrst_n,
    input  logic                    rinc,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic                    rempty
);

    // Internal interconnect signals
    logic [ADDR_WIDTH-1:0] waddr;
    logic [ADDR_WIDTH-1:0] raddr;
    logic [ADDR_WIDTH:0]   wptr;
    logic [ADDR_WIDTH:0]   rptr;
    logic [ADDR_WIDTH:0]   wq2_rptr;
    logic [ADDR_WIDTH:0]   rq2_wptr;
    logic                  wclken;

    // Memory write qualify: only write if increment requested and not full
    assign wclken = winc & ~wfull;

    // -------------------------------------------------------------------------
    // 1. Dual-Port Storage Array
    // -------------------------------------------------------------------------
    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_mem (
        .wclk   (wclk),
        .wclken (wclken),
        .waddr  (waddr),
        .wdata  (wdata),
        .raddr  (raddr),
        .rdata  (rdata)
    );

    // -------------------------------------------------------------------------
    // 2. Read Pointer & Empty Flag Controller (rclk domain)
    // -------------------------------------------------------------------------
    rptr_empty #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_rptr_empty (
        .rclk     (rclk),
        .rrst_n   (rrst_n),
        .rinc     (rinc),
        .rq2_wptr (rq2_wptr),
        .rempty   (rempty),
        .raddr    (raddr),
        .rptr     (rptr)
    );

    // -------------------------------------------------------------------------
    // 3. Write Pointer & Full Flag Controller (wclk domain)
    // -------------------------------------------------------------------------
    wptr_full #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_wptr_full (
        .wclk     (wclk),
        .wrst_n   (wrst_n),
        .winc     (winc),
        .wq2_rptr (wq2_rptr),
        .wfull    (wfull),
        .waddr    (waddr),
        .wptr     (wptr)
    );

    // -------------------------------------------------------------------------
    // 4. Synchronizer: Read Pointer (rclk) -> Write Domain (wclk)
    // -------------------------------------------------------------------------
    sync_2ff #(
        .WIDTH (ADDR_WIDTH + 1)
    ) u_sync_r2w (
        .clk   (wclk),
        .rst_n (wrst_n),
        .din   (rptr),
        .dout  (wq2_rptr)
    );

    // -------------------------------------------------------------------------
    // 5. Synchronizer: Write Pointer (wclk) -> Read Domain (rclk)
    // -------------------------------------------------------------------------
    sync_2ff #(
        .WIDTH (ADDR_WIDTH + 1)
    ) u_sync_w2r (
        .clk   (rclk),
        .rst_n (rrst_n),
        .din   (wptr),
        .dout  (rq2_wptr)
    );

endmodule

`default_nettype wire
