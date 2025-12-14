module rdma_sched (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sched_in_valid,
    input  wire [63:0] sched_in_data,
    input  wire        sched_in_last,

    output wire        sched_out_valid,
    output wire [63:0] sched_out_data,
    output wire        sched_out_last
);

assign sched_out_valid = sched_in_valid;
assign sched_out_data  = sched_in_data;
assign sched_out_last  = sched_in_last;

endmodule
