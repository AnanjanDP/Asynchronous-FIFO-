// =============================================================================
// Class: fifo_env
// Description: Class-based Verification Environment Container
//
// Key Responsibilities:
// - Instantiates and connects all verification components and mailboxes.
// - Coordinates initialization, driver runs, monitor runs, and scoreboarding.
// =============================================================================

`ifndef FIFO_ENV_SV
`define FIFO_ENV_SV

`include "fifo_item.sv"
`include "fifo_driver.sv"
`include "fifo_monitor.sv"
`include "fifo_scoreboard.sv"
`include "fifo_generator.sv"

class fifo_env #(parameter int unsigned DATA_WIDTH = 8);

    virtual fifo_if#(DATA_WIDTH) vif;

    // Component handles
    fifo_wr_driver     #(DATA_WIDTH) wr_drv;
    fifo_rd_driver     #(DATA_WIDTH) rd_drv;
    fifo_wr_monitor    #(DATA_WIDTH) wr_mon;
    fifo_rd_monitor    #(DATA_WIDTH) rd_mon;
    fifo_scoreboard    #(DATA_WIDTH) scb;
    fifo_generator     #(DATA_WIDTH) gen;

    // Communication mailboxes
    mailbox #(fifo_item#(DATA_WIDTH)) wr_drv_mbx;
    mailbox #(fifo_item#(DATA_WIDTH)) rd_drv_mbx;
    mailbox #(fifo_item#(DATA_WIDTH)) wr_mon_mbx;
    mailbox #(fifo_item#(DATA_WIDTH)) rd_mon_mbx;

    function new(virtual fifo_if#(DATA_WIDTH) vif);
        this.vif = vif;
    endfunction

    // Build phase: construct mailboxes and components
    virtual function void build();
        wr_drv_mbx = new();
        rd_drv_mbx = new();
        wr_mon_mbx = new();
        rd_mon_mbx = new();

        wr_drv = new(vif, wr_drv_mbx);
        rd_drv = new(vif, rd_drv_mbx);
        wr_mon = new(vif, wr_mon_mbx);
        rd_mon = new(vif, rd_mon_mbx);
        scb    = new(wr_mon_mbx, rd_mon_mbx);
        gen    = new(wr_drv_mbx, rd_drv_mbx);
    endfunction

    // Reset sequence phase
    virtual task reset();
        fork
            wr_drv.reset();
            rd_drv.reset();
        join
    endtask

    // Start passive monitors and scoreboard
    virtual task start_infrastructure();
        fork
            wr_drv.run();
            rd_drv.run();
            wr_mon.run();
            rd_mon.run();
            scb.run();
        join_none
    endtask

endclass

`endif // FIFO_ENV_SV
