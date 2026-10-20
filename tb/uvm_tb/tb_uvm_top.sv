// =============================================================================
// Top-Level Module: tb_uvm_top
// Description: UVM Top Module instantiating DUT, Interface, setting config_db,
//              and invoking run_test()
// =============================================================================

`timescale 1ns / 1ps
`default_nettype none

import uvm_pkg::*;
`include "uvm_macros.svh"
import fifo_uvm_pkg::*;

module tb_uvm_top;

    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned ADDR_WIDTH = 4;

    // Asynchronous Clocks: wclk = 100MHz (10ns), rclk = 66.6MHz (15ns)
    logic wclk = 0;
    logic rclk = 0;

    always #5.0ns  wclk = ~wclk;
    always #7.5ns  rclk = ~rclk;

    // Interface instantiation
    fifo_if #(DATA_WIDTH) intf (
        .wclk (wclk),
        .rclk (rclk)
    );

    // DUT instantiation
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .wclk   (intf.wclk),
        .wrst_n (intf.wrst_n),
        .winc   (intf.winc),
        .wdata  (intf.wdata),
        .wfull  (intf.wfull),
        .rclk   (intf.rclk),
        .rrst_n (intf.rrst_n),
        .rinc   (intf.rinc),
        .rdata  (intf.rdata),
        .rempty (intf.rempty)
    );

    initial begin
        // Set virtual interface in UVM config_db for components
        uvm_config_db#(virtual fifo_if#(DATA_WIDTH))::set(null, "*", "vif", intf);

        // Dump VCD waveforms
        $dumpfile("waves/dump_uvm.vcd");
        $dumpvars(0, tb_uvm_top);

        // Run UVM Test
        run_test("fifo_base_test");
    end

endmodule

`default_nettype wire
