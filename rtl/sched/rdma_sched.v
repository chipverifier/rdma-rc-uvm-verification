module rdma_sched (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        sched_in_valid,
    input  wire [63:0] sched_in_data,
    input  wire        sched_in_last,

    output reg         sched_out_valid,
    output reg  [63:0] sched_out_data,
    output reg         sched_out_last
);

    // ============================
    // State Machine
    // ============================
    localparam S_IDLE    = 2'd0;
    localparam S_FORWARD = 2'd1;
    localparam S_DONE    = 2'd2;

    reg [1:0] state;

    // ============================
    // Sequential Logic
    // ============================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            sched_out_valid <= 1'b0;
            sched_out_data  <= 64'd0;
            sched_out_last  <= 1'b0;
        end else begin
            // default
            sched_out_valid <= 1'b0;

            case (state)
                // --------------------
                // IDLE: wait request
                // --------------------
                S_IDLE: begin
                    if (sched_in_valid) begin
                        sched_out_valid <= 1'b1;
                        sched_out_data  <= sched_in_data;
                        sched_out_last  <= sched_in_last;

                        if (sched_in_last)
                            state <= S_DONE;
                        else
                            state <= S_FORWARD;
                    end
                end

                // --------------------
                // FORWARD: middle beats
                // --------------------
                S_FORWARD: begin
                    if (sched_in_valid) begin
                        sched_out_valid <= 1'b1;
                        sched_out_data  <= sched_in_data;
                        sched_out_last  <= sched_in_last;

                        if (sched_in_last)
                            state <= S_DONE;
                    end
                end

                // --------------------
                // DONE: one-cycle end
                // --------------------
                S_DONE: begin
                    // v1: just return to IDLE
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
