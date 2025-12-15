import uvm_pkg::*;
`include "uvm_macros.svh"

`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class rdma_scb extends uvm_component;
    `uvm_component_utils(rdma_scb)

    uvm_analysis_imp_exp #(rdma_txn, rdma_scb) exp_tx_imp;
    uvm_analysis_imp_act #(rdma_txn, rdma_scb) act_tx_imp;

    rdma_txn exp_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        exp_tx_imp = new("exp_tx_imp", this);
        act_tx_imp = new("act_tx_imp", this);
    endfunction

    function void write_exp(rdma_txn t);
        exp_q.push_back(t);
    endfunction

    function void write_act(rdma_txn t);
        rdma_txn exp;

        if (exp_q.size() == 0)
            `uvm_fatal("SCB", "Unexpected actual TX")

        exp = exp_q.pop_front();

        if (!t.compare(exp))
            `uvm_error("SCB", "TX mismatch")
        else
            `uvm_info("SCB", "TX match", UVM_LOW)
    endfunction

endclass
