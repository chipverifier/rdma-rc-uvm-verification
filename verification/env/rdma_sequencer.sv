// verification/env/rdma_sequencer.sv
import uvm_pkg::*;   // 导入UVM库
`include "uvm_macros.svh"  // 导入UVM宏定义
// 核心：继承uvm_sequencer#(rdma_seq_item)，指定seq_item为模板参数
// 这是sequencer唯一需要自定义的地方：绑定对应的seq_item类型
class rdma_sequencer extends uvm_sequencer#(rdma_seq_item);
    // UVM注册宏（必须，sequencer是component，用`uvm_component_utils）
    `uvm_component_utils(rdma_sequencer)

    // 构造函数（模板化固定写法，无自定义逻辑）
    function new(string name = "rdma_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // 不需要加任何其他方法！UVM基类已经实现了sequencer的所有核心逻辑
    // 这就是sequencer的全部代码，极简无冗余
endclass