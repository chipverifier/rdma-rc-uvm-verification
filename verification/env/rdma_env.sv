// verification/env/rdma_env.sv
// 直接导入UVM（适配老VCS，与Driver/Monitor写法一致）
import uvm_pkg::*;
`include "uvm_macros.svh"

// 继承UVM标准的uvm_env（环境容器基类）
class rdma_env extends uvm_env;
    // UVM组件注册宏（必备，使组件能被UVM工厂管理）
    `uvm_component_utils(rdma_env)

    // 保留：Sequencer/Driver/Monitor句柄
    rdma_sequencer sqr;
    rdma_driver    drv;
    rdma_monitor   mon;

    // 唯一的UVM标准构造函数（解决重载错误，仅保留name + parent参数）
    function new(string name = "rdma_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 保留：初始化任务（核心逻辑不变，仅保留信号初始化）
    task init();
        $display("[ENV] Starting env initialization...");
        drv.init_signals(); // 调用Driver的信号初始化方法
        $display("[ENV] Env initialization done");
    endtask

    // 保留：启动任务（核心逻辑不变，启动Monitor的数据采集）
    task start();
        $display("[ENV] Starting env components...");
        mon.start(); // 调用Monitor的采集启动方法
        $display("[ENV] Env components started (Monitor running)");
    endtask

    // ======================
    // 改动3：完善build_phase：用UVM工厂创建组件（核心规范修改）
    // ======================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // UVM工厂创建组件（替代手动new，符合UVM规范）
        sqr = rdma_sequencer::type_id::create("sqr", this);
        drv = rdma_driver::type_id::create("drv", this);
        mon = rdma_monitor::type_id::create("mon", this);
        $display("[ENV] Driver/Monitor/Sequencer created by UVM factory in build_phase");
    endfunction

    // ======================
    // 改动2：新增connect_phase——获取接口并赋值+绑定Sequencer（核心解决并行）
    // ======================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 1. 核心：绑定Driver与Sequencer的端口（必须）
        drv.seq_item_port.connect(sqr.seq_item_export);
        $display("[ENV] Driver ↔ Sequencer bound successfully");

        // 2. 从uvm_config_db获取虚接口（关键：解决driver/monitor的vif=null问题）
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", drv.vif)) begin
            `uvm_fatal("VIF_ERR_DRV", "Failed to get rdma_vif for driver!")
        end
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", mon.vif)) begin
            `uvm_fatal("VIF_ERR_MON", "Failed to get rdma_vif for monitor!")
        end
        $display("[ENV] Driver/Monitor vif assigned in connect_phase (no null pointer!)");
    endfunction

    // ======================
    // 核心：run_phase——移除硬编码，仅启动sequence（替代原有发包逻辑）
    // ======================
    task run_phase(uvm_phase phase);
        rdma_fixed_seq fixed_seq; // 选择固定包序列
        super.run_phase(phase);
        // 关键：UVM Objection——阻止仿真在逻辑执行前结束
        phase.raise_objection(this, "Env start running");
        // 原有初始化和monitor启动（保留）
        init();
        start();
        fixed_seq = rdma_fixed_seq::type_id::create("fixed_seq"); // 创建序列
        fixed_seq.start(sqr); // 启动序列：绑定到sequencer
        phase.drop_objection(this, "Env finish running");
    endtask
endclass