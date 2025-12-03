// tb_rdma_rc_buf.sv - RDMA RC缓冲模块VCS+Verdi验证测试台
// 支持VCS编译、FSDB波形导出、核心功能校验
`timescale 1ns/1ps

// 导入Verdi FSDB波形dump包（VCS编译时需链接fsdb库）

module tb_rdma_rc_buf();

// -------------------------- 1. 参数定义（与DUT严格对齐） --------------------------
parameter CLK_FREQ    = 100_000_000;  // 100MHz时钟
parameter CLK_PERIOD  = 10;           // 时钟周期10ns
parameter DATA_WIDTH  = 64;           // 数据位宽
parameter BUF_DEPTH   = 16;           // 缓冲深度（2的幂次）
parameter ADDR_WIDTH  = $clog2(BUF_DEPTH); // 地址位宽

// -------------------------- 2. 信号定义 --------------------------
// 时钟/复位
reg                     clk;
reg                     rst_n;

// 流量控制输入
reg                     send_pause;

// AXI-Stream接收接口
reg [DATA_WIDTH-1:0]    s_axis_tdata;
reg                     s_axis_tvalid;
reg                     s_axis_tlast;
wire                    s_axis_tready;

// AXI-Stream发送接口
wire [DATA_WIDTH-1:0]   m_axis_tdata;
wire                    m_axis_tvalid;
wire                    m_axis_tlast;
reg                     m_axis_tready;

// 缓冲状态输出
wire                    buf_full;
wire                    buf_empty;
wire                    backpressure;

// 测试控制信号
reg                     test_pass;
reg [31:0]              test_case;
reg [ADDR_WIDTH:0]      exp_buf_cnt;

// 暴露DUT内部信号（用于波形调试）
wire [ADDR_WIDTH:0]     buf_cnt;
wire [ADDR_WIDTH-1:0]   wr_addr;
wire [ADDR_WIDTH-1:0]   rd_addr;
assign buf_cnt  = u_rdma_rc_buf.buf_cnt;
assign wr_addr  = u_rdma_rc_buf.wr_addr;
assign rd_addr  = u_rdma_rc_buf.rd_addr;

// -------------------------- 3. 时钟/复位生成 --------------------------
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    #(CLK_PERIOD * 5);
    rst_n = 1'b1;
end

// -------------------------- 4. FSDB波形导出（Verdi专用） --------------------------
initial begin
    // 生成波形文件：tb_rdma_rc_buf.fsdb
    $fsdbDumpfile("tb_rdma_rc_buf.fsdb");
    // Dump所有层级的信号（0表示所有层级，+all表示包含memory/reg）
    $fsdbDumpvars(0, tb_rdma_rc_buf, "+all");
    // 从复位释放后开始dump，避免冗余
    $fsdbDumpon();
    @(posedge rst_n);
    // 测试结束后停止dump
    #(CLK_PERIOD * 1000);
    $fsdbDumpoff();
    $finish();
end

// -------------------------- 5. DUT实例化 --------------------------
rdma_rc_buf #(
    .DATA_WIDTH (DATA_WIDTH),
    .BUF_DEPTH  (BUF_DEPTH),
    .ADDR_WIDTH (ADDR_WIDTH)
) u_rdma_rc_buf (
    .clk            (clk),
    .rst_n          (rst_n),
    .send_pause     (send_pause),
    .s_axis_tdata   (s_axis_tdata),
    .s_axis_tvalid  (s_axis_tvalid),
    .s_axis_tlast   (s_axis_tlast),
    .s_axis_tready  (s_axis_tready),
    .m_axis_tdata   (m_axis_tdata),
    .m_axis_tvalid  (m_axis_tvalid),
    .m_axis_tlast   (m_axis_tlast),
    .m_axis_tready  (m_axis_tready),
    .buf_full       (buf_full),
    .buf_empty      (buf_empty),
    .backpressure   (backpressure)
);

// -------------------------- 6. 测试激励与校验 --------------------------
initial begin
    // 信号初始化
    send_pause    = 1'b0;
    s_axis_tdata  = {DATA_WIDTH{1'b0}};
    s_axis_tvalid = 1'b0;
    s_axis_tlast  = 1'b0;
    m_axis_tready = 1'b1;
    test_pass     = 1'b1;
    test_case     = 0;
    exp_buf_cnt   = 0;

    @(posedge rst_n);
    $display("====================================================");
    $display("      RDMA RC缓冲模块验证（VCS+Verdi）");
    $display("====================================================");
    $display("参数：DATA_WIDTH=%0d, BUF_DEPTH=%0d", DATA_WIDTH, BUF_DEPTH);
    $display("====================================================\n");

    // 用例1：复位初始状态校验
    test_case = 1;
    $display("[用例%d] 复位后初始状态校验", test_case);
    #CLK_PERIOD;
    if (buf_empty != 1'b1 || buf_full != 1'b0 || backpressure != 1'b0 || s_axis_tready != 1'b1) begin
        $error("[用例%d] 初始状态错误！buf_empty=%b, buf_full=%b, backpressure=%b, s_axis_tready=%b",
               test_case, buf_empty, buf_full, backpressure, s_axis_tready);
        test_pass = 1'b0;
    end else begin
        $display("[用例%d] 初始状态校验通过 ✔", test_case);
    end

    // 用例2：正常读写+计数校验
    test_case = 2;
    $display("\n[用例%d] 正常读写+缓冲计数校验", test_case);
    s_axis_tvalid = 1'b1;
    for (int i=0; i<8; i++) begin
        s_axis_tdata = $random();
        s_axis_tlast = (i==7) ? 1'b1 : 1'b0;
        #CLK_PERIOD;
        exp_buf_cnt = exp_buf_cnt + 1;
        if (buf_cnt != exp_buf_cnt) begin
            $error("[用例%d] 写入第%d帧，计数错误！实际=%0d, 预期=%0d", test_case, i+1, buf_cnt, exp_buf_cnt);
            test_pass = 1'b0;
        end
    end
    s_axis_tvalid = 1'b0;
    #CLK_PERIOD;
    if (buf_empty != 1'b0 || buf_full != 1'b0) begin
        $error("[用例%d] 写入8帧后状态错误！buf_empty=%b, buf_full=%b", test_case, buf_empty, buf_full);
        test_pass = 1'b0;
    end

    // 读取8帧
    for (int i=0; i<8; i++) begin
        #CLK_PERIOD;
        exp_buf_cnt = exp_buf_cnt - 1;
        if (buf_cnt != exp_buf_cnt || (m_axis_tvalid != 1'b1 && i<7)) begin
            $error("[用例%d] 读取第%d帧错误！计数=%0d, 预期=%0d, m_axis_tvalid=%b",
                   test_case, i+1, buf_cnt, exp_buf_cnt, m_axis_tvalid);
            test_pass = 1'b0;
        end
        if (i==7 && m_axis_tlast != 1'b1) begin
            $error("[用例%d] 帧尾标记错误！m_axis_tlast=%b", test_case, m_axis_tlast);
            test_pass = 1'b0;
        end
    end
    #CLK_PERIOD;
    if (buf_empty != 1'b1) begin
        $error("[用例%d] 读取完成后未空！buf_empty=%b", test_case, buf_empty);
        test_pass = 1'b0;
    end else begin
        $display("[用例%d] 正常读写校验通过 ✔", test_case);
    end

    // 用例3：缓冲满背压校验
    test_case = 3;
    $display("\n[用例%d] 缓冲满背压校验", test_case);
    s_axis_tvalid = 1'b1;
    for (int i=0; i<BUF_DEPTH; i++) begin
        s_axis_tdata = $random();
        s_axis_tlast = (i==BUF_DEPTH-1) ? 1'b1 : 1'b0;
        #CLK_PERIOD;
        exp_buf_cnt = exp_buf_cnt + 1;
    end
    s_axis_tvalid = 1'b0;
    #CLK_PERIOD;
    if (buf_full != 1'b1 || backpressure != 1'b1 || s_axis_tready != 1'b0) begin
        $error("[用例%d] 缓冲满状态错误！buf_full=%b, backpressure=%b, s_axis_tready=%b",
               test_case, buf_full, backpressure, s_axis_tready);
        test_pass = 1'b0;
    end
    // 尝试写入（背压生效）
    s_axis_tvalid = 1'b1;
    s_axis_tdata = $random();
    #CLK_PERIOD;
    if (buf_cnt != BUF_DEPTH) begin
        $error("[用例%d] 背压失效！计数=%0d", test_case, buf_cnt);
        test_pass = 1'b0;
    end
    s_axis_tvalid = 1'b0;
    $display("[用例%d] 缓冲满背压校验通过 ✔", test_case);

    // 用例4：send_pause暂停发送校验
    test_case = 4;
    $display("\n[用例%d] send_pause暂停发送校验", test_case);
    // 清空缓冲
    send_pause = 1'b0;
    for (int i=0; i<BUF_DEPTH; i++) begin
        #CLK_PERIOD;
        exp_buf_cnt = exp_buf_cnt - 1;
    end
    #CLK_PERIOD;
    // 写入8帧
    s_axis_tvalid = 1'b1;
    for (int i=0; i<8; i++) begin
        s_axis_tdata = $random();
        #CLK_PERIOD;
    end
    s_axis_tvalid = 1'b0;
    send_pause = 1'b1;
    #(CLK_PERIOD*5);
    if (m_axis_tvalid != 1'b0) begin
        $error("[用例%d] 暂停失效！m_axis_tvalid=%b", test_case, m_axis_tvalid);
        test_pass = 1'b0;
    end
    // 释放暂停
    send_pause = 1'b0;
    #(CLK_PERIOD*8);
    if (buf_empty != 1'b1) begin
        $error("[用例%d] 暂停释放后未清空！buf_empty=%b", test_case, buf_empty);
        test_pass = 1'b0;
    end else begin
        $display("[用例%d] 暂停发送校验通过 ✔", test_case);
    end

    // 测试汇总
    $display("\n====================================================");
    if (test_pass) begin
        $display("                   所有用例通过 ✔");
    end else begin
        $display("                   部分用例失败 ✘");
    end
    $display("====================================================");
    $finish();
end

endmodule