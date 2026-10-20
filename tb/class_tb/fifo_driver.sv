// =============================================================================
// Class: fifo_wr_driver and fifo_rd_driver
// Description: Dual-domain pin-level drivers for Asynchronous FIFO
//
// Key Responsibilities:
// - fifo_wr_driver: consumes write items from mailbox and drives wclk clocking block.
// - fifo_rd_driver: consumes read items from mailbox and drives rclk clocking block.
// - Handles flow control: respects wfull and rempty or drives controlled stress traffic.
// =============================================================================

`ifndef FIFO_DRIVER_SV
`define FIFO_DRIVER_SV

`include "fifo_item.sv"

// -----------------------------------------------------------------------------
// Write Domain Driver
// -----------------------------------------------------------------------------
class fifo_wr_driver #(parameter int unsigned DATA_WIDTH = 8);

    virtual fifo_if#(DATA_WIDTH) vif;
    mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx;

    function new(virtual fifo_if#(DATA_WIDTH) vif, 
                 mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx);
        this.vif    = vif;
        this.wr_mbx = wr_mbx;
    endfunction

    // Reset sequence
    virtual task reset();
        vif.cb_wr.winc  <= 1'b0;
        vif.cb_wr.wdata <= '0;
        vif.wrst_n      <= 1'b0;
        repeat (3) @(vif.cb_wr);
        vif.wrst_n      <= 1'b1;
        repeat (2) @(vif.cb_wr);
    endtask

    // Main run loop
    virtual task run();
        fifo_item#(DATA_WIDTH) item;
        forever begin
            wr_mbx.get(item);

            // Apply randomized delay cycles
            repeat (item.delay_cycles) @(vif.cb_wr);

            if (item.op == fifo_item#(DATA_WIDTH)::WRITE) begin
                // Wait if FIFO is full (unless test deliberately exercises overflow)
                while (vif.cb_wr.wfull === 1'b1) begin
                    @(vif.cb_wr);
                end

                vif.cb_wr.winc  <= 1'b1;
                vif.cb_wr.wdata <= item.data;
                @(vif.cb_wr);
                vif.cb_wr.winc  <= 1'b0;
                vif.cb_wr.wdata <= '0;
            end
        end
    endtask

endclass

// -----------------------------------------------------------------------------
// Read Domain Driver
// -----------------------------------------------------------------------------
class fifo_rd_driver #(parameter int unsigned DATA_WIDTH = 8);

    virtual fifo_if#(DATA_WIDTH) vif;
    mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx;

    function new(virtual fifo_if#(DATA_WIDTH) vif, 
                 mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx);
        this.vif    = vif;
        this.rd_mbx = rd_mbx;
    endfunction

    // Reset sequence
    virtual task reset();
        vif.cb_rd.rinc <= 1'b0;
        vif.rrst_n     <= 1'b0;
        repeat (3) @(vif.cb_rd);
        vif.rrst_n     <= 1'b1;
        repeat (2) @(vif.cb_rd);
    endtask

    // Main run loop
    virtual task run();
        fifo_item#(DATA_WIDTH) item;
        forever begin
            rd_mbx.get(item);

            // Apply randomized delay cycles
            repeat (item.delay_cycles) @(vif.cb_rd);

            if (item.op == fifo_item#(DATA_WIDTH)::READ) begin
                // Wait if FIFO is empty (unless test deliberately exercises underflow)
                while (vif.cb_rd.rempty === 1'b1) begin
                    @(vif.cb_rd);
                end

                vif.cb_rd.rinc <= 1'b1;
                @(vif.cb_rd);
                vif.cb_rd.rinc <= 1'b0;
            end
        end
    endtask

endclass

`endif // FIFO_DRIVER_SV
