// =============================================================================
// Class: fifo_item
// Description: Transaction class representing FIFO operations
//
// Features:
// - Parameterized payload data width.
// - Constrained-random delays for modeling variable-rate producer/consumer.
// - Utility functions: convert2string, copy, compare.
// =============================================================================

`ifndef FIFO_ITEM_SV
`define FIFO_ITEM_SV

class fifo_item #(parameter int unsigned DATA_WIDTH = 8);

    typedef enum { WRITE, READ, IDLE } op_type_e;

    rand op_type_e                  op;
    rand bit [DATA_WIDTH-1:0]       data;
    rand int unsigned               delay_cycles;

    // Timing constraints: favor back-to-back bursts with occasional random stalls
    constraint c_delay {
        delay_cycles dist {
            0       := 70, // 70% back-to-back zero delay
            [1:3]   := 20, // 20% short delays
            [4:8]   := 10  // 10% longer delays
        };
    }

    // Constructor
    function new(string name = "fifo_item");
    endfunction

    // String formatting for logging
    virtual function string convert2string();
        string s;
        case (op)
            WRITE: $sformat(s, "OP=WRITE Data=0x%02h Delay=%0d", data, delay_cycles);
            READ:  $sformat(s, "OP=READ  Data=0x%02h Delay=%0d", data, delay_cycles);
            IDLE:  $sformat(s, "OP=IDLE  Delay=%0d", delay_cycles);
        endcase
        return s;
    endfunction

    // Deep copy
    virtual function void copy(fifo_item#(DATA_WIDTH) rhs);
        if (rhs == null) return;
        this.op           = rhs.op;
        this.data         = rhs.data;
        this.delay_cycles = rhs.delay_cycles;
    endfunction

    // Comparison function
    virtual function bit compare(fifo_item#(DATA_WIDTH) rhs);
        if (rhs == null) return 0;
        return (this.data === rhs.data);
    endfunction

endclass

`endif // FIFO_ITEM_SV
