import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_test extends uvm_test;
    `uvm_component_utils(rdma_test)

    rdma_env env;

    function new(string name = "rdma_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = rdma_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        rdma_fixed_seq seq;
        phase.raise_objection(this);
        seq = rdma_fixed_seq::type_id::create("seq");
        seq.start(env.sqr);
        phase.drop_objection(this);
    endtask
    
endclass
