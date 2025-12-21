import uvm_pkg::*;
`include "uvm_macros.svh"

// 因为使用filelist，无需include其他文件，编译器会按filelist顺序找到类定义
class rdma_env extends uvm_env;
    `uvm_component_utils(rdma_env)

    // 组件句柄（原有代码，正确）
    rdma_agent            agt;
    rdma_host_agent       m_rdma_host_agt;
    rdma_complete_agent   m_rdma_complete_agt;
    rdma_rm               rm;
    rdma_scb              scb;

    // 接口句柄（原有代码，正确：带modport视角）
    virtual rdma_if                   vif;
    virtual rdma_host_if.drv_mp       m_rdma_host_vif;
    virtual rdma_complete_if.mon_mp   m_rdma_complete_vif;

    function new(string name = "rdma_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 修正点1：将config_db::get移到build_phase（UVM最佳实践）
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // 步骤1：获取接口（类型与句柄严格匹配，带modport）
        // 注意：TB中传递的是virtual rdma_if（无modport），所以这里用原类型获取
        if (!uvm_config_db#(virtual rdma_if)::get(this, "", "rdma_vif", vif)) begin
            `uvm_fatal("ENV_VIF_ERR", "Failed to get rdma_vif from config_db")
        end
        // 修正：获取的类型是virtual rdma_host_if.drv_mp（与句柄匹配）
        if (!uvm_config_db#(virtual rdma_host_if.drv_mp)::get(this, "", "rdma_host_vif", m_rdma_host_vif)) begin
            `uvm_fatal("ENV_VIF_ERR", "Failed to get m_rdma_host_vif from config_db")
        end
        // 修正：获取的类型是virtual rdma_complete_if.mon_mp（与句柄匹配）
        if (!uvm_config_db#(virtual rdma_complete_if.mon_mp)::get(this, "", "rdma_complete_vif", m_rdma_complete_vif)) begin
            `uvm_fatal("ENV_VIF_ERR", "Failed to get m_rdma_complete_vif from config_db")
        end

        // 步骤2：实例化组件（原有代码，正确）
        agt = rdma_agent::type_id::create("agt", this);
        m_rdma_host_agt = rdma_host_agent::type_id::create("m_rdma_host_agt", this);
        m_rdma_complete_agt = rdma_complete_agent::type_id::create("m_rdma_complete_agt", this);
        rm  = rdma_rm::type_id::create("rm",  this);
        scb = rdma_scb::type_id::create("scb", this);

        // 步骤3：将接口传递给子组件（类型与子组件需要的一致）
        // 传递rdma_if（无modport）给agt
        uvm_config_db#(virtual rdma_if)::set(this, "agt*", "rdma_vif", vif);
        // 修正：传递的类型是virtual rdma_host_if.drv_mp（与agent需要的一致）
        uvm_config_db#(virtual rdma_host_if.drv_mp)::set(this, "m_rdma_host_agt*", "rdma_host_vif", m_rdma_host_vif);
        // 修正：传递的类型是virtual rdma_complete_if.mon_mp（与agent需要的一致）
        uvm_config_db#(virtual rdma_complete_if.mon_mp)::set(this, "m_rdma_complete_agt*", "rdma_complete_vif", m_rdma_complete_vif);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // 原有代码：组件之间的连接（正确，保留）
        agt.mon.rx_ap.connect(rm.rx_imp);
        agt.mon.tx_ap.connect(scb.act_tx_imp);
        rm.exp_tx_ap.connect(scb.exp_tx_imp);

        // 可选：连接complete agent的monitor到scb（后续扩展）
        // m_rdma_complete_agt.mon.ap.connect(scb.act_comp_imp);
    endfunction

endclass