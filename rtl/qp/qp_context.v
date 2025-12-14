module qp_context (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    input  wire [63:0] in_data,
    input  wire        in_last,

    output wire        out_valid,
    output wire [63:0] out_data,
    output wire        out_last
);

assign out_valid = in_valid;
assign out_data  = in_data;
assign out_last  = in_last;

endmodule
