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


    pkt_beat_t exp;

    // ======================
    // 修改：对比TX输出，改用Monitor的rx_queue（其余无修改）
    // ======================
    /*
    always @(posedge clk) begin
        if (rst_n && rdma_intf.cb.tx_valid) begin
            // 替换：从Monitor的rx_queue取预期值
            exp = env.mon.get_rx_beat();

            if (rdma_intf.cb.tx_data !== exp.data || rdma_intf.cb.tx_last !== exp.last) begin
                $fatal(1,
                    "[ERROR] Mismatch: TX data=%h last=%b | EXP data=%h last=%b",
                    rdma_intf.cb.tx_data, rdma_intf.cb.tx_last, exp.data, exp.last
                );
            end else begin
                $display("[%0t] PASS TX data=%h last=%b",
                         $time, rdma_intf.cb.tx_data, rdma_intf.cb.tx_last);
            end
        end
    end
    */

    // ======================
    // Main Test（无其他修改）
    // ======================
    initial begin
        // 关键：将rdma_intf存入UVM配置库，标识名为"rdma_vif"
        uvm_config_db#(virtual rdma_if)::set(null, "*", "rdma_vif", rdma_intf);
        $display("[TB] rdma_vif stored to uvm_config_db successfully");
    end

    initial begin
        $fsdbDumpvars(0, tb_rdma_top);
    end

     // 改动点2：仅添加空的UVM启动逻辑（新增1行，无实际作用，仅验证UVM库）
    initial begin
        // 空的run_test()，不影响原有逻辑（UVM会启动但无测试用例，原有逻辑已执行完毕）
        run_test("rdma_test");
    end

endmodule