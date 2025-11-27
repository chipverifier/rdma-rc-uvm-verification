// RDMA RC Credit流量控制模块（最终定稿，适配PDU模块）
// 核心功能：初始化 + 数据帧消耗 + ACK控制帧恢复 + 额度耗尽暂停 + 超时错误
// 独立运行：仅依赖时钟/复位，输入为PDU帧类型标志+Opcode，输出为暂停/错误/剩余额度
module rdma_rc_flow #(
    parameter CREDIT_WIDTH  = 8,     // Credit计数器位宽（0~255）
    parameter CREDIT_INIT   = 8'h10, // 默认初始Credit=16
    parameter ERROR_TIMEOUT = 4'd10  // 暂停超时周期=10个时钟
)(
    // 全局时钟与复位（唯一的基础依赖）
    input  wire                 clk,                // 100MHz时钟
    input  wire                 rst_n,              // 异步低复位

    // AXI配置（可选，0则用默认值）
    input  wire [CREDIT_WIDTH-1:0] credit_init_cfg, // 初始Credit配置值

    // QP状态输入（仅需RTS状态+就绪，和你的QP模块对齐）
    input  wire [2:0]           qp_state,           // QP当前状态
    input  wire                 qp_ready,           // QP就绪标志

    // PDU模块输入（核心对接信号，和你的PDU模块100%对齐）
    input  wire [7:0]           pdu_opcode,         // PDU解析的Opcode
    input  wire                 is_data_frame,      // PDU数据帧标志
    input  wire                 is_control_frame,   // PDU控制帧标志

    // Credit核心输出（模块自身功能结果）
    output reg [CREDIT_WIDTH-1:0] credit_remain,    // 剩余Credit额度
    output reg                  send_pause,         // 发送暂停信号（1=暂停）
    output reg                  credit_err          // 超时错误信号（1=报错）
);

// 常量定义（和你的QP/PDU模块严格对齐）
localparam QP_RTS   = 3'b011;    // QP的RTS发送就绪状态
localparam OP_ACK   = 8'h20;     // ACK帧Opcode（PDU控制帧范围0x20~0x7F）

// 内部寄存器：超时计数器（记录暂停持续时间）
reg [3:0] timeout_cnt;

// ********** 核心逻辑1：Credit额度的初始化、消耗、恢复 **********
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        credit_remain <= CREDIT_INIT; // 复位用默认值
    end 
    else if (credit_init_cfg != 0) begin
        credit_remain <= credit_init_cfg; // 配置值优先
    end 
    else if (qp_state == QP_RTS && qp_ready) begin // QP就绪才允许更新Credit
        // 数据帧：消耗1个Credit（直接用PDU的is_data_frame标志）
        if (is_data_frame) begin
            credit_remain <= credit_remain - 1'b1;
        end
        // ACK控制帧：恢复1个Credit（控制帧+特定Opcode）
        else if (is_control_frame && (pdu_opcode == OP_ACK)) begin
            credit_remain <= credit_remain + 1'b1;
        end
        // 其他帧：Credit保持不变
        else begin
            credit_remain <= credit_remain;
        end
    end
    else begin
        credit_remain <= credit_remain; // 非RTS/未就绪，额度不变
    end
end

// ********** 核心逻辑2：额度耗尽→暂停发送 **********
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        send_pause <= 1'b0; // 复位后默认允许发送
    end else begin
        // 额度为0则暂停，否则允许（通用化位宽，改CREDIT_WIDTH不用改这里）
        send_pause <= (credit_remain == {CREDIT_WIDTH{1'b0}}) ? 1'b1 : 1'b0;
    end
end

// ********** 核心逻辑3：暂停超时→触发错误 **********
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_cnt <= 4'd0;
        credit_err  <= 1'b0;
    end else if (send_pause) begin // 暂停时才计数
        timeout_cnt <= timeout_cnt + 1'b1;
        // 计数到超时周期则报错，否则正常
        credit_err  <= (timeout_cnt >= ERROR_TIMEOUT) ? 1'b1 : 1'b0;
    end else begin // 未暂停则清零计数器+错误
        timeout_cnt <= 4'd0;
        credit_err  <= 1'b0;
    end
end

endmodule