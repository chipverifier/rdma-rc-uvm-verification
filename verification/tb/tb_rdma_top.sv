// verification/tb/tb_rdma_top.sv
import uvm_pkg::*;
`include "uvm_macros.svh"
module tb_rdma_top;

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz

    initial begin
        rst_n = 0;
        #50;
        rst_n = 1;
    end

    rdma_if rdma_intf(clk, rst_n);
    rdma_top dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_valid (rdma_intf.rx_valid),
        .rx_data  (rdma_intf.rx_data),
        .rx_last  (rdma_intf.rx_last),
        .tx_valid (rdma_intf.tx_valid),
        .tx_data  (rdma_intf.tx_data),
        .tx_last  (rdma_intf.tx_last)
    );



    initial begin
        // 关键：将rdma_intf存入UVM配置库，标识名为"rdma_vif"
        uvm_config_db#(virtual rdma_if)::set(null, "*", "rdma_vif", rdma_intf);
        $display("[TB] rdma_vif stored to uvm_config_db successfully");
    end

    initial begin
        $fsdbDumpvars(0, tb_rdma_top);
    end

    initial begin
        run_test("rdma_test");
    end

endmodule