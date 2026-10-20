// =============================================================================
// Class: fifo_generator
// Description: Constrained-random sequence generator for FIFO verification
//
// Capabilities:
// - Generates burst sequences, alternating sequences, and random traffic.
// - Supports data pattern injection (walking ones, alternating 0xAA/0x55, all zeroes, all ones).
// =============================================================================

`ifndef FIFO_GENERATOR_SV
`define FIFO_GENERATOR_SV

`include "fifo_item.sv"

class fifo_generator #(parameter int unsigned DATA_WIDTH = 8);

    mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx;
    mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx;

    function new(mailbox #(fifo_item#(DATA_WIDTH)) wr_mbx,
                 mailbox #(fifo_item#(DATA_WIDTH)) rd_mbx);
        this.wr_mbx = wr_mbx;
        this.rd_mbx = rd_mbx;
    endfunction

    // Generate N write items
    virtual task gen_writes(int unsigned count);
        fifo_item#(DATA_WIDTH) item;
        for (int i = 0; i < count; i++) begin
            item = new("gen_wr_item");
            if (!item.randomize() with { op == fifo_item#(DATA_WIDTH)::WRITE; }) begin
                $fatal(1, "[GENERATOR] Randomization failed for write transaction!");
            end
            wr_mbx.put(item);
        end
    endtask

    // Generate N read items
    virtual task gen_reads(int unsigned count);
        fifo_item#(DATA_WIDTH) item;
        for (int i = 0; i < count; i++) begin
            item = new("gen_rd_item");
            if (!item.randomize() with { op == fifo_item#(DATA_WIDTH)::READ; }) begin
                $fatal(1, "[GENERATOR] Randomization failed for read transaction!");
            end
            rd_mbx.put(item);
        end
    endtask

    // Generate corner case specific data patterns
    virtual task gen_pattern_writes(int unsigned count);
        fifo_item#(DATA_WIDTH) item;
        for (int i = 0; i < count; i++) begin
            item = new("pattern_wr_item");
            item.op           = fifo_item#(DATA_WIDTH)::WRITE;
            item.delay_cycles = 0;
            case (i % 6)
                0: item.data = '0;                       // All 0s
                1: item.data = '1;                       // All 1s
                2: item.data = {DATA_WIDTH/2{2'b10}};    // 0xAA pattern
                3: item.data = {DATA_WIDTH/2{2'b01}};    // 0x55 pattern
                4: item.data = (1 << (i % DATA_WIDTH));  // Walking 1
                5: item.data = ~(1 << (i % DATA_WIDTH)); // Walking 0
            endcase
            wr_mbx.put(item);
        end
    endtask

endclass

`endif // FIFO_GENERATOR_SV
