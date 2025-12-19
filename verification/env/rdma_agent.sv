class rdma_agent extends uvm_agent;
    `uvm_component_utils(rdma_agent)

    rdma_sequencer  sqr;
    rdma_driver     drv;
    rdma_monitor    mon;

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual rdma_if vif;

    function new(string name = "rdma_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif))
            `uvm_fatal("AGENT", "rdma_vif not found")

        uvm_config_db#(virtual rdma_if)::set(this, "*", "rdma_vif", vif);

        mon = rdma_monitor::type_id::create("mon", this);

        if (is_active == UVM_ACTIVE) begin
            sqr = rdma_sequencer::type_id::create("sqr", this);
            drv = rdma_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
