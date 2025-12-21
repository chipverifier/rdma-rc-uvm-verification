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

    // 实例化物理接口（原有代码，正确）
    rdma_if rdma_intf(clk, rst_n);
    rdma_host_if rdma_host_intf(clk, rst_n);
    rdma_complete_if rdma_complete_intf(clk, rst_n);

    // 连接DUT（原有代码，正确）
    rdma_top dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_valid   (rdma_intf.rx_valid),
        .rx_data    (rdma_intf.rx_data),
        .rx_last    (rdma_intf.rx_last),
        .host_valid (rdma_host_intf.host_valid),
        .host_data  (rdma_host_intf.host_data),
        .host_last  (rdma_host_intf.host_last),
        .tx_valid   (rdma_intf.tx_valid),
        .tx_data    (rdma_intf.tx_data),
        .tx_last    (rdma_intf.tx_last),
        .comp_valid (rdma_complete_intf.comp_valid)
    );

    initial begin
        // 优化点1：传递对应modport视角的接口（而非整个接口）
        // 路径用"uvm_test_top.env"（指定到env层级，而非通配符*，避免全局匹配的潜在冲突）
        uvm_config_db#(virtual rdma_if)::set(null, "uvm_test_top.env", "rdma_vif", rdma_intf);
        // 传递host接口的drv_mp视角（给Host Agent/Driver）
        uvm_config_db#(virtual rdma_host_if.drv_mp)::set(null, "uvm_test_top.env", "rdma_host_vif", rdma_host_intf);
        // 传递complete接口的mon_mp视角（给Complete Agent/Monitor）
        uvm_config_db#(virtual rdma_complete_if.mon_mp)::set(null, "uvm_test_top.env", "rdma_complete_vif", rdma_complete_intf);
        
        $display("[TB] Interfaces stored to uvm_config_db successfully");
    end

    initial begin
        $fsdbDumpvars(0, tb_rdma_top);
    end

    initial begin
        // **************************
        // 正确写法：fork必须在initial的begin/end内
        // **************************
        fork
            begin
                #10000000ps; // 1ms超时
                `uvm_warning("SIM_TIMEOUT", "Simulation timeout, force exit")
                $finish; // 强制退出
            end
            begin
                run_test("rdma_test"); // 启动UVM测试
            end
        join
    end

endmodule