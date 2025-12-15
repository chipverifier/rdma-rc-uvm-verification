import "DPI-C" context function void dpi_write(input int beats);

class rdma_rm extends uvm_component;
    `uvm_component_utils(rdma_rm)

    uvm_analysis_imp #(rdma_txn, rdma_rm) rx_imp;
    uvm_analysis_port#(rdma_txn)          exp_tx_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        rx_imp    = new("rx_imp", this);
        exp_tx_ap = new("exp_tx_ap", this);
    endfunction

    function void write(rdma_txn rx);
        rdma_txn exp;
        exp = rdma_txn::type_id::create("exp");
        exp.beats  = rx.beats;
        exp.data_q = rx.data_q;
        exp_tx_ap.write(exp);
        dpi_write(rx.beats);
    endfunction
endclass
