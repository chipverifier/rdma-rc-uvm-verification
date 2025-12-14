// verification/env/rdma_driver.sv
import uvm_pkg::*;
`include "uvm_macros.svh"
// 改动点2：继承UVM的uvm_driver（替换原有空类，添加泛型参数uvm_sequence_item，UVM标准）
class rdma_driver extends uvm_driver#(uvm_sequence_item);
    // 改动点3：添加UVM组件注册宏（新增1行，UVM必备）
    `uvm_component_utils(rdma_driver)

    // 保留：虚接口句柄（核心逻辑不变，一行不改）
    virtual rdma_if vif;

    // 改动点4：调整构造函数为UVM标准构造函数（name + parent）
    // 原有new(virtual rdma_if vif)改为UVM标准格式，接口后续通过外部赋值（暂不改）
    function new(string name = "rdma_driver", uvm_component parent = null);
        super.new(name, parent); // 调用父类构造函数
    endfunction

    // 保留：核心方法send_packet（完全不变，一行不改）
    task send_packet(input int beats, input logic [63:0] base);
        int i;
        $display("[DRIVER] Start sending packet: beats=%0d, base=%h", beats, base);
        begin
            for (i = 0; i < beats; i++) begin
                @(vif.cb);
                vif.cb.rx_valid <= 1'b1;
                vif.cb.rx_data  <= base + i;
                vif.cb.rx_last  <= (i == beats - 1);
            end
            @(vif.cb);
            vif.cb.rx_valid <= 1'b0;
            vif.cb.rx_last  <= 1'b0;
        end
        $display("[DRIVER] Finish sending packet: beats=%0d", beats);
    endtask

    // 保留：辅助方法init_signals（完全不变，一行不改）
    task init_signals();
        $display("[DRIVER] Initializing signals...");
        vif.cb.rx_valid <= 1'b0;
        vif.cb.rx_data  <= 64'h0;
        vif.cb.rx_last  <= 1'b0;
    endtask

endclass