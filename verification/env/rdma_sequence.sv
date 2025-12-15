import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_base_seq extends uvm_sequence#(rdma_seq_item);
    `uvm_object_utils(rdma_base_seq)

    int pkt_num = 1;

    function new(string name = "rdma_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        for (int idx = 0; idx < pkt_num; idx++) begin
            rdma_seq_item req;
            req = rdma_seq_item::type_id::create($sformatf("req_%0d", idx));
            if (!req.randomize()) begin
                `uvm_fatal("RAND_ERR", "randomize failed")
            end
            start_item(req);
            finish_item(req);
        end
    endtask
endclass


class rdma_fixed_seq extends rdma_base_seq;
    `uvm_object_utils(rdma_fixed_seq)

    function new(string name = "rdma_fixed_seq");
        super.new(name);
        pkt_num = 2;
    endfunction

    virtual task body();
        for (int idx = 0; idx < pkt_num; idx++) begin
            rdma_seq_item req;
            req = rdma_seq_item::type_id::create($sformatf("req_%0d", idx));
            if (idx == 0) begin
                req.beats = 4;
                req.base  = 64'h1000;
            end else begin
                req.beats = 2;
                req.base  = 64'h2000;
            end
            start_item(req);
            finish_item(req);
        end
    endtask
endclass


class rdma_rand_seq extends rdma_base_seq;
    `uvm_object_utils(rdma_rand_seq)

    function new(string name = "rdma_rand_seq");
        super.new(name);
        pkt_num = 5;
    endfunction
endclass
