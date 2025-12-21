// 导入UVM库和宏
import uvm_pkg::*;
`include "uvm_macros.svh"

// RDMA Complete Agent：封装Monitor，统一管理采样侧接口
class rdma_complete_agent extends uvm_agent;
    // 1. 注册到UVM工厂（组件必须）
    `uvm_component_utils(rdma_complete_agent)

    // 2. 声明子组件句柄（仅需Monitor，无Sequencer/Driver）
    rdma_complete_monitor mon;

    // 3. 声明Agent的接口句柄（接收Test传递的接口，再分发给Monitor）
    virtual rdma_complete_if.mon_mp vif;

    // 4. 构造函数（UVM组件标准格式）
    function new(string name = "rdma_complete_agent", uvm_component parent = null);
        super.new(name, parent);
        // 采样侧Agent固定为被动模式（无需驱动，仅采样），可直接设置
        is_active = UVM_PASSIVE;
    endfunction

    // 5. Build Phase：创建Monitor + 接收接口 + 传递接口给Monitor
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 步骤1：从Test获取接口（Config DB路径为当前Agent，Test需对应设置）
        if (!uvm_config_db#(virtual rdma_complete_if.mon_mp)::get(this, "", "rdma_complete_vif", vif)) begin
            `uvm_fatal("AGT_NO_VIF", "Agent: 无法从Config DB获取rdma_complete_if接口！")
        end

        // 步骤2：创建Monitor（采样侧唯一子组件）
        mon = rdma_complete_monitor::type_id::create("mon", this);

        // 步骤3：将接口传递给Monitor（放入Config DB，路径为"mon"，Monitor可直接获取）
        uvm_config_db#(virtual rdma_complete_if.mon_mp)::set(this, "mon", "rdma_complete_vif", vif);
    endfunction

    // 6. Connect Phase：采样侧无额外连接逻辑（Monitor的分析端口由外部组件订阅）
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 若需要，可在此处将Monitor的分析端口连接到Agent的分析端口（透传，后续扩展用）
        // ap = mon.ap; // 需先在Agent中声明分析端口，当前基础场景无需
    endfunction

endclass