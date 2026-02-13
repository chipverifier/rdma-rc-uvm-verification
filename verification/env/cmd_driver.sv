class cmd_driver extends uvm_driver #(cmd_item);

  virtual cmd_if vif;

  `uvm_component_utils(cmd_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);

    cmd_item req;

    forever begin
      seq_item_port.get_next_item(req);

      drive_one(req);

      seq_item_port.item_done();
    end
  endtask

  task drive_one(cmd_item req);

    bit [255:0] pkt;

    pkt = req.pack();

    @(posedge vif.clk);
    vif.cmd_valid <= 1'b1;
    vif.cmd_data  <= pkt;

    @(posedge vif.clk);
    vif.cmd_valid <= 1'b0;

  endtask

endclass
