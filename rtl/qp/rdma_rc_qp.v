// RDMA RC QP状态机RTL设计（修复qp_ready置位时序）
// 路径：rtl/qp/rdma_rc_qp.v
module rdma_rc_qp #(
    parameter QPN_WIDTH = 16  // QPN（Queue Pair Number）位宽
)(
    input  wire                 clk,        // 系统时钟（100MHz）
    input  wire                 rst_n,      // 异步低电平复位
    input  wire [QPN_WIDTH-1:0] local_qpn,  // 本地QP编号
    input  wire [QPN_WIDTH-1:0] remote_qpn, // 远程QP编号
    input  wire                 cfg_valid,  // QP配置有效信号
    input  wire                 cmd_connect,// 连接命令（触发RTR/RTS）
    input  wire                 cmd_disconnect, // 断开命令（回到Reset）
    output reg  [2:0]           qp_state,   // QP当前状态（3位编码）
    output reg                  qp_ready    // QP就绪信号（状态稳定后置位）
);

// ========== RDMA RC QP标准状态定义 ==========
localparam RESET  = 3'b000; // 复位状态（初始）
localparam INIT   = 3'b001; // 初始化状态（配置完成）
localparam RTR    = 3'b010; // 接收就绪（收到远程QP连接请求）
localparam RTS    = 3'b011; // 发送就绪（双向连接建立，可传输数据）
localparam ERROR  = 3'b111; // 错误状态（配置/命令异常）

// ========== 内部寄存器 ==========
reg [QPN_WIDTH-1:0] local_qpn_reg;  // 本地QPN配置寄存器
reg [QPN_WIDTH-1:0] remote_qpn_reg; // 远程QPN配置寄存器
reg                 cfg_done;       // 配置完成标志

// ========== 配置寄存器逻辑 ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        local_qpn_reg  <= {QPN_WIDTH{1'b0}};
        remote_qpn_reg <= {QPN_WIDTH{1'b0}};
        cfg_done       <= 1'b0;
    end else if (cfg_valid && !cfg_done) begin
        // 锁存本地QPN，远程QPN需在连接阶段配置
        local_qpn_reg  <= local_qpn;
        cfg_done       <= 1'b1; // 配置完成标志置位
    end else if (cmd_connect && cfg_done && (qp_state == INIT)) begin
        // 连接阶段锁存远程QPN
        remote_qpn_reg <= remote_qpn;
    end else if (cmd_disconnect) begin
        // 断开连接，清空配置
        local_qpn_reg  <= {QPN_WIDTH{1'b0}};
        remote_qpn_reg <= {QPN_WIDTH{1'b0}};
        cfg_done       <= 1'b0;
    end
end

// ========== QP核心状态机（修复qp_ready置位时序） ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        qp_state <= RESET;
        qp_ready <= 1'b0;
    end else begin
        case (qp_state)
            RESET: begin
                // 复位状态：配置有效则进入Init，同时置位ready
                if (cfg_valid) begin
                    qp_state <= INIT;
                    qp_ready <= 1'b1; // 状态切换时直接置位ready
                end else begin
                    qp_state <= RESET;
                    qp_ready <= 1'b0;
                end
            end
            INIT: begin
                // 初始化状态：配置完成+连接命令+远程QPN非0 → 进入RTR
                if (cfg_done && cmd_connect && (remote_qpn != {QPN_WIDTH{1'b0}})) begin
                    qp_state <= RTR;
                    qp_ready <= 1'b1; // 状态切换时直接置位ready
                end else if (cmd_disconnect) begin
                    qp_state <= RESET;
                    qp_ready <= 1'b0;
                end else begin
                    qp_state <= INIT;
                    qp_ready <= 1'b1; // 保持INIT状态，ready始终置位
                end
            end
            RTR: begin
                // 接收就绪：再次收到连接命令（远程QP确认）→ 进入RTS
                if (cmd_connect && (remote_qpn_reg == remote_qpn)) begin
                    qp_state <= RTS;
                    qp_ready <= 1'b1; // 状态切换时直接置位ready
                end else if (cmd_disconnect) begin
                    qp_state <= RESET;
                    qp_ready <= 1'b0;
                end else begin
                    qp_state <= RTR;
                    qp_ready <= 1'b1; // 保持RTR状态，ready始终置位
                end
            end
            RTS: begin
                // 发送就绪：核心工作状态，断开命令则回到Reset
                if (cmd_disconnect) begin
                    qp_state <= RESET;
                    qp_ready <= 1'b0;
                end else begin
                    qp_state <= RTS;
                    qp_ready <= 1'b1; // 保持RTS状态，ready始终置位
                end
            end
            default: begin
                // 异常状态：回到Reset
                qp_state <= ERROR;
                qp_ready <= 1'b0;
            end
        endcase
    end
end

endmodule