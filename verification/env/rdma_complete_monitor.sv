// 导入UVM库和宏
import uvm_pkg::*;
`include "uvm_macros.svh"

// RDMA Complete Monitor：核心功能是采样DUT输出的comp_valid信号并发送
class rdma_complete_monitor extends uvm_monitor;
    // 1. 注册到UVM工厂（组件必须）
    `uvm_component_utils(rdma_complete_monitor)

    // 2. 声明虚拟接口句柄（使用mon_mp视角，仅操作mon_cb时钟块）
    virtual rdma_complete_if.mon_mp vif;

    // 3. 声明分析端口（UVM中传递采样数据的标准端口，发送给记分板等）
    // 泛型参数为采样的事务类型，支持多个组件订阅
    uvm_analysis_port#(rdma_complete_seq_item) ap;

    // 4. 构造函数（UVM组件标准格式）
    function new(string name = "rdma_complete_monitor", uvm_component parent = null);
        super.new(name, parent);
        // 初始化分析端口（必须在构造函数中创建）
        ap = new("ap", this);
    endfunction

    // 5. Build Phase：从Config DB获取Agent传递的接口（核心步骤）
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从当前组件路径获取接口（Agent会将接口传递到此处）
        if (!uvm_config_db#(virtual rdma_complete_if.mon_mp)::get(this, "", "rdma_complete_vif", vif)) begin
            `uvm_fatal("MON_NO_VIF", "Monitor: 无法从Config DB获取rdma_complete_if接口！")
        end
    endfunction

    // 6. Main Phase：持续采样接口信号（Monitor核心逻辑）
    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        // 死循环：持续采样直到仿真结束
        forever begin
            // 步骤1：等待时钟上升沿（通过时钟块同步，采到稳定的DUT输出信号）
            @(vif.mon_cb);
            // 步骤2：采样信号并封装为seq_item
            collect_transaction();
        end
    endtask

    // 7. 核心采样方法：将接口信号封装为seq_item（后续加字段仅需修改此方法）
    virtual task collect_transaction();
        // 创建seq_item对象（存储采样数据）
        rdma_complete_seq_item tr = rdma_complete_seq_item::type_id::create("comp_tr");

        // 物理信号 → 事务字段（一一映射，后续加字段仅需添加此处）
        tr.comp_valid = vif.mon_cb.comp_valid;

        // 步骤3：通过分析端口发送事务（订阅者会收到此数据）
        ap.write(tr);

        // 可选：打印采样信息（调试用，可通过UVM_VERBOSITY控制）
        `uvm_info("MON_SAMPLE", 
                  $sformatf("Monitor: 采样到comp_valid=%b", tr.comp_valid),
                  UVM_LOW)
    endtask

endclass