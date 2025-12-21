// RDMA Host Agent：封装Sqr、Drv，统一管理接口和组件连接
class rdma_host_agent extends uvm_agent;
    // 1. 注册到UVM工厂（组件必须）
    `uvm_component_utils(rdma_host_agent)

    // 2. 声明子组件句柄（与之前编写的组件一一对应）
    rdma_host_sequencer sqr; // 序列器
    rdma_host_driver    drv; // 驱动器
    // rdma_host_monitor  mon; // Monitor预留（后续需采样时添加）

    // 3. 声明Agent的接口句柄（接收Test传递的接口，再分发给Drv）
    virtual rdma_host_if.drv_mp vif;

    // 4. 构造函数（UVM组件标准格式）
    function new(string name = "rdma_host_agent", uvm_component parent = null);
        super.new(name, parent);
        is_active = UVM_ACTIVE;
    endfunction

    // 5. Build Phase：创建子组件 + 接收接口 + 传递接口给Drv
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 步骤1：从Test获取接口（Config DB路径为当前Agent，Test需对应设置）
        if (!uvm_config_db#(virtual rdma_host_if.drv_mp)::get(this, "", "rdma_host_vif", vif)) begin
            `uvm_fatal("AGT_NO_VIF", "Agent: 无法从Config DB获取rdma_host_if接口！")
        end

        // 步骤2：根据Agent模式创建子组件（UVM_ACTIVE=主动模式，驱动DUT）
        if (is_active == UVM_ACTIVE) begin
            sqr = rdma_host_sequencer::type_id::create("sqr", this); // 创建序列器
            drv = rdma_host_driver::type_id::create("drv", this);   // 创建驱动器

            // 步骤3：将接口传递给Drv（放入Config DB，路径为"drv"，Drv可直接获取）
            uvm_config_db#(virtual rdma_host_if.drv_mp)::set(this, "drv", "rdma_host_vif", vif);
        end

        // 步骤4：预留Monitor创建（被动模式时仅创建Monitor，用于采样）
        // mon = rdma_host_monitor::type_id::create("mon", this);
        // uvm_config_db#(virtual rdma_host_if.mon_mp)::set(this, "mon", "rdma_host_vif", vif);
    endfunction

    // 6. Connect Phase：连接Sequencer和Driver（核心连接逻辑）
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 仅在主动模式下连接：Driver的seq_item_port → Sequencer的seq_item_export
        if (is_active == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction

endclass