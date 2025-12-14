class rdma_packet extends uvm_sequence_item;
    rand logic [63:0] data[];
    rand bit          last[];

    `uvm_object_utils(rdma_packet)

    function new(string name="rdma_packet");
        super.new(name);
    endfunction
endclass
