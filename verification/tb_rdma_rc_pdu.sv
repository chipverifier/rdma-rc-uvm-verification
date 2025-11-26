// RDMA RC PDU解析模块独立测试台
// 功能：脱离QP状态机，通过硬编码模拟QP状态，验证PDU解析、帧类型区分、错误检测逻辑
// 测试用例：覆盖不同QP状态+不同Opcode+有效/无效QPN的核心场景
module tb_rdma_rc_pdu;

// 参数定义（与PDU解析模块对齐）
parameter QPN_WIDTH     = 16;
parameter PSN_WIDTH     = 24;
parameter OPCODE_WIDTH  = 8;
parameter DATA_WIDTH    = 64;
parameter CLK_PERIOD    = 10; // 时钟周期10ns（100MHz）

// PDU字段偏移定义（与PDU解析模块对齐）
parameter OPCODE_OFFSET = 56;
parameter QPN_OFFSET    = 32;
parameter PSN_OFFSET    = 8;

// 信号声明
logic                 clk;
logic                 rst_n;
logic [DATA_WIDTH-1:0] pdu_data;
logic                 pdu_valid;
logic [2:0]           qp_state;   // 模拟QP状态（硬编码）
logic [QPN_WIDTH-1:0] local_qpn;
logic [QPN_WIDTH-1:0] remote_qpn;

// PDU解析模块输出信号
logic [OPCODE_WIDTH-1:0]  pdu_opcode;
logic [QPN_WIDTH-1:0]     pdu_qpn;
logic [PSN_WIDTH-1:0]     pdu_psn;
logic                     is_data_frame;
logic                     is_control_frame;
logic                     opcode_err;
logic                     qpn_mismatch_err;
logic                     pdu_parse_done;

// QP状态定义（与PDU解析模块对齐）
localparam RESET  = 3'b000;
localparam INIT   = 3'b001;
localparam RTR    = 3'b010;
localparam RTS    = 3'b011;
localparam ERROR  = 3'b111;

// Opcode测试值（与PDU解析模块的范围对齐）
localparam DATA_OPCODE     = 8'h05;  // 有效数据帧Opcode（0x00~0x1F）
localparam CTRL_OPCODE     = 8'h25;  // 有效控制帧Opcode（0x20~0x7F）
localparam RESERVED_OPCODE = 8'h85;  // 保留无效Opcode（0x80~0xFF）

// QPN测试值
localparam LOCAL_QPN  = 16'h1234;   // 本地QPN
localparam REMOTE_QPN = 16'h5678;   // 远程QPN
localparam INVALID_QPN = 16'h9999;  // 无效QPN（非本地/远程）

// PSN测试值
localparam TEST_PSN   = 24'h000001;

// 例化PDU解析模块（DUT）
rdma_rc_pdu_parser #(
    .QPN_WIDTH    (QPN_WIDTH),
    .PSN_WIDTH    (PSN_WIDTH),
    .OPCODE_WIDTH (OPCODE_WIDTH),
    .DATA_WIDTH   (DATA_WIDTH)
) u_rdma_rc_pdu_parser (
    .clk            (clk),
    .rst_n          (rst_n),
    .pdu_data       (pdu_data),
    .pdu_valid      (pdu_valid),
    .qp_state       (qp_state),       // 模拟的QP状态
    .local_qpn      (local_qpn),      // 硬编码本地QPN
    .remote_qpn     (remote_qpn),     // 硬编码远程QPN
    .pdu_opcode     (pdu_opcode),
    .pdu_qpn        (pdu_qpn),
    .pdu_psn        (pdu_psn),
    .is_data_frame  (is_data_frame),
    .is_control_frame (is_control_frame),
    .opcode_err     (opcode_err),
    .qpn_mismatch_err (qpn_mismatch_err),
    .pdu_parse_done (pdu_parse_done)
);

// 生成时钟
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 修正后的send_pdu任务：添加@(posedge clk)等待时序逻辑更新
task automatic send_pdu(
    input [OPCODE_WIDTH-1:0] opcode,
    input [QPN_WIDTH-1:0]    qpn,
    input [PSN_WIDTH-1:0]    psn
);
    // 定义采样变量，存储有效窗口的结果
    reg opcode_err_sample;
    reg qpn_mismatch_err_sample;
    begin
        pdu_data[OPCODE_OFFSET +: OPCODE_WIDTH] = opcode;
        pdu_data[QPN_OFFSET +: QPN_WIDTH]       = qpn;
        pdu_data[PSN_OFFSET +: PSN_WIDTH]       = psn;
        @(posedge clk);
        pdu_valid = 1'b1;
        $display("[%0t ns] 发送PDU：Opcode=0x%02h, QPN=0x%04h, PSN=0x%06h, QP状态=%03b", 
                 $time, opcode, qpn, psn, qp_state);
        // 2. 等待1个时钟周期，pdu_valid仅持续1个周期（匹配时序图的10~20ns）
        @(posedge clk);
        @(posedge clk);
        pdu_valid = 1'b0;
        #1;              // 避免竞争，延迟1ns
        
        // 3. 采样输出：此时opcode_err正处于20~30ns的有效窗口（核心！）
        opcode_err_sample = opcode_err;
        qpn_mismatch_err_sample = qpn_mismatch_err;
        $display("[%0t ns] 采样结果：Opcode错误标志=%b, QPN不匹配错误标志=%b", 
                 $time, opcode_err_sample, qpn_mismatch_err_sample);

        // 4. 等待错误标志窗口结束，准备下一次PDU
        @(posedge clk);
    end
endtask

// 核心测试激励序列
initial begin
    // 初始化所有信号
    rst_n          = 1'b0;
    pdu_data       = {DATA_WIDTH{1'b0}};
    pdu_valid      = 1'b0;
    qp_state       = RESET;          // 初始QP状态：复位
    local_qpn      = LOCAL_QPN;
    remote_qpn     = REMOTE_QPN;

    // 释放复位
    #20 rst_n = 1'b1;
    $display("[%0t ns] 复位释放", $time);
    #CLK_PERIOD;

    // 测试用例1：QP=RESET状态，发送数据帧（预期Opcode错误）
    qp_state = RESET;
    send_pdu(DATA_OPCODE, LOCAL_QPN, TEST_PSN);
    //$display("[%0t ns] 用例1：RESET状态+数据帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例2：QP=INIT状态，发送控制帧（预期Opcode错误）
    qp_state = INIT;
    send_pdu(CTRL_OPCODE, REMOTE_QPN, TEST_PSN + 1);
    //$display("[%0t ns] 用例2：INIT状态+控制帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例3：QP=RTR状态，发送控制帧（预期无Opcode错误）
    qp_state = RTR;
    send_pdu(CTRL_OPCODE, REMOTE_QPN, TEST_PSN + 2);
    //$display("[%0t ns] 用例3：RTR状态+控制帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例4：QP=RTR状态，发送数据帧（预期Opcode错误）
    qp_state = RTR;
    send_pdu(DATA_OPCODE, LOCAL_QPN, TEST_PSN + 3);
    //$display("[%0t ns] 用例4：RTR状态+数据帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例5：QP=RTS状态，发送数据帧（预期无Opcode错误）
    qp_state = RTS;
    send_pdu(DATA_OPCODE, LOCAL_QPN, TEST_PSN + 4);
    //$display("[%0t ns] 用例5：RTS状态+数据帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例6：QP=RTS状态，发送控制帧（预期Opcode错误）
    qp_state = RTS;
    send_pdu(CTRL_OPCODE, REMOTE_QPN, TEST_PSN + 5);
    //$display("[%0t ns] 用例6：RTS状态+控制帧 → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例7：发送保留Opcode（任意状态均预期Opcode错误）
    qp_state = RTS;
    send_pdu(RESERVED_OPCODE, LOCAL_QPN, TEST_PSN + 6);
    //$display("[%0t ns] 用例7：RTS状态+保留Opcode → Opcode错误标志=%b", $time, opcode_err);

    // 测试用例8：有效数据帧+无效QPN（预期QPN不匹配错误）
    qp_state = RTS;
    send_pdu(DATA_OPCODE, INVALID_QPN, TEST_PSN + 7);
    //$display("[%0t ns] 用例8：RTS状态+有效数据帧+无效QPN → QPN错误标志=%b", $time, qpn_mismatch_err);

    // 结束仿真
    #50 $display("[%0t ns] PDU解析模块独立测试完成", $time);
    $finish;
end

// 波形Dump（用于仿真调试）
initial begin
    $dumpfile("../sim/wave/tb_rdma_rc_pdu.vcd");
    $dumpvars(0, tb_rdma_rc_pdu);
    $dumpflush;

    // FSDB Dump（Verdi调试用，可选）
    $fsdbDumpfile("../sim/wave/tb_rdma_rc_pdu.fsdb");
    $fsdbDumpvars(0, tb_rdma_rc_pdu);
    $fsdbDumpMDA();
end

endmodule
