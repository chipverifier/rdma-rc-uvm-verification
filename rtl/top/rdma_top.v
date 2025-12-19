module rdma_top (
    input  wire        clk,
    input  wire        rst_n,

    // RX side (Host / Network inject)
    input  wire        rx_valid,
    input  wire [63:0] rx_data,
    input  wire        rx_last,

    // TX side (to Network)
    output wire        tx_valid,
    output wire [63:0] tx_data,
    output wire        tx_last,

    // Completion to Host / UVM
    output wire        comp_valid
);

    // ============================
    // Internal wires
    // ============================

    // RX -> QP
    wire        rx2qp_valid;
    wire [63:0] rx2qp_data;
    wire        rx2qp_last;

    // QP -> Scheduler
    wire        qp2sch_valid;
    wire [63:0] qp2sch_data;
    wire        qp2sch_last;

    // Scheduler -> TX
    wire        sch2tx_valid;
    wire [63:0] sch2tx_data;
    wire        sch2tx_last;

    // TX -> Completion
    wire        tx_done;

    // ============================
    // RX
    // ============================
    rdma_rx u_rx (
        .clk          (clk),
        .rst_n        (rst_n),
        .rx_valid     (rx_valid),
        .rx_data      (rx_data),
        .rx_last      (rx_last),
        .rx_out_valid (rx2qp_valid),
        .rx_out_data  (rx2qp_data),
        .rx_out_last  (rx2qp_last)
    );

    // ============================
    // QP Context (pass-through v1)
    // ============================
    qp_context u_qp (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (rx2qp_valid),
        .in_data   (rx2qp_data),
        .in_last   (rx2qp_last),
        .out_valid (qp2sch_valid),
        .out_data  (qp2sch_data),
        .out_last  (qp2sch_last)
    );

    // ============================
    // Scheduler
    // ============================
    rdma_sched u_sched (
        .clk             (clk),
        .rst_n           (rst_n),
        .sched_in_valid  (qp2sch_valid),
        .sched_in_data   (qp2sch_data),
        .sched_in_last   (qp2sch_last),
        .sched_out_valid (sch2tx_valid),
        .sched_out_data  (sch2tx_data),
        .sched_out_last  (sch2tx_last)
    );

    // ============================
    // TX
    // ============================
    rdma_tx u_tx (
        .clk         (clk),
        .rst_n       (rst_n),
        .tx_in_valid (sch2tx_valid),
        .tx_in_data  (sch2tx_data),
        .tx_in_last  (sch2tx_last),
        .tx_valid    (tx_valid),
        .tx_data     (tx_data),
        .tx_last     (tx_last),
        .tx_done     (tx_done)
    );

    // ============================
    // Completion Engine
    // ============================
    rdma_completion u_comp (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_done    (tx_done),
        .comp_valid (comp_valid)
    );

endmodule
