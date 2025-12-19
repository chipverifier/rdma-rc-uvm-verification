import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_driver extends uvm_driver#(rdma_seq_item);
    `uvm_component_utils(rdma_driver)

    virtual rdma_if vif;

    function new(string name = "rdma_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif))
            `uvm_fatal("DRV", "vif not set")
    endfunction

    task run_phase(uvm_phase phase);
        rdma_seq_item req;

        vif.cb.rx_valid <= 0;
        vif.cb.rx_last  <= 0;

         if (!vif.rst_n)
            @(posedge vif.rst_n);

        forever begin
            seq_item_port.get_next_item(req);
            send_packet(req.beats, req.base);
            seq_item_port.item_done();
        end
    endtask

    task send_packet(int beats, logic [63:0] base);
        int i;
        for (i = 0; i < beats; i++) begin
            vif.cb.rx_valid <= 1;
            vif.cb.rx_data  <= base + i;
            vif.cb.rx_last  <= (i == beats-1);
            @(vif.cb);
        end
        vif.cb.rx_valid <= 0;
        vif.cb.rx_last  <= 0;
    endtask
endclass