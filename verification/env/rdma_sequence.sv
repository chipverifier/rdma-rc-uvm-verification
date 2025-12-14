// verification/env/rdma_sequence.sv
import uvm_pkg::*;
`include "uvm_macros.svh"

// ########################### 基础序列：rdma_base_seq（所有序列的父类） ###########################
// 作用：封装通用逻辑（如创建seq_item、基础赋值），子类可继承复用
class rdma_base_seq extends uvm_sequence#(rdma_seq_item);
    // UVM注册宏（sequence是object，用`uvm_object_utils）
    `uvm_object_utils(rdma_base_seq)

    // 可选：定义序列的配置参数（比如发包数量，可从test/env传递）
    int pkt_num = 1;  // Default: send 1 packet

    // 构造函数（固定写法）
    function new(string name = "rdma_base_seq");
        super.new(name);
    endfunction

    // 核心：pre_body() —— 发送前的初始化（可选，比如打印日志、配置参数）
    virtual task pre_body();
        super.pre_body();
        $display("[%s] Sequence start execution (send %0d packets)", this.get_name(), pkt_num);
    endtask

    // 核心：body() —— 所有激励逻辑的入口（重点实现）
    virtual task body();
        // 判空：防止seq_item创建失败（工业级代码的健壮性处理）
        if (starting_phase != null) begin
            starting_phase.raise_objection(this); // Associate phase to prevent UVM exit early
        end

        // 循环发送指定数量的包（通用逻辑，子类可直接复用）
        // 修改：用for循环替代repeat循环，手动定义索引变量idx
        for (int idx = 0; idx < pkt_num; idx++) begin
            rdma_seq_item req;
            // 1. 创建seq_item对象（UVM工厂机制，必须用type_id::create）
            req = rdma_seq_item::type_id::create("req");

            // 2. 给seq_item赋值（两种方式：固定值 / 随机化，二选一或结合）
            // 方式1：固定值赋值（新手入门，简单直观）
            // req.beats = 4;
            // req.base = 64'h1000;

            // 方式2：随机化赋值（工业级常用，灵活生成激励，依赖seq_item的约束）
            if (!req.randomize()) begin
                // 随机化失败时的致命错误处理（健壮性）
                `uvm_fatal("SEQ_RAND_ERR", "rdma_seq_item randomization failed!")
            end

            // 3. 核心：把seq_item发送给sequencer（阻塞，直到driver处理完成）
            start_item(req);  // Send request to sequencer
            finish_item(req); // Send seq_item to driver officially

            // 4. 打印发送的seq_item信息（调试用，调用seq_item的do_print方法）
            $display("[%s] Sent seq_item (No.%0d)：\n%s", this.get_name(), idx+1, req.sprint());
        end

        if (starting_phase != null) begin
            starting_phase.drop_objection(this); // Release objection
        end
    endtask

    // 核心：post_body() —— 发送后的收尾（可选，比如打印日志）
    virtual task post_body();
        super.post_body();
        $display("[%s] Sequence execution completed", this.get_name());
    endtask

endclass

// ########################### 派生序列1：rdma_fixed_seq（固定参数发包） ###########################
// 作用：继承base_seq，重写为固定参数发包（比如只发4拍、base=0x1000的包）
class rdma_fixed_seq extends rdma_base_seq;
    `uvm_object_utils(rdma_fixed_seq)

    function new(string name = "rdma_fixed_seq");
        super.new(name);
        pkt_num = 2; // Override: send 2 fixed packets
    endfunction

    // 重写body()：固定参数赋值（覆盖base_seq的随机化逻辑）
    virtual task body();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this);
        end

        // 修复：用for循环+自定义索引idx替代repeat_index
        for (int idx = 0; idx < pkt_num; idx++) begin
            rdma_seq_item req;
            req = rdma_seq_item::type_id::create("req");

            // 固定参数赋值（第一个包4拍，第二个包2拍）
            if (idx == 0) begin // Use custom idx to judge loop times
                req.beats = 4;
                req.base = 64'h1000;
            end else begin
                req.beats = 2;
                req.base = 64'h2000;
            end

            start_item(req);
            finish_item(req);
            $display("[%s] Sent fixed packet (No.%0d)：beats=%0d, base=%h", this.get_name(), idx+1, req.beats, req.base);
        end

        if (starting_phase != null) begin
            starting_phase.drop_objection(this);
        end
    endtask

endclass

// ########################### 派生序列2：rdma_rand_seq（随机化发包，工业级常用） ###########################
// 作用：继承base_seq，纯随机化发包（依赖seq_item的约束）
class rdma_rand_seq extends rdma_base_seq;
    `uvm_object_utils(rdma_rand_seq)

    function new(string name = "rdma_rand_seq");
        super.new(name);
        pkt_num = 5; // Override: send 5 random packets
    endfunction

    // 无需重写body()，直接复用base_seq的随机化逻辑即可（这就是继承的好处）
    // 如需扩展，可重写body()添加自定义随机化约束（比如临时修改seq_item的约束）
endclass