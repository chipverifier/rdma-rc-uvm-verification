import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_env extends uvm_env;
    `uvm_component_utils(rdma_env)

    rdma_agent       agt;
    rdma_rm        rm;
    rdma_scb       scb;

    virtual rdma_if vif;

    function new(string name = "rdma_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agt = rdma_agent::type_id::create("agt", this);
        rm  = rdma_rm::type_id::create("rm",  this);
        scb = rdma_scb::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif)) begin
            `uvm_fatal("ENV_VIF_ERR", "Failed to get rdma_vif from config_db")
        end

        uvm_config_db#(virtual rdma_if)::set(this, "agt*", "rdma_vif", vif);

        agt.mon.rx_ap.connect(rm.rx_imp);
        agt.mon.tx_ap.connect(scb.act_tx_imp);
        rm.exp_tx_ap.connect(scb.exp_tx_imp);

    endfunction

endclass
