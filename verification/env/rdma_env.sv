import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_env extends uvm_env;
    `uvm_component_utils(rdma_env)

    rdma_sequencer sqr;
    rdma_driver    drv;
    rdma_monitor   mon;
    rdma_rm        rm;
    rdma_scb       scb;

    function new(string name = "rdma_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sqr = rdma_sequencer::type_id::create("sqr", this);
        drv = rdma_driver   ::type_id::create("drv", this);
        mon = rdma_monitor  ::type_id::create("mon", this);
        rm  = rdma_rm       ::type_id::create("rm",  this);
        scb = rdma_scb      ::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        drv.seq_item_port.connect(sqr.seq_item_export);

        mon.rx_ap.connect(rm.rx_imp);
        rm.exp_tx_ap.connect(scb.exp_tx_imp);
        mon.tx_ap.connect(scb.act_tx_imp);

        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", drv.vif))
            `uvm_fatal("VIF_ERR_DRV", "Failed to get rdma_vif for driver")

        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", mon.vif))
            `uvm_fatal("VIF_ERR_MON", "Failed to get rdma_vif for monitor")
    endfunction

endclass
