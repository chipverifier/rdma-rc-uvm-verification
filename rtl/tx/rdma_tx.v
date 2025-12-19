module rdma_tx (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        tx_in_valid,
    input  wire [63:0] tx_in_data,
    input  wire        tx_in_last,

    output reg         tx_valid,
    output reg  [63:0] tx_data,
    output reg         tx_last,

    output reg         tx_done   // <<< 新增
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_valid <= 1'b0;
        tx_data  <= 64'd0;
        tx_last  <= 1'b0;
        tx_done  <= 1'b0;
    end else begin
        // default
        tx_done <= 1'b0;

        // pass-through
        tx_valid <= tx_in_valid;
        tx_data  <= tx_in_data;
        tx_last  <= tx_in_last;

        // completion condition
        if (tx_in_valid && tx_in_last) begin
            tx_done <= 1'b1;   // one-cycle pulse
        end
    end
end

endmodule
