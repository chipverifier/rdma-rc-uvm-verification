// verification/tb/rdma_if.sv

interface rdma_if (
    input logic clk,
    input logic rst_n
);
    // RX方向信号（DUT输入）
    logic        rx_valid;
    logic [63:0] rx_data;
    logic        rx_last;

    // TX方向信号（DUT输出）
    logic        tx_valid;
    logic [63:0] tx_data;
    logic        tx_last;

    // 时钟块：解决时序竞争，仅保留必要的驱动/采样规则
    clocking cb @(posedge clk);
        default input #1step output #0;
        output rx_valid, rx_data, rx_last;
        input tx_valid, tx_data, tx_last;
    endclocking
endinterface