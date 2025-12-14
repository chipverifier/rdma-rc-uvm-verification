// verification/env/rdma_driver.sv
import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_driver extends uvm_driver#(rdma_seq_item);
    `uvm_component_utils(rdma_driver)
    virtual rdma_if vif;

    function new(string name = "rdma_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 核心：run_phase——循环接收seq_item并发包
    task run_phase(uvm_phase phase);
        forever begin
            rdma_seq_item req;
            // 从sequencer接收seq_item（阻塞）
            seq_item_port.get_next_item(req);
            // 调用原有发包方法，传入seq_item的参数
            send_packet(req.beats, req.base);
            // 告诉sequencer处理完成
            seq_item_port.item_done();
        end
    endtask

    // 原有：send_packet方法（保留，参数不变）
    task send_packet(int beats, logic [63:0] base);
        // 原有发包逻辑（不变）
        $display("[DRIVER] Start sending packet: beats=%0d, base=%h", beats, base);
        // ... 你的发包代码 ...
        $display("[DRIVER] Finish sending packet: beats=%0d", beats);
    endtask

    // 原有：init_signals方法（保留）
    task init_signals();
        $display("[DRIVER] Initializing signals...");
        // ... 原有信号初始化代码 ...
    endtask
endclass