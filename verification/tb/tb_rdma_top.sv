// verification/tb/tb_rdma_top.sv
import uvm_pkg::*;
`include "uvm_macros.svh"
module tb_rdma_top;

    // ======================
    // Clock & Reset（无修改）
    // ======================
    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz

    initial begin
        rst_n = 0;
        #50;
        rst_n = 1;
    end

    // ======================
    // 接口实例化（无修改）
    // ======================
    rdma_if rdma_intf(clk, rst_n);

    // ======================
    // Env句柄（无修改）
    // ======================
    rdma_env     env;

    // ======================
    // DUT（无修改）
    // ======================
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

    // ======================
    // 修复2：直接使用全局的pkt_beat_t（无需env.mon.）
    // ======================
    pkt_beat_t exp;  // 直接使用外部定义的结构体类型

    // ======================
    // 修改：对比TX输出，改用Monitor的rx_queue（其余无修改）
    // ======================
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

    // ======================
    // Main Test（无其他修改）
    // ======================
    initial begin
        //改动1：替换原有env = new(rdma_intf); 改为UVM标准构造函数（传名称或空参数）
        env = new("rdma_env"); // 也可以写 env = new(); （使用默认名称）
        // 改动2：新增set_vif调用，给env赋值接口（核心修复）
        env.set_vif(rdma_intf);
        env.init();
        env.start();

        wait (rst_n);
        @(rdma_intf.cb);

        $display("=================================");
        $display(" RDMA RX -> TX BASIC TEST START ");
        $display("=================================");

        $display("Send Packet A (4 beats)");
        env.drv.send_packet(4, 64'h1000);

        #50;

        $display("Send Packet B (2 beats)");
        env.drv.send_packet(2, 64'h2000);

        #100;

        // 检查Monitor的rx_queue是否为空
        if (env.mon.rx_queue.size() != 0) begin
            $fatal(1, "[ERROR] Test end but Monitor rx_queue not empty!");
        end

        $display("=================================");
        $display("         TEST PASS               ");
        $display("=================================");

        $finish;
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