// RDMA RC QP状态机验证测试台（SystemVerilog）
// 路径：verification/tb_rdma_rc_qp.sv
module tb_rdma_rc_qp;

// ========== 参数定义 ==========
parameter QPN_WIDTH = 16;
parameter CLK_PERIOD = 10; // 时钟周期10ns（100MHz）

// ========== 信号声明 ==========
logic                 clk;
logic                 rst_n;
logic [QPN_WIDTH-1:0] local_qpn;
logic [QPN_WIDTH-1:0] remote_qpn;
logic                 cfg_valid;
logic                 cmd_connect;
logic                 cmd_disconnect;
logic [2:0]           qp_state;
logic                 qp_ready;

// ========== RDMA RC QP状态宏定义（与DUT对齐） ==========
localparam RESET  = 3'b000;
localparam INIT   = 3'b001;
localparam RTR    = 3'b010;
localparam RTS    = 3'b011;
localparam ERROR  = 3'b111;

// ========== 实例化DUT（RTL模块） ==========
rdma_rc_qp #(
    .QPN_WIDTH(QPN_WIDTH)
) u_rdma_rc_qp (
    .clk            (clk),
    .rst_n          (rst_n),
    .local_qpn      (local_qpn),
    .remote_qpn     (remote_qpn),
    .cfg_valid      (cfg_valid),
    .cmd_connect    (cmd_connect),
    .cmd_disconnect (cmd_disconnect),
    .qp_state       (qp_state),
    .qp_ready       (qp_ready)
);
// ========== 时钟生成 ==========
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ========== 核心测试激励序列 ==========
initial begin
    // 1. 初始化信号
    rst_n          = 1'b0;
    local_qpn      = 16'h1234; // 本地QPN配置
    remote_qpn     = 16'h0000; // 远程QPN初始为0
    cfg_valid      = 1'b0;
    cmd_connect    = 1'b0;
    cmd_disconnect = 1'b0;

    // 2. 释放复位
    #20 rst_n = 1'b1;
    $display("[%0t ns] 复位释放，进入RESET状态", $time);

    // 3. 配置QP，进入INIT状态
    #10 cfg_valid = 1'b1;
    #10 cfg_valid = 1'b0;
    $display("[%0t ns] QP配置有效，触发进入INIT状态", $time);

    // 4. 配置远程QPN，发送连接命令，进入RTR状态
    #30 remote_qpn = 16'h5678; // 远程QPN配置为5678
    #10 cmd_connect = 1'b1;
    #10 cmd_connect = 1'b0;
    $display("[%0t ns] 发送连接命令，触发进入RTR状态", $time);

    // 5. 远程QP确认，再次发送连接命令，进入RTS状态（核心工作状态）
    #30 cmd_connect = 1'b1;
    #10 cmd_connect = 1'b0;
    $display("[%0t ns] 远程QP确认，触发进入RTS状态（数据传输就绪）", $time);

    // 6. 运行一段时间后，发送断开命令，回到RESET状态
    #100 cmd_disconnect = 1'b1;
    #10 cmd_disconnect = 1'b0;
    $display("[%0t ns] 发送断开命令，触发回到RESET状态", $time);

    // 7. 仿真结束
    #50 $display("[%0t ns] 仿真结束", $time);
    $finish;
end

// ========== 状态断言验证（SV特性，确保状态转移正确） ==========
// 断言1：复位时必须处于RESET状态
assert property (@(posedge clk) !rst_n |-> qp_state == RESET) else
    $error("[ASSERT ERROR] 复位时QP状态非RESET！");

// 断言2：配置有效后，INIT状态必须就绪
assert property (@(posedge clk) (qp_state == INIT) |-> qp_ready) else
    $error("[ASSERT ERROR] INIT状态未就绪！");

// 断言3：RTS状态必须就绪（核心工作状态）
assert property (@(posedge clk) (qp_state == RTS) |-> qp_ready) else
    $error("[ASSERT ERROR] RTS状态未就绪（无法传输数据）！");

// ========== 波形Dump（适配sim/wave目录） ==========
initial begin
    $dumpfile("../sim/wave/tb_qp.vcd"); // 波形文件输出到sim/wave
    $dumpvars(0, tb_rdma_rc_qp);       // Dump所有层级信号
    $dumpflush; // 强制刷新波形缓存

    // 新增FSDB Dump核心代码（关键）
    $fsdbDumpfile("../sim/wave/tb_qp.fsdb");  // 指定FSDB输出路径（与VCD同目录）
    $fsdbDumpvars(0, tb_rdma_rc_qp);          // Dump所有层级的信号（0表示全层级）
    $fsdbDumpMDA();                            // 可选：支持多维数组信号Dump（RDMA可能用到）
    $fsdbAutoSwitchDumpfile(1024, "../sim/wave/tb_qp.fsdb", 2); // 可选：大仿真时自动切分FSDB（按1GB切分）
end

endmodule