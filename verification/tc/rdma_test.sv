// verification/tb/rdma_test.sv

// 定义最简的UVM Test用例（仅继承+注册，无任何逻辑）
class rdma_test extends uvm_test;
    // UVM组件注册宏（必须）
    `uvm_component_utils(rdma_test)
    rdma_env env; // Env句柄
    // 标准UVM构造函数
    function new(string name = "rdma_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 创建Env（纳入UVM层次，其phase会自动执行）
        env = rdma_env::type_id::create("env", this);
        $display("[TEST] rdma_env created in build_phase");
    endfunction

    // 新增：添加run_phase，使用objection阻止UVM立刻结束，添加延迟
    task run_phase(uvm_phase phase);
        // 关键：UVM的objection机制，阻止仿真立刻结束
        phase.raise_objection(this, "Keep simulation running for original logic");

        // 添加足够的延迟（比原有测试逻辑的总时间长，如200ns，可根据需要调整）
        // 原有逻辑：复位50ns + 发送数据包 + 等待100ns，总时间约200ns
        #1000ns;

        // 释放objection，允许仿真结束
        phase.drop_objection(this, "Original logic finished");
    endtask

endclass