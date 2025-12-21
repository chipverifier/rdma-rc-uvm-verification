module rdma_top (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        host_valid,
    input  wire [63:0] host_data,
    input  wire        host_last,

    input  wire        rx_valid,
    input  wire [63:0] rx_data,
    input  wire        rx_last,

    output wire        tx_valid,
    output wire [63:0] tx_data,
    output wire        tx_last,

    output wire        comp_valid
);

    wire        rx2qp_valid;
    wire [63:0] rx2qp_data;
    wire        rx2qp_last;

    wire        host2qp_valid;
    wire [63:0] host2qp_data;
    wire        host2qp_last;

    wire        arb_valid;
    wire [63:0] arb_data;
    wire        arb_last;

    wire        qp2sch_valid;
    wire [63:0] qp2sch_data;
    wire        qp2sch_last;

    wire        sch2tx_valid;
    wire [63:0] sch2tx_data;
    wire        sch2tx_last;

    wire        tx_done;

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

    assign host2qp_valid = host_valid;
    assign host2qp_data  = host_data;
    assign host2qp_last  = host_last;
/*
    assign host2qp_valid = 1'b0;
    assign host2qp_data  = 64'd0;
    assign host2qp_last  = 1'b0;
*/

    assign arb_valid = host2qp_valid | rx2qp_valid;
    assign arb_data  = host2qp_valid ? host2qp_data : rx2qp_data;
    assign arb_last  = host2qp_valid ? host2qp_last : rx2qp_last;

    qp_context u_qp (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (arb_valid),
        .in_data   (arb_data),
        .in_last   (arb_last),
        .out_valid (qp2sch_valid),
        .out_data  (qp2sch_data),
        .out_last  (qp2sch_last)
    );

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

    rdma_completion u_comp (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_done    (tx_done),
        .comp_valid (comp_valid)
    );

endmodule
