// =============================================================================
// Interface: fifo_if
// Description: SystemVerilog Dual-Clock Interface for Asynchronous FIFO
//
// Features:
// - Encapsulates both write (wclk) and read (rclk) clock domains.
// - Dedicated clocking blocks (cb_wr, cb_rd) to eliminate delta-cycle race
//   conditions between testbench drivers/monitors and DUT.
// - Modports for driver and monitor components in each domain.
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

interface fifo_if #(
    parameter int unsigned DATA_WIDTH = 8
)(
    input logic wclk,
    input logic rclk
);

    // Write Domain Signals
    logic                  wrst_n;
    logic                  winc;
    logic [DATA_WIDTH-1:0] wdata;
    logic                  wfull;

    // Read Domain Signals
    logic                  rrst_n;
    logic                  rinc;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  rempty;

    // -------------------------------------------------------------------------
    // Write Domain Clocking Block (Synchronous to wclk)
    // -------------------------------------------------------------------------
    clocking cb_wr @(posedge wclk);
        default input #1step output #100ps;
        output winc;
        output wdata;
        input  wfull;
    endclocking

    // Write Monitor Clocking Block (Input-only sampling)
    clocking cb_wr_mon @(posedge wclk);
        default input #1step;
        input winc;
        input wdata;
        input wfull;
        input wrst_n;
    endclocking

    // -------------------------------------------------------------------------
    // Read Domain Clocking Block (Synchronous to rclk)
    // -------------------------------------------------------------------------
    clocking cb_rd @(posedge rclk);
        default input #1step output #100ps;
        output rinc;
        input  rdata;
        input  rempty;
    endclocking

    // Read Monitor Clocking Block (Input-only sampling)
    clocking cb_rd_mon @(posedge rclk);
        default input #1step;
        input rinc;
        input rdata;
        input rempty;
        input rrst_n;
    endclocking

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport wr_driver (
        clocking cb_wr,
        output   wrst_n
    );

    modport wr_monitor (
        clocking cb_wr_mon
    );

    modport rd_driver (
        clocking cb_rd,
        output   rrst_n
    );

    modport rd_monitor (
        clocking cb_rd_mon
    );

    // DUT connection modport
    modport dut (
        input  wclk,
        input  wrst_n,
        input  winc,
        input  wdata,
        output wfull,
        input  rclk,
        input  rrst_n,
        input  rinc,
        output rdata,
        output rempty
    );

endinterface

`default_nettype wire
