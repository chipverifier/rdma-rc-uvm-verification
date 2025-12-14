// verification/env/rdma_env.sv

// 直接导入UVM（适配老VCS，解决UVM类型识别问题，与Driver/Monitor写法一致）
import uvm_pkg::*;
`include "uvm_macros.svh"

// 继承UVM标准的uvm_env（环境容器基类）
class rdma_env extends uvm_env;
    // UVM组件注册宏（必备，使组件能被UVM工厂管理）
    `uvm_component_utils(rdma_env)

    // 保留：Driver/Monitor句柄（核心逻辑不变）
    rdma_driver  drv;
    rdma_monitor mon;
    // 保留：虚接口句柄（核心逻辑不变）
    virtual rdma_if vif;

    // 唯一的UVM标准构造函数（解决重载错误，仅保留name + parent参数）
    function new(string name = "rdma_env", uvm_component parent = null);
        super.new(name, parent);
        // 提前实例化Driver/Monitor（原有逻辑不变，可传名称便于调试）
        drv = new("drv");
        mon = new("mon");
        $display("[ENV] Env initialized: Driver and Monitor created");
    endfunction

    // 新增：设置接口方法（替代原有带vif的构造函数，完成接口赋值）
    function void set_vif(virtual rdma_if vif);
        this.vif = vif;
        // 接口赋值（原有逻辑不变，传递给Driver和Monitor）
        drv.vif = this.vif;
        mon.vif = this.vif;
        $display("[ENV] Env vif set successfully");
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

    // UVM生命周期阶段（预留，为后续全UVM化做准备，不影响当前逻辑）
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 后续可将Driver/Monitor的实例化移至此处（使用UVM工厂：type_id::create）
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        // 后续可将init/start逻辑移至此处，对接UVM的运行阶段
    endtask

endclass