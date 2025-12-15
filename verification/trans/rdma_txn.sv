import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_txn extends uvm_sequence_item;
    `uvm_object_utils(rdma_txn)

    int unsigned beats;
    logic [63:0] data_q[$];

    function new(string name = "rdma_txn");
        super.new(name);
    endfunction
endclass
