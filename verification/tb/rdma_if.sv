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
/*
    input  wire        host_valid,
    input  wire [63:0] host_data,
    input  wire        host_last,

*/
// RDMA Host接口：修正信号驱动方向，添加modport适配UVM Driver
interface rdma_host_if (
    input logic clk,    // 系统时钟
    input logic rst_n   // 异步复位（低有效）
);
    // --------------------------
    // 1. 定义host接口的物理信号（DUT的输入，由Driver驱动）
    // --------------------------
    logic        host_valid;  // 数据有效信号
    logic [63:0] host_data;   // 64位数据信号
    logic        host_last;   // 帧最后一拍信号

    // --------------------------
    // 2. 定义Driver专用的时钟块（解决时序竞争，指定信号输出方向）
    // --------------------------
    // 时钟块绑定到clk上升沿，是UVM中同步驱动信号的标准做法
    clocking drv_cb @(posedge clk);
        // 默认规则：采样信号前延迟1step（避开delta延迟），驱动信号无延迟
        default input #1step output #0;
        // 信号方向：output（Driver向DUT输出这些信号）
        output host_valid, host_data, host_last;
    endclocking

    // --------------------------
    // 3. 定义Driver的modport（限定只能使用drv_cb时钟块，避免权限混乱）
    // --------------------------
    modport drv_mp (
        clocking drv_cb,  // 仅能访问drv_cb时钟块
        input rst_n       // 复位信号作为输入（Driver需要判断复位状态）
    );
endinterface
/*
    output wire        comp_valid
*/
// RDMA Complete接口：用于采样DUT输出的comp_valid信号（采样侧接口）
interface rdma_complete_if (
    input logic clk,    // 系统时钟
    input logic rst_n   // 异步复位（低有效）
);
    // --------------------------
    // 1. 定义接口的物理信号（DUT的输出，由验证环境的Monitor采样）
    // --------------------------
    logic comp_valid;   // DUT输出的完成有效信号

    // --------------------------
    // 2. 定义Monitor专用的时钟块（解决时序竞争，指定信号输入方向）
    // --------------------------
    // 时钟块绑定到clk上升沿，采样侧仅需input方向（只能读，不能写）
    clocking mon_cb @(posedge clk);
        // 默认规则：采样信号前延迟1step（避开delta延迟，采到稳定值）
        default input #1step;
        // 信号方向：input（Monitor从物理信号读取值）
        input comp_valid;
    endclocking

    // --------------------------
    // 3. 定义Monitor的modport（限定只能使用mon_cb时钟块，避免权限混乱）
    // --------------------------
    modport mon_mp (
        clocking mon_cb,
        input rst_n
    );

    // 预留：若后续需要驱动（极少场景，DUT输出一般无需驱动），可添加drv_mp，当前无需
    // clocking drv_cb @(posedge clk);
    //     default input #1step output #0;
    //     output comp_valid;
    // endclocking
    // modport drv_mp (clocking drv_cb, input rst_n);

endinterface