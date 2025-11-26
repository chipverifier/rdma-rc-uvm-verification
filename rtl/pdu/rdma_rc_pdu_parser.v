// RDMA RC PDU解析模块
// 功能：解析PDU头部的Opcode/QPN/PSN字段，区分数据帧/控制帧，
//       检测Opcode错误（状态不匹配/无效Opcode）和QPN不匹配错误
// 参数化设计：兼容QP状态机位宽，支持总线位宽扩展
module rdma_rc_pdu_parser #(
    parameter QPN_WIDTH     = 16,    // 队列对号位宽（与QP状态机一致）
    parameter PSN_WIDTH     = 24,    // 包序列号位宽（RDMA标准）
    parameter OPCODE_WIDTH  = 8,     // 操作码位宽（RDMA标准8位）
    parameter DATA_WIDTH    = 64,    // PDU数据总线位宽（可扩展至128/256）
    // PDU头部字段偏移定义（64位总线大端序）
    parameter OPCODE_OFFSET = 56,    // Opcode偏移：bit56~bit63
    parameter QPN_OFFSET    = 32,    // QPN偏移：bit32~bit47
    parameter PSN_OFFSET    = 8      // PSN偏移：bit8~bit31
)(
    input  wire                                     clk,                // 系统时钟（100MHz）
    input  wire                                     rst_n,              // 异步低电平复位
    input  wire [DATA_WIDTH-1:0]                    pdu_data,           // 物理层输入的PDU数据
    input  wire                                     pdu_valid,          // PDU数据有效信号
    input  wire [2:0]                               qp_state,           // QP当前状态（来自QP状态机）
    input  wire [QPN_WIDTH-1:0]                     local_qpn,          // 本地QPN（来自QP配置）
    input  wire [QPN_WIDTH-1:0]                     remote_qpn,         // 远程QPN（来自QP配置）
    // PDU解析结果输出
    output reg  [OPCODE_WIDTH-1:0]                  pdu_opcode,         // 解析出的Opcode字段
    output reg  [QPN_WIDTH-1:0]                     pdu_qpn,            // 解析出的QPN字段
    output reg  [PSN_WIDTH-1:0]                     pdu_psn,            // 解析出的PSN字段
    output reg                                      is_data_frame,      // 数据帧标志：1=数据帧，0=非数据帧
    output reg                                      is_control_frame,   // 控制帧标志：1=控制帧，0=非控制帧
    // 错误检测输出
    output reg                                      opcode_err,         // Opcode错误：无效Opcode/状态不匹配
    output reg                                      qpn_mismatch_err,   // QPN错误：解析值与本地/远程QPN不匹配
    output reg                                      pdu_parse_done      // PDU解析完成标志
);

// QP状态定义（与QP状态机对齐）
localparam RESET  = 3'b000;    // 复位状态
localparam INIT   = 3'b001;    // 初始化状态
localparam RTR    = 3'b010;    // 接收就绪状态
localparam RTS    = 3'b011;    // 发送就绪状态（数据传输）
localparam ERROR  = 3'b111;    // 错误状态

// RDMA RC Opcode范围定义（协议标准分类）
localparam DATA_OPCODE_MIN  = {OPCODE_WIDTH{1'b0}};  // 数据帧Opcode：0x00~0x1F
localparam DATA_OPCODE_MAX  = 8'h1F;
localparam CTRL_OPCODE_MIN  = 8'h20;                 // 控制帧Opcode：0x20~0x7F
localparam CTRL_OPCODE_MAX  = 8'h7F;
localparam RESERVED_OPCODE_MIN = 8'h80;              // 保留无效Opcode：0x80~0xFF

// 内部寄存器：锁存字段值和帧类型判断结果
reg [OPCODE_WIDTH-1:0]  opcode_r;   // 锁存的Opcode字段
reg [QPN_WIDTH-1:0]     qpn_r;      // 锁存的QPN字段
reg [PSN_WIDTH-1:0]     psn_r;      // 锁存的PSN字段
reg                     data_frame_r; // 锁存的数据帧标志
reg                     ctrl_frame_r; // 锁存的控制帧标志

// 步骤1：提取PDU头部字段（组合逻辑）
// 根据偏移参数从PDU数据总线中提取Opcode/QPN/PSN
always @(*) begin
    if (pdu_valid) begin
        opcode_r = pdu_data[OPCODE_OFFSET + OPCODE_WIDTH - 1 : OPCODE_OFFSET];
        qpn_r    = pdu_data[QPN_OFFSET + QPN_WIDTH - 1 : QPN_OFFSET];
        psn_r    = pdu_data[PSN_OFFSET + PSN_WIDTH - 1 : PSN_OFFSET];
    end else begin
        opcode_r = {OPCODE_WIDTH{1'b0}};
        qpn_r    = {QPN_WIDTH{1'b0}};
        psn_r    = {PSN_WIDTH{1'b0}};
    end
end

// 步骤2：区分数据帧/控制帧（组合逻辑）
// 根据Opcode范围按RDMA协议标准分类帧类型
always @(*) begin
    if (pdu_valid) begin
        if ((opcode_r >= DATA_OPCODE_MIN) && (opcode_r <= DATA_OPCODE_MAX)) begin
            data_frame_r = 1'b1;
            ctrl_frame_r = 1'b0;
        end else if ((opcode_r >= CTRL_OPCODE_MIN) && (opcode_r <= CTRL_OPCODE_MAX)) begin
            data_frame_r = 1'b0;
            ctrl_frame_r = 1'b1;
        end else begin
            data_frame_r = 1'b0;
            ctrl_frame_r = 1'b0; // 保留Opcode：非数据/控制帧
        end
    end else begin
        data_frame_r = 1'b0;
        ctrl_frame_r = 1'b0;
    end
end
// 新增：错误标志的临时锁存寄存器（用于保持1个时钟周期）
reg opcode_err_t;       // 临时Opcode错误标志
reg qpn_mismatch_err_t; // 临时QPN不匹配错误标志
reg pdu_parse_done_t;   // 临时解析完成标志
// 步骤3：锁存解析结果并检测错误（时序逻辑）
// 1. 将解析字段和帧类型锁存到输出寄存器
// 2. 检测Opcode错误：状态不匹配/保留Opcode
// 3. 检测QPN错误：解析值与本地/远程QPN均不匹配
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 复位：清空所有输出寄存器和错误标志
        pdu_opcode       <= {OPCODE_WIDTH{1'b0}};
        pdu_qpn          <= {QPN_WIDTH{1'b0}};
        pdu_psn          <= {PSN_WIDTH{1'b0}};
        is_data_frame    <= 1'b0;
        is_control_frame <= 1'b0;
        opcode_err       <= 1'b0;
        qpn_mismatch_err <= 1'b0;
        pdu_parse_done   <= 1'b0;
        opcode_err_t     <= 1'b0;
        qpn_mismatch_err_t <= 1'b0;
        pdu_parse_done_t <= 1'b0;
    end else begin
        if (pdu_valid) begin
            // 1. 锁存解析结果（原有逻辑）
            pdu_opcode       <= opcode_r;
            pdu_qpn          <= qpn_r;
            pdu_psn          <= psn_r;
            is_data_frame    <= data_frame_r;
            is_control_frame <= ctrl_frame_r;

            // 2. 计算错误标志（原有逻辑，结果存到临时寄存器）
            case (qp_state)
                RTS:  opcode_err_t <= (~data_frame_r) || (opcode_r >= RESERVED_OPCODE_MIN);
                RTR:  opcode_err_t <= (~ctrl_frame_r) || (opcode_r >= RESERVED_OPCODE_MIN);
                default: opcode_err_t <= 1'b1;
            endcase
            if (opcode_r >= RESERVED_OPCODE_MIN) opcode_err_t <= 1'b1; // 保留Opcode直接错误
            qpn_mismatch_err_t <= (qpn_r != local_qpn) && (qpn_r != remote_qpn);
            pdu_parse_done_t   <= 1'b1;

            // 3. 输出寄存器先清空（等待下一个周期更新）
            opcode_err       <= 1'b0;
            qpn_mismatch_err <= 1'b0;
            pdu_parse_done   <= 1'b0;
        end else begin
            // 核心：pdu_valid无效后，将临时错误标志赋值给输出，保持1个周期（匹配时序图）
            opcode_err       <= opcode_err_t;
            qpn_mismatch_err <= qpn_mismatch_err_t;
            pdu_parse_done   <= pdu_parse_done_t;

            // 1个周期后清空临时寄存器，准备下一次PDU
            opcode_err_t     <= 1'b0;
            qpn_mismatch_err_t <= 1'b0;
            pdu_parse_done_t <= 1'b0;
        end
    end
end

endmodule
