// 导入UVM库和宏（所有UVM组件必备）
import uvm_pkg::*;
`include "uvm_macros.svh"

// RDMA Complete事务类：封装采样到的comp_valid信号（采样侧数据载体）
class rdma_complete_seq_item extends uvm_sequence_item;
    // 1. 定义采样对应的字段（仅需封装comp_valid，后续加字段仅需在此添加）
    logic comp_valid;  // 采样到的DUT输出完成有效信号（无需rand，因为是采样数据，非随机产生）

    // 2. 注册到UVM工厂（支持自动化功能：打印/比较/复制等）
    `uvm_object_utils_begin(rdma_complete_seq_item)
        `uvm_field_int(comp_valid, UVM_ALL_ON)
    `uvm_object_utils_end

    // 3. 构造函数（UVM对象标准格式）
    function new(string name = "rdma_complete_seq_item");
        super.new(name);
    endfunction

endclass