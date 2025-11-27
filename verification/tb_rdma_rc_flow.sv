// RDMA RC Credit模块SV测试平台（修复打印时机+计数公式）
`timescale 1ns/1ps

module tb_rdma_rc_flow;

parameter CREDIT_WIDTH  = 8;
parameter CREDIT_INIT   = 8'h10;
parameter ERROR_TIMEOUT = 4'd10;
parameter CLK_PERIOD    = 10;

logic                     clk;
logic                     rst_n;
logic [CREDIT_WIDTH-1:0]  credit_init_cfg;
logic [2:0]               qp_state;
logic                     qp_ready;
logic [7:0]               pdu_opcode;
logic                     is_data_frame;
logic                     is_control_frame;

wire [CREDIT_WIDTH-1:0]   credit_remain;
wire                      send_pause;
wire                      credit_err;

rdma_rc_flow #(
    .CREDIT_WIDTH(CREDIT_WIDTH),
    .CREDIT_INIT(CREDIT_INIT),
    .ERROR_TIMEOUT(ERROR_TIMEOUT)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .credit_init_cfg(credit_init_cfg),
    .qp_state(qp_state),
    .qp_ready(qp_ready),
    .pdu_opcode(pdu_opcode),
    .is_data_frame(is_data_frame),
    .is_control_frame(is_control_frame),
    .credit_remain(credit_remain),
    .send_pause(send_pause),
    .credit_err(credit_err)
);

// 时钟生成（无修改）
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// FSDB波形dump（无修改）
initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars(0, tb_rdma_rc_flow);
    $fsdbDumpMDA;
    $fsdbDumpon;
end

// 核心测试激励（修复打印时机+计数公式）
initial begin
    rst_n              = 1'b0;
    credit_init_cfg    = 8'h00;
    qp_state           = 3'b000;
    qp_ready           = 1'b0;
    pdu_opcode         = 8'h00;
    is_data_frame      = 1'b0;
    is_control_frame   = 1'b0;

    // 场景1：复位初始化
    #20 rst_n = 1'b1;
    #CLK_PERIOD; // 新增：等待时钟沿，让send_pause同步更新
    $display("[%0tns] 场景1：复位初始化完成，credit_remain = 0x%02h，send_pause = %b", $time/1ns, credit_remain, send_pause);
    #10;

    // 场景2：QP进入RTS状态
    qp_state = 3'b011;
    qp_ready = 1'b1;
    #CLK_PERIOD; // 新增：等待时钟沿
    $display("[%0tns] 场景2：QP进入RTS状态，qp_ready = %b，send_pause = %b", $time/1ns, qp_ready, send_pause);
    #10;

    // 场景3：发送16个数据帧
    $display("[%0tns] 场景3：开始发送16个数据帧，消耗Credit", $time/1ns);
    repeat(16) begin
        is_data_frame = 1'b1;
        #CLK_PERIOD;
        is_data_frame = 1'b0;
        $display("  [%0tns] 数据帧发送后，credit_remain = 0x%02h，send_pause = %b", $time/1ns, credit_remain, send_pause);
    end
    #CLK_PERIOD; // 新增：等待时钟沿
    $display("[%0tns] 场景3结束：credit_remain = 0x%02h，send_pause = %b", $time/1ns, credit_remain, send_pause);
    #10;

    // 场景4：发送ACK帧
    $display("[%0tns] 场景4：发送ACK控制帧，恢复Credit", $time/1ns);
    is_control_frame = 1'b1;
    pdu_opcode       = 8'h20;
    #CLK_PERIOD;
    is_control_frame = 1'b0;
    pdu_opcode       = 8'h00;
    $display("  [%0tns] ACK帧发送后，credit_remain = 0x%02h，send_pause = %b", $time/1ns, credit_remain, send_pause);
    #10;

    // 场景5：暂停超时报错（修复计数公式：时间基准改为240）
    $display("[%0tns] 场景5：再次发送数据帧，Credit耗尽后测试超时报错", $time/1ns);
    is_data_frame = 1'b1;
    #CLK_PERIOD;
    is_data_frame = 1'b0;
    $display("  [%0tns] 数据帧发送后，credit_remain = 0x%02h，send_pause = %b", $time/1ns, credit_remain, send_pause);
    
    // 修复计数公式：($time/1ns - 240)/10 → 240是当前时间基准
    repeat(ERROR_TIMEOUT) begin
        #CLK_PERIOD;
        $display("  [%0tns] 暂停第%0d个时钟，credit_err = %b", $time/1ns, ($time/1ns - 240)/10, credit_err);
    end
    #CLK_PERIOD; // 新增：等待时钟沿
    $display("[%0tns] 场景5结束：暂停超时，credit_err = %b", $time/1ns, credit_err);
    #10;

    // 场景6：发送ACK帧
    $display("[%0tns] 场景6：发送ACK帧，恢复Credit并取消错误", $time/1ns);
    is_control_frame = 1'b1;
    pdu_opcode       = 8'h20;
    #CLK_PERIOD;
    is_control_frame = 1'b0;
    pdu_opcode       = 8'h00;
    $display("  [%0tns] ACK帧发送后，credit_remain = 0x%02h，send_pause = %b，credit_err = %b", $time/1ns, credit_remain, send_pause, credit_err);
    #10;

    $display("[%0tns] 所有测试场景执行完成！", $time/1ns);
    $finish;
end

endmodule