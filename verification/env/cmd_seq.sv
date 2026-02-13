class cmd_seq extends uvm_sequence #(cmd_item);

  `uvm_object_utils(cmd_seq)

  function new(string name="cmd_seq");
    super.new(name);
  endfunction

  virtual task body();
    cmd_item req;

    repeat (10) begin
      req = cmd_item::type_id::create("req");

      start_item(req);
      assert(req.randomize());
      finish_item(req);
    end
  endtask

endclass
