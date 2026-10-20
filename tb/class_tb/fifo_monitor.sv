// =============================================================================
// Class: fifo_wr_monitor and fifo_rd_monitor
// Description: Dual-domain passive monitors for Asynchronous FIFO
//
// Key Responsibilities:
// - Passively samples interface activity at clocking block sample times.
// - Accurately filters out rejected operations (writes during wfull, reads during rempty).
// - Creates transaction objects and broadcasts to Scoreboard mailboxes.
// =============================================================================

`ifndef FIFO_MONITOR_SV
`define FIFO_MONITOR_SV

`include "fifo_item.sv"

// -----------------------------------------------------------------------------
// Write Domain Passive Monitor (wclk domain)
// -----------------------------------------------------------------------------
class fifo_wr_monitor #(parameter int unsigned DATA_WIDTH = 8);

    virtual fifo_if#(DATA_WIDTH) vif;
    mailbox #(fifo_item#(DATA_WIDTH)) mon_mbx;

    function new(virtual fifo_if#(DATA_WIDTH) vif, 
                 mailbox #(fifo_item#(DATA_WIDTH)) mon_mbx);
        this.vif     = vif;
        this.mon_mbx = mon_mbx;
    endfunction

    virtual task run();
        fifo_item#(DATA_WIDTH) item;
        forever begin
            @(vif.cb_wr_mon);
            // An accepted write occurs when winc is asserted, wfull is low, and out of reset
            if (vif.cb_wr_mon.wrst_n && vif.cb_wr_mon.winc && !vif.cb_wr_mon.wfull) begin
                item = new("wr_mon_item");
                item.op   = fifo_item#(DATA_WIDTH)::WRITE;
                item.data = vif.cb_wr_mon.wdata;
                mon_mbx.put(item);
            end
        end
    endtask

endclass

// -----------------------------------------------------------------------------
// Read Domain Passive Monitor (rclk domain)
// -----------------------------------------------------------------------------
class fifo_rd_monitor #(parameter int unsigned DATA_WIDTH = 8);

    virtual fifo_if#(DATA_WIDTH) vif;
    mailbox #(fifo_item#(DATA_WIDTH)) mon_mbx;

    function new(virtual fifo_if#(DATA_WIDTH) vif, 
                 mailbox #(fifo_item#(DATA_WIDTH)) mon_mbx);
        this.vif     = vif;
        this.mon_mbx = mon_mbx;
    endfunction

    virtual task run();
        fifo_item#(DATA_WIDTH) item;
        forever begin
            @(vif.cb_rd_mon);
            // An accepted read occurs when rinc is asserted, rempty is low, and out of reset
            if (vif.cb_rd_mon.rrst_n && vif.cb_rd_mon.rinc && !vif.cb_rd_mon.rempty) begin
                item = new("rd_mon_item");
                item.op   = fifo_item#(DATA_WIDTH)::READ;
                item.data = vif.cb_rd_mon.rdata; // Sample data at head of FWFT FIFO
                mon_mbx.put(item);
            end
        end
    endtask

endclass

`endif // FIFO_MONITOR_SV
