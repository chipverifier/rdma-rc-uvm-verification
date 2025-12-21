 // Import UVM package and macros (required for UVM components)
import uvm_pkg::*;
`include "uvm_macros.svh"

// RDMA Host sequencer: Bridges Sequence and Driver, no custom logic needed for basic scenarios
class rdma_host_sequencer extends uvm_sequencer #(rdma_host_seq_item);
    // Register to UVM factory (mandatory for component instantiation)
    `uvm_component_utils(rdma_host_sequencer)

    // Constructor: Standard UVM component constructor format
    function new(string name = "rdma_host_sequencer", uvm_component parent = null);
        super.new(name, parent); // Call parent class constructor (fixed)
    endfunction

    // ********** 新增：加一行强制仲裁触发（VCS 2018专属修复）**********
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        set_arbitration(UVM_SEQ_ARB_STRICT_FIFO); // 仅加这一行
    endfunction

endclass