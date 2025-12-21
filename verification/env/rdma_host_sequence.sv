import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_host_base_seq extends uvm_sequence #(rdma_host_seq_item);
    `uvm_object_utils(rdma_host_base_seq)
    `uvm_declare_p_sequencer(rdma_host_sequencer)

    function new(string name = "rdma_host_base_seq");
        super.new(name);
    endfunction

    virtual task body();
        rdma_host_seq_item tr;
        
        // ********** 新增：验证p_sequencer是否正确赋值 **********
        if (p_sequencer == null) begin
            `uvm_fatal("PSEQ_NULL", "p_sequencer is null! 类型匹配失败或赋值失败")
        end else begin
            `uvm_info("PSEQ_CHECK", $sformatf("p_sequencer路径：%s", p_sequencer.get_full_name()), UVM_MEDIUM)
        end
        // ********************************************************
        
        `uvm_info("HOST_SEQ_BODY_ENTER", "Host sequence body start executing", UVM_MEDIUM)
        
        tr = rdma_host_seq_item::type_id::create("host_tr");
        if (tr == null) begin
            `uvm_fatal("SEQ_TR_NULL", "Sequence: 无法创建rdma_host_seq_item对象！")
        end
        `uvm_info("HOST_SEQ_TR_CREATE", "Host sequence item created successfully", UVM_MEDIUM)
        
        if (!tr.randomize()) begin
            `uvm_error("SEQ_RAND_ERR", "Sequence: rdma_host_seq_item随机化失败！")
        end else begin
            `uvm_info("HOST_SEQ_TR_RAND", "Host sequence item randomize completed", UVM_MEDIUM)
        end
        
        `uvm_info("HOST_SEQ_START_ITEM", "Host sequence start_item(tr) begin", UVM_MEDIUM)
        start_item(tr);
        `uvm_info("HOST_SEQ_START_ITEM_DONE", "Host sequence start_item(tr) completed", UVM_MEDIUM)
        
        `uvm_info("HOST_SEQ_FINISH_ITEM", "Host sequence finish_item(tr) begin", UVM_MEDIUM)
        finish_item(tr);
        `uvm_info("HOST_SEQ_FINISH_ITEM_DONE", "Host sequence finish_item(tr) completed", UVM_MEDIUM)
        
        `uvm_info("SEQ_SEND_DONE", $sformatf("Sequence: 发送单拍事务 -> valid=%b, data=0x%016x, last=%b", tr.host_valid, tr.host_data, tr.host_last), UVM_MEDIUM)
    endtask
endclass