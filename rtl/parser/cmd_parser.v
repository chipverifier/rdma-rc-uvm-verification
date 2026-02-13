module cmd_parser (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [255:0] cmd_data,
    output reg         cmd_ready,

    output reg  [7:0]   opcode,
    output reg  [55:0]  addr,
    output reg  [127:0] data,
    output reg          cmd_done
);

    typedef enum logic [1:0] {
        IDLE,
        PARSE,
        DONE
    } state_t;

    state_t state, next_state;

    // 状态跳转
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE:  if (cmd_valid) next_state = PARSE;
            PARSE: next_state = DONE;
            DONE:  next_state = IDLE;
        endcase
    end

    // 输出逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            opcode   <= 0;
            addr     <= 0;
            data     <= 0;
            cmd_done <= 0;
            cmd_ready<= 1;
        end else begin
            cmd_done <= 0;

            case(state)
                PARSE: begin
                    opcode <= cmd_data[255:248];
                    addr   <= cmd_data[247:192];
                    data   <= cmd_data[127:0];
                end
                DONE: begin
                    cmd_done <= 1;
                end
            endcase
        end
    end

endmodule
