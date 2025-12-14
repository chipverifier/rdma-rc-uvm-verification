// verification/env/rdma_monitor.sv
// 改动点1：添加UVM直接导入（和Driver写法一致，适配老VCS）
import uvm_pkg::*;
`include "uvm_macros.svh"

// 保留：全局定义的pkt_beat_t结构体（原有逻辑，不变）
typedef struct {
    logic [63:0] data;
    logic last;
} pkt_beat_t;

// 改动点2：继承UVM的uvm_monitor基类（替换原有空类）
class rdma_monitor extends uvm_monitor;
    // 改动点3：添加UVM组件注册宏（必备）
    `uvm_component_utils(rdma_monitor)

    // 保留：虚接口句柄（核心逻辑不变）
    virtual rdma_if vif;

    // 保留：存储采集到的RX数据队列（核心逻辑不变）
    pkt_beat_t rx_queue[$];

    // 改动点4：适配UVM标准构造函数（name + parent）
    // 原有构造函数：function new(virtual rdma_if vif);
    // 改为UVM标准格式，接口后续在Env中赋值
    function new(string name = "rdma_monitor", uvm_component parent = null);
        super.new(name, parent); // 调用父类构造函数
    endfunction

    // 保留：核心方法——启动数据采集（原有逻辑，不变）
    task start();
        $display("[MONITOR] Start collecting RX data...");
        $display("[MONITOR] Start collecting TX data...");
        fork
            collect_rx_data(); // 采集RX数据
            // 若有TX数据采集逻辑，保留即可
        join_none
    endtask

    // 保留：核心方法——采集RX数据（原有逻辑，不变）
    task collect_rx_data();
        forever begin
            @(posedge vif.clk);
            if (vif.rst_n && vif.rx_valid) begin
                pkt_beat_t beat;
                beat.data = vif.rx_data;
                beat.last = vif.rx_last;
                rx_queue.push_back(beat);
                $display("[MONITOR][RX] time=%0t, data=%h, last=%b", $time, beat.data, beat.last);
            end
        end
    endtask

    // ======================
    // 核心改动：在Monitor的build_phase中直接获取接口
    // ======================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 与Driver一致：获取TB中存储的"rdma_vif"接口
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif)) begin
            $fatal(1, "[MONITOR] Failed to get 'rdma_vif' from uvm_config_db!");
        end
        $display("[MONITOR] Successfully got 'rdma_vif' from uvm_config_db");
    endfunction

    // 保留：核心方法——获取队列中的RX数据（原有逻辑，不变）
    function pkt_beat_t get_rx_beat();
        if (rx_queue.size() == 0) begin
            $fatal(1, "[MONITOR] Error: rx_queue is empty!");
        end
        get_rx_beat = rx_queue.pop_front();
    endfunction

endclass