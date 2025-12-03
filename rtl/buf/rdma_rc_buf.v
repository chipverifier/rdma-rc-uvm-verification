// RDMA RC 数据缓冲模块（适配flow_ctrl/pdu_parser/QP模块）
// 核心功能：AXI-Stream数据缓存 + 背压输出 + 流量控制暂停联动 + 满/空检测
// 参数化设计：缓冲深度/数据位宽可配置，对齐已有模块位宽规范
module rdma_rc_buf #(
    parameter DATA_WIDTH    = 64,    // 数据位宽（与PDU解析模块一致）
    parameter BUF_DEPTH     = 16,    // 缓冲深度（2的幂次，默认16帧）
    parameter ADDR_WIDTH    = $clog2(BUF_DEPTH) // 地址位宽（自动计算）
)(
    // 全局时钟与复位（和已有模块对齐）
    input  wire                     clk,                // 100MHz系统时钟
    input  wire                     rst_n,              // 异步低电平复位

    // 流量控制模块输入（核心联动信号）
    input  wire                     send_pause,         // 发送暂停（来自flow_ctrl，1=暂停）

    // AXI-Stream接收接口（上游：验证环境Driver/PDU解析模块）
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,       // 接收PDU数据
    input  wire                     s_axis_tvalid,      // 接收数据有效
    input  wire                     s_axis_tlast,       // 接收帧尾（标记1帧PDU结束）
    output reg                      s_axis_tready,      // 接收就绪（背压核心：0=暂停上游）

    // AXI-Stream发送接口（下游：流量控制模块/外部）
    output reg [DATA_WIDTH-1:0]     m_axis_tdata,       // 发送缓存数据
    output reg                      m_axis_tvalid,      // 发送数据有效
    output reg                      m_axis_tlast,       // 发送帧尾
    input  wire                     m_axis_tready,      // 下游接收就绪

    // 状态输出（供flow_ctrl/状态反馈接口）
    output reg                      buf_full,           // 缓冲满标志（1=满）
    output reg                      buf_empty,          // 缓冲空标志（1=空）
    output reg                      backpressure        // 背压信号（=buf_full，简化上游对接）
);

// ========== 内部信号定义 ==========
reg [DATA_WIDTH-1:0]  buf_mem[0:BUF_DEPTH-1]; // 缓冲存储（寄存器数组）
reg [ADDR_WIDTH-1:0]  wr_addr;                 // 写地址计数器
reg [ADDR_WIDTH-1:0]  rd_addr;                 // 读地址计数器
reg [ADDR_WIDTH:0]    buf_cnt;                 // 缓冲数据计数（0~BUF_DEPTH）
reg                   tlast_r;                 // 帧尾锁存寄存器（保证整帧发送）

// ========== 核心逻辑1：缓冲写控制（接收AXI-Stream数据） ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_addr <= {ADDR_WIDTH{1'b0}};
        tlast_r <= 1'b0;
    end else if (s_axis_tvalid && s_axis_tready) begin // 上游有效+本模块就绪
        // 写入缓冲存储
        buf_mem[wr_addr] <= s_axis_tdata;
        // 锁存帧尾（用于发送阶段标记）
        if (s_axis_tlast) begin
            tlast_r <= 1'b1;
        end
        // 写地址自增（循环）
        if (wr_addr == BUF_DEPTH - 1) begin
            wr_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            wr_addr <= wr_addr + 1'b1;
        end
    end else begin
        wr_addr <= wr_addr;
        tlast_r <= tlast_r;
    end
end

// ========== 核心逻辑2：缓冲读控制（发送AXI-Stream数据） ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_addr     <= {ADDR_WIDTH{1'b0}};
        m_axis_tdata<= {DATA_WIDTH{1'b0}};
        m_axis_tvalid<= 1'b0;
        m_axis_tlast <= 1'b0;
    end else if (!send_pause && !buf_empty) begin // 未暂停+缓冲非空
        if (m_axis_tready || !m_axis_tvalid) begin // 下游就绪/当前无有效数据
            // 从缓冲读取数据
            m_axis_tdata <= buf_mem[rd_addr];
            m_axis_tvalid <= 1'b1;
            // 发送帧尾（匹配接收的tlast）
            if (tlast_r) begin
                m_axis_tlast <= 1'b1;
                tlast_r <= 1'b0; // 帧尾发送后清零
            end else begin
                m_axis_tlast <= 1'b0;
            end
            // 读地址自增（循环）
            if (rd_addr == BUF_DEPTH - 1) begin
                rd_addr <= {ADDR_WIDTH{1'b0}};
            end else begin
                rd_addr <= rd_addr + 1'b1;
            end
        end else begin
            // 下游未就绪，保持当前数据
            m_axis_tdata <= m_axis_tdata;
            m_axis_tvalid <= m_axis_tvalid;
            m_axis_tlast <= m_axis_tlast;
        end
    end else begin
        // 暂停/缓冲空，停止发送
        m_axis_tdata <= {DATA_WIDTH{1'b0}};
        m_axis_tvalid <= 1'b0;
        m_axis_tlast <= 1'b0;
        rd_addr <= rd_addr;
    end
end

// ========== 核心逻辑3：缓冲计数+满/空检测 ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buf_cnt <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        case ({s_axis_tvalid & s_axis_tready, m_axis_tvalid & m_axis_tready & !send_pause})
            2'b01:  buf_cnt <= buf_cnt - 1'b1; // 只读不写，计数减1
            2'b10:  buf_cnt <= buf_cnt + 1'b1; // 只写不读，计数加1
            2'b11:  buf_cnt <= buf_cnt;        // 读写同时，计数不变
            default: buf_cnt <= buf_cnt;       // 无操作，计数不变
        endcase
    end
end

// 满/空判断（核心：计数=BUF_DEPTH则满，=0则空）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        buf_full <= 1'b0;
        buf_empty <= 1'b1;
        backpressure <= 1'b0;
    end else begin
        buf_full <= (buf_cnt == BUF_DEPTH);
        buf_empty <= (buf_cnt == {ADDR_WIDTH+1{1'b0}});
        backpressure <= (buf_cnt == BUF_DEPTH); // 背压=缓冲满，简化上游对接
    end
end

// ========== 核心逻辑4：背压控制（接收就绪信号） ==========
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s_axis_tready <= 1'b0;
    end else begin
        // 缓冲未满则就绪（允许上游发数据），满则拒绝（背压）
        s_axis_tready <= !buf_full;
    end
end

endmodule