// rdma_seq_item.sv中补充约束
import uvm_pkg::*;   // 导入UVM库
`include "uvm_macros.svh"  // 导入UVM宏定义
class rdma_seq_item extends uvm_sequence_item;
    `uvm_object_utils(rdma_seq_item)

    rand int beats;
    rand logic [63:0] base;

    // 约束：限制拍数和起始数据的范围
    constraint beats_c { beats inside {[1:8]}; }
    constraint base_c { base % 64 == 0; }

    function new(string name = "rdma_seq_item");
        super.new(name);
    endfunction

    // 可选：实现do_print方法，支持sprint()打印
    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("beats", beats, 32, UVM_DEC);
        printer.print_field("base", base, 64, UVM_HEX);
    endfunction
endclass