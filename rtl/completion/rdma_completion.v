module rdma_completion (
    input  wire clk,
    input  wire rst_n,

    // from TX
    input  wire tx_done,     // one-cycle pulse when a request finishes

    // to Host / UVM
    output reg  comp_valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        comp_valid <= 1'b0;
    end else begin
        // default
        comp_valid <= 1'b0;

        // v1: one completion per tx_done
        if (tx_done) begin
            comp_valid <= 1'b1;
        end
    end
end

endmodule
