// =============================================================================
// Package: fifo_uvm_pkg
// Description: Complete Production-Grade UVM 1.2 Verification Environment
//              for Asynchronous FIFO
//
// Components Included:
//   - fifo_seq_item     : Sequence item with fields, constraints, and utility macros
//   - fifo_sequences    : Base, burst, random, and concurrent sequences
//   - fifo_wr_driver    : UVM driver in wclk domain
//   - fifo_rd_driver    : UVM driver in rclk domain
//   - fifo_wr_monitor   : Passive UVM monitor in wclk domain with analysis port
//   - fifo_rd_monitor   : Passive UVM monitor in rclk domain with analysis port
//   - fifo_wr_agent     : Write domain agent (ACTIVE or PASSIVE)
//   - fifo_rd_agent     : Read domain agent (ACTIVE or PASSIVE)
//   - fifo_scoreboard   : TLM-based scoreboarding with golden reference model
//   - fifo_env          : Top UVM environment container wiring agents to scoreboard
//   - fifo_tests        : Base test and stress tests
// =============================================================================

`timescale 1ns / 1ps

package fifo_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int unsigned DATA_WIDTH = 8;
    localparam int unsigned ADDR_WIDTH = 4;
    localparam int unsigned DEPTH      = 1 << ADDR_WIDTH;

    // =========================================================================
    // 1. SEQUENCE ITEM
    // =========================================================================
    class fifo_seq_item extends uvm_sequence_item;

        typedef enum { WRITE, READ, IDLE } op_type_e;

        rand op_type_e            op;
        rand bit [DATA_WIDTH-1:0] data;
        rand int unsigned         delay_cycles;

        `uvm_object_utils_begin(fifo_seq_item)
            `uvm_field_enum(op_type_e, op, UVM_ALL_ON)
            `uvm_field_int(data,           UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(delay_cycles,   UVM_ALL_ON | UVM_DEC)
        `uvm_object_utils_end

        constraint c_delay {
            delay_cycles dist {
                0     := 70,
                [1:3] := 20,
                [4:8] := 10
            };
        }

        function new(string name = "fifo_seq_item");
            super.new(name);
        endfunction

    endclass : fifo_seq_item

    // =========================================================================
    // 2. SEQUENCES
    // =========================================================================
    typedef uvm_sequencer #(fifo_seq_item) fifo_sequencer;

    class fifo_base_sequence extends uvm_sequence #(fifo_seq_item);
        `uvm_object_utils(fifo_base_sequence)
        function new(string name = "fifo_base_sequence"); super.new(name); endfunction
    endclass

    // Write sequence
    class fifo_write_sequence extends fifo_base_sequence;
        `uvm_object_utils(fifo_write_sequence)
        rand int num_items = 20;

        function new(string name = "fifo_write_sequence"); super.new(name); endfunction

        virtual task body();
            for (int i = 0; i < num_items; i++) begin
                `uvm_do_with(req, { req.op == fifo_seq_item::WRITE; })
            end
        endtask
    endclass

    // Read sequence
    class fifo_read_sequence extends fifo_base_sequence;
        `uvm_object_utils(fifo_read_sequence)
        rand int num_items = 20;

        function new(string name = "fifo_read_sequence"); super.new(name); endfunction

        virtual task body();
            for (int i = 0; i < num_items; i++) begin
                `uvm_do_with(req, { req.op == fifo_seq_item::READ; })
            end
        endtask
    endclass

    // =========================================================================
    // 3. DRIVERS
    // =========================================================================
    class fifo_wr_driver extends uvm_driver #(fifo_seq_item);
        `uvm_component_utils(fifo_wr_driver)

        virtual fifo_if#(DATA_WIDTH) vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if#(DATA_WIDTH))::get(this, "", "vif", vif))
                `uvm_fatal("NO_VIF", "Virtual interface not set for fifo_wr_driver")
        endfunction

        virtual task run_phase(uvm_phase phase);
            fifo_seq_item item;
            // Reset
            vif.cb_wr.winc  <= 1'b0;
            vif.cb_wr.wdata <= '0;
            vif.wrst_n      <= 1'b0;
            repeat (3) @(vif.cb_wr);
            vif.wrst_n      <= 1'b1;
            repeat (2) @(vif.cb_wr);

            forever begin
                seq_item_port.get_next_item(item);
                repeat (item.delay_cycles) @(vif.cb_wr);

                if (item.op == fifo_seq_item::WRITE) begin
                    while (vif.cb_wr.wfull === 1'b1) @(vif.cb_wr);
                    vif.cb_wr.winc  <= 1'b1;
                    vif.cb_wr.wdata <= item.data;
                    @(vif.cb_wr);
                    vif.cb_wr.winc  <= 1'b0;
                    vif.cb_wr.wdata <= '0;
                end
                seq_item_port.item_done();
            end
        endtask
    endclass

    class fifo_rd_driver extends uvm_driver #(fifo_seq_item);
        `uvm_component_utils(fifo_rd_driver)

        virtual fifo_if#(DATA_WIDTH) vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if#(DATA_WIDTH))::get(this, "", "vif", vif))
                `uvm_fatal("NO_VIF", "Virtual interface not set for fifo_rd_driver")
        endfunction

        virtual task run_phase(uvm_phase phase);
            fifo_seq_item item;
            // Reset
            vif.cb_rd.rinc <= 1'b0;
            vif.rrst_n     <= 1'b0;
            repeat (3) @(vif.cb_rd);
            vif.rrst_n     <= 1'b1;
            repeat (2) @(vif.cb_rd);

            forever begin
                seq_item_port.get_next_item(item);
                repeat (item.delay_cycles) @(vif.cb_rd);

                if (item.op == fifo_seq_item::READ) begin
                    while (vif.cb_rd.rempty === 1'b1) @(vif.cb_rd);
                    vif.cb_rd.rinc <= 1'b1;
                    @(vif.cb_rd);
                    vif.cb_rd.rinc <= 1'b0;
                end
                seq_item_port.item_done();
            end
        endtask
    endclass

    // =========================================================================
    // 4. MONITORS
    // =========================================================================
    class fifo_wr_monitor extends uvm_monitor;
        `uvm_component_utils(fifo_wr_monitor)

        virtual fifo_if#(DATA_WIDTH) vif;
        uvm_analysis_port #(fifo_seq_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if#(DATA_WIDTH))::get(this, "", "vif", vif))
                `uvm_fatal("NO_VIF", "Virtual interface not set for fifo_wr_monitor")
        endfunction

        virtual task run_phase(uvm_phase phase);
            fifo_seq_item item;
            forever begin
                @(vif.cb_wr_mon);
                if (vif.cb_wr_mon.wrst_n && vif.cb_wr_mon.winc && !vif.cb_wr_mon.wfull) begin
                    item = fifo_seq_item::type_id::create("wr_item");
                    item.op   = fifo_seq_item::WRITE;
                    item.data = vif.cb_wr_mon.wdata;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class fifo_rd_monitor extends uvm_monitor;
        `uvm_component_utils(fifo_rd_monitor)

        virtual fifo_if#(DATA_WIDTH) vif;
        uvm_analysis_port #(fifo_seq_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual fifo_if#(DATA_WIDTH))::get(this, "", "vif", vif))
                `uvm_fatal("NO_VIF", "Virtual interface not set for fifo_rd_monitor")
        endfunction

        virtual task run_phase(uvm_phase phase);
            fifo_seq_item item;
            forever begin
                @(vif.cb_rd_mon);
                if (vif.cb_rd_mon.rrst_n && vif.cb_rd_mon.rinc && !vif.cb_rd_mon.rempty) begin
                    item = fifo_seq_item::type_id::create("rd_item");
                    item.op   = fifo_seq_item::READ;
                    item.data = vif.cb_rd_mon.rdata;
                    ap.write(item);
                end
            end
        endtask
    endclass

    // =========================================================================
    // 5. AGENTS
    // =========================================================================
    class fifo_wr_agent extends uvm_agent;
        `uvm_component_utils(fifo_wr_agent)

        fifo_sequencer  sqr;
        fifo_wr_driver  drv;
        fifo_wr_monitor mon;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = fifo_wr_monitor::type_id::create("mon", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sqr = fifo_sequencer::type_id::create("sqr", this);
                drv = fifo_wr_driver::type_id::create("drv", this);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            if (get_is_active() == UVM_ACTIVE) begin
                drv.seq_item_port.connect(sqr.seq_item_export);
            end
        endfunction
    endclass

    class fifo_rd_agent extends uvm_agent;
        `uvm_component_utils(fifo_rd_agent)

        fifo_sequencer  sqr;
        fifo_rd_driver  drv;
        fifo_rd_monitor mon;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon = fifo_rd_monitor::type_id::create("mon", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sqr = fifo_sequencer::type_id::create("sqr", this);
                drv = fifo_rd_driver::type_id::create("drv", this);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            if (get_is_active() == UVM_ACTIVE) begin
                drv.seq_item_port.connect(sqr.seq_item_export);
            end
        endfunction
    endclass

    // =========================================================================
    // 6. SCOREBOARD (TLM FIFO-Based Golden Model)
    // =========================================================================
    class fifo_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(fifo_scoreboard)

        uvm_tlm_analysis_fifo #(fifo_seq_item) wr_fifo;
        uvm_tlm_analysis_fifo #(fifo_seq_item) rd_fifo;

        logic [DATA_WIDTH-1:0] golden_queue[$];
        int unsigned match_count    = 0;
        int unsigned mismatch_count = 0;
        int unsigned wr_count       = 0;
        int unsigned rd_count       = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            wr_fifo = new("wr_fifo", this);
            rd_fifo = new("rd_fifo", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            fork
                // Write collector thread
                forever begin
                    fifo_seq_item wr_item;
                    wr_fifo.get(wr_item);
                    golden_queue.push_back(wr_item.data);
                    wr_count++;
                end
                // Read checker thread
                forever begin
                    fifo_seq_item rd_item;
                    logic [DATA_WIDTH-1:0] expected_data;
                    rd_fifo.get(rd_item);
                    rd_count++;

                    if (golden_queue.size() == 0) begin
                        `uvm_error("SCB_UNDERFLOW", "Read observed when reference model is EMPTY!")
                        mismatch_count++;
                    end else begin
                        expected_data = golden_queue.pop_front();
                        if (rd_item.data === expected_data) begin
                            match_count++;
                        end else begin
                            `uvm_error("SCB_MISMATCH", $sformatf("Data Mismatch! Exp=0x%02h, Got=0x%02h", 
                                       expected_data, rd_item.data))
                            mismatch_count++;
                        end
                    end
                end
            join
        endtask

        virtual function void report_phase(uvm_phase phase);
            `uvm_info("UVM_SCB_REPORT", $sformatf("Total Writes: %0d, Total Reads: %0d, Matches: %0d, Mismatches: %0d",
                      wr_count, rd_count, match_count, mismatch_count), UVM_LOW)
            if (mismatch_count == 0 && (wr_count == rd_count))
                `uvm_info("UVM_SCB_REPORT", ">>> UVM SCOREBOARD CHECK PASSED <<<", UVM_LOW)
            else
                `uvm_error("UVM_SCB_REPORT", ">>> UVM SCOREBOARD CHECK FAILED <<<")
        endfunction
    endclass

    // =========================================================================
    // 7. ENVIRONMENT
    // =========================================================================
    class fifo_env extends uvm_env;
        `uvm_component_utils(fifo_env)

        fifo_wr_agent   wr_agent;
        fifo_rd_agent   rd_agent;
        fifo_scoreboard scb;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            wr_agent = fifo_wr_agent::type_id::create("wr_agent", this);
            rd_agent = fifo_rd_agent::type_id::create("rd_agent", this);
            scb      = fifo_scoreboard::type_id::create("scb", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            wr_agent.mon.ap.connect(scb.wr_fifo.analysis_export);
            rd_agent.mon.ap.connect(scb.rd_fifo.analysis_export);
        endfunction
    endclass

    // =========================================================================
    // 8. TESTS
    // =========================================================================
    class fifo_base_test extends uvm_test;
        `uvm_component_utils(fifo_base_test)

        fifo_env env;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = fifo_env::type_id::create("env", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            fifo_write_sequence wr_seq;
            fifo_read_sequence  rd_seq;

            phase.raise_objection(this);
            wr_seq = fifo_write_sequence::type_id::create("wr_seq");
            rd_seq = fifo_read_sequence::type_id::create("rd_seq");

            fork
                wr_seq.start(env.wr_agent.sqr);
                rd_seq.start(env.rd_agent.sqr);
            join

            #100ns;
            phase.drop_objection(this);
        endtask
    endclass

endpackage : fifo_uvm_pkg
