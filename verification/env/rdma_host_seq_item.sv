// Import UVM package and macros (required for all UVM components)
import uvm_pkg::*;
`include "uvm_macros.svh"

// RDMA Host sequence item: Encapsulates all data to be driven to DUT's host interface
class rdma_host_seq_item extends uvm_sequence_item;
    // 1. Declare fields corresponding to rdma_host_if signals
    // (Modify these fields directly if you need to add/remove signals later)
    rand logic        host_valid;  // Corresponding to interface's host_valid
    rand logic [63:0] host_data;   // Corresponding to interface's host_data (64-bit)
    rand logic        host_last;   // Corresponding to interface's host_last

    // 2. Register class and fields to UVM factory (mandatory for UVM automation)
    // UVM_ALL_ON: Enables all automation features (print/compare/copy etc.)
    `uvm_object_utils_begin(rdma_host_seq_item)
        `uvm_field_int(host_valid, UVM_ALL_ON)
        `uvm_field_int(host_data,  UVM_ALL_ON)
        `uvm_field_int(host_last,  UVM_ALL_ON)
    `uvm_object_utils_end

    // 3. Constructor (required for UVM object instantiation)
    function new(string name = "rdma_host_seq_item");
        super.new(name);
    endfunction

    // 4. Optional constraint: Ensure valid logic (avoid meaningless random values)
    // Rule: If host_last is 1 (end of frame), host_valid must be 1 (data valid)
    constraint c_last_valid {
        host_last -> host_valid == 1'b1; 
    }

endclass