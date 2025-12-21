import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_host_driver extends uvm_driver #(rdma_host_seq_item);
    `uvm_component_utils(rdma_host_driver)

    virtual rdma_host_if.drv_mp vif;
    // 保留显式绑定事务类型（核心避坑代码，保留）
    typedef rdma_host_seq_item REQ;
    typedef rdma_host_seq_item RSP;
    REQ req; // 对应参考driver中的req声明位置

    function new(string name = "rdma_host_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("DRV_BUILD_ENTER", "Host Driver build phase start executing", UVM_MEDIUM)
        // 对齐参考driver的接口获取逻辑（去掉多余格式化，保持简洁）
        if (!uvm_config_db#(virtual rdma_host_if.drv_mp)::get(this, "", "rdma_host_vif", vif)) begin
            `uvm_fatal("DRV_NO_VIF", "Driver: 无法从Config DB获取rdma_host_if接口！")
        end
        `uvm_info("DRV_BUILD_SUCCESS", "Host Driver get interface successfully", UVM_MEDIUM)
    endfunction

    // ********** 核心修改：改用run_phase，和参考driver完全对齐 **********
    virtual task run_phase(uvm_phase phase);
        `uvm_info("DRV_RUN_ENTER", "Host Driver run phase start executing", UVM_MEDIUM)

        // 1. 初始化接口信号（对齐参考driver的vif.cb.rx_valid <= 0）
        vif.drv_cb.host_valid <= 1'b0;
        vif.drv_cb.host_data  <= 64'd0;
        vif.drv_cb.host_last  <= 1'b0;
        `uvm_info("DRV_INIT_SIGNAL", "Host Driver initialized interface signals to 0", UVM_MEDIUM)

        // 2. 等待复位释放（对齐参考driver的if (!vif.rst_n) @(posedge vif.rst_n)）
        if (!vif.rst_n) begin
            `uvm_info("DRV_WAIT_RST", $sformatf("Host Driver waiting for rst_n release (rst_n = %b)", vif.rst_n), UVM_MEDIUM)
            @(posedge vif.rst_n); // 沿触发，和参考driver一致
            `uvm_info("DRV_RST_RELEASED", "Host Driver rst_n released (posedge detected)", UVM_MEDIUM)
        end

        // 3. 无限循环处理事务（对齐参考driver的forever逻辑，无额外延迟）
        forever begin
            `uvm_info("DRV_WAIT_ITEM", "Host Driver waiting for sequence item from Sequencer", UVM_MEDIUM)
            seq_item_port.get_next_item(req);
            // 补充打印：接收到的事务详情（保留原有格式化）
            `uvm_info("DRV_RECV_ITEM", $sformatf("Host Driver received item: valid=%b, data=0x%016x, last=%b", req.host_valid, req.host_data, req.host_last), UVM_MEDIUM)
            // 驱动事务到接口（对应参考driver的send_packet）
            drive_transaction(req);
            seq_item_port.item_done();
            `uvm_info("DRV_ITEM_DONE", "Host Driver notify Sequencer item processed completed", UVM_MEDIUM)
        end
    endtask

    // 对应参考driver的send_packet，保留驱动逻辑+打印
    virtual task drive_transaction(rdma_host_seq_item tr);
        `uvm_info("DRV_DRIVE_START", "Host Driver start driving transaction to interface", UVM_MEDIUM)
        // 对齐参考driver的cb触发逻辑
        @(vif.drv_cb);
        vif.drv_cb.host_valid <= tr.host_valid;
        vif.drv_cb.host_data  <= tr.host_data;
        vif.drv_cb.host_last  <= tr.host_last;
        `uvm_info("DRV_DRIVE_DONE", $sformatf("Host Driver drive completed: valid=%b, data=0x%016x, last=%b", tr.host_valid, tr.host_data, tr.host_last), UVM_MEDIUM)

        // 可选：对齐参考driver的最后置0（参考driver在send_packet最后置0，这里补充）
        @(vif.drv_cb);
        vif.drv_cb.host_valid <= 1'b0;
        vif.drv_cb.host_last  <= 1'b0;
        `uvm_info("DRV_DRIVE_RESET", "Host Driver reset interface signals after driving", UVM_MEDIUM)
    endtask

endclass