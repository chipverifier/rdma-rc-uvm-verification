// verification/env/rdma_sequencer.sv
import uvm_pkg::*;
`include "uvm_macros.svh" 

class rdma_sequencer extends uvm_sequencer#(rdma_seq_item);
    `uvm_component_utils(rdma_sequencer)

    function new(string name = "rdma_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass