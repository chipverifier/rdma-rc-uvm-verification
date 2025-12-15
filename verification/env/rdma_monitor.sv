import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_monitor extends uvm_monitor;
    `uvm_component_utils(rdma_monitor)

    virtual rdma_if vif;

    uvm_analysis_port #(rdma_txn) rx_ap;
    uvm_analysis_port #(rdma_txn) tx_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        rx_ap = new("rx_ap", this);
        tx_ap = new("tx_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif))
            `uvm_fatal("MON", "vif not set")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            collect_rx();
            collect_tx();
        join
    endtask

    task collect_rx();
        rdma_txn t;
        t = rdma_txn::type_id::create("rx_pkt", this);

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) begin
                t = rdma_txn::type_id::create("rx_pkt", this);
                continue;
            end

            if (vif.rx_valid) begin
                t.data_q.push_back(vif.rx_data);

                if (vif.rx_last) begin
                    t.beats = t.data_q.size();
                    rx_ap.write(t);
                    t = rdma_txn::type_id::create("rx_pkt", this);
                end
            end
        end
    endtask

    task collect_tx();
        rdma_txn t;
        t = rdma_txn::type_id::create("tx_pkt", this);

        forever begin
            @(posedge vif.clk);
            if (!vif.rst_n) begin
                t = rdma_txn::type_id::create("tx_pkt", this);
                continue;
            end

            if (vif.tx_valid) begin
                t.data_q.push_back(vif.tx_data);

                if (vif.tx_last) begin
                    t.beats = t.data_q.size();
                    tx_ap.write(t);
                    t = rdma_txn::type_id::create("tx_pkt", this);
                end
            end
        end
    endtask

endclass
