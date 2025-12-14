module rdma_rx (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        rx_valid,
    input  wire [63:0] rx_data,
    input  wire        rx_last,

    output reg         rx_out_valid,
    output reg  [63:0] rx_out_data,
    output reg         rx_out_last
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_out_valid <= 1'b0;
        rx_out_data  <= 64'd0;
        rx_out_last  <= 1'b0;
    end else begin
        rx_out_valid <= rx_valid;
        rx_out_data  <= rx_data;
        rx_out_last  <= rx_last;
    end
end

endmodule
