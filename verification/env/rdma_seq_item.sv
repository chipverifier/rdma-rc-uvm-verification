// rdma_seq_item.sv
import uvm_pkg::*;
`include "uvm_macros.svh"
class rdma_seq_item extends uvm_sequence_item;
    `uvm_object_utils(rdma_seq_item)

    rand int unsigned beats;
    rand logic [63:0] base;

    constraint beats_c { beats inside {[1:8]}; }
    constraint base_c { base % 64 == 0; }

    function new(string name = "rdma_seq_item");
        super.new(name);
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("beats", beats, 32, UVM_DEC);
        printer.print_field("base", base, 64, UVM_HEX);
    endfunction
endclass