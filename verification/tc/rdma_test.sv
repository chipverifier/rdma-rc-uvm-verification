import uvm_pkg::*;
`include "uvm_macros.svh"

class rdma_test extends uvm_test;
    `uvm_component_utils(rdma_test)

    rdma_env env;

    function new(string name = "rdma_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = rdma_env::type_id::create("env", this);
        `uvm_info("TEST_BUILD", "RDMA Test build phase completed", UVM_MEDIUM)
    endfunction

    task run_phase(uvm_phase phase);
        rdma_fixed_seq seq;
        rdma_host_base_seq host_seq;

        phase.raise_objection(this);
        `uvm_info("TEST_RUN", "RDMA Test run phase start, creating sequences", UVM_MEDIUM)
        
        // 常规：创建序列对象
        seq = rdma_fixed_seq::type_id::create("seq");
        host_seq = rdma_host_base_seq::type_id::create("host_seq");

        // 常规：等待复位释放
        wait(env.agt.vif.rst_n);
        `uvm_info("TEST_RUN", "Reset released, start sequences after 100ps", UVM_MEDIUM)
        #100;

        // 常规：并行启动序列（直接使用Sequencer具体句柄，无类型转换）
        fork
            begin: seq_thread
                `uvm_info("SEQ_START", "Starting rdma_fixed_seq", UVM_MEDIUM)
                seq.start(env.agt.sqr); // 常规写法：直接用rdma_sequencer句柄
                `uvm_info("SEQ_FINISH", "rdma_fixed_seq completed", UVM_MEDIUM)
            end
            begin: host_seq_thread
                `uvm_info("HOST_SEQ_START", "Starting rdma_host_base_seq", UVM_MEDIUM)
                host_seq.start(env.m_rdma_host_agt.sqr); // 常规写法：直接用rdma_host_sequencer句柄
                `uvm_info("HOST_SEQ_FINISH", "rdma_host_base_seq completed", UVM_MEDIUM)
            end
        join

        #100;
        `uvm_info("TEST_RUN", "All sequences completed, drop objection", UVM_MEDIUM)
        phase.drop_objection(this);

        // 常规：超时兜底（避免仿真阻塞）
        fork
            begin: timeout_thread
                #1000000;
                `uvm_warning("SIM_TIMEOUT", "Simulation timeout, force exit")
                $finish;
            end
        join_none
    endtask
endclass