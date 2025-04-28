module ysyx_25020032_IFU(
        input clk,
        input rst,

        // IFU->IDU synchronization
        output reg ifu_valid,
        input idu_ready,
        output reg[31:0]instr,

        // WBU->IFU synchronization
        input wbu_valid,
        output reg ifu_ready,
        input branch_taken,
        input [31:0]branch_target,

        // IFU->ICache synchronization
        output [31:0]pc,
        input [31:0] icache_instr,
        output reg icache_valid,
        input icache_ready
    );

    `ifdef FETCH_EVENT
        reg [31:0]fetch_event_cnt;
        initial begin
            fetch_event_cnt = 0;
        end
    `endif

    wire [31:0]next_pc = pc + 32'd4;
    // PC register
    ysyx_25020032_Reg #(.WIDTH(32), .RESET_VAL(32'h3000_0000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(next_pc), .dout(pc), .wen(ifu_valid && idu_ready)
        );

// ======================State Machine=======================
    localparam INIT = 2'b00,
               FETCH = 2'b01,
               IDLE = 2'b10;

    reg [1:0] state, next_state;
    always @(posedge clk) begin
        if(rst) begin
            state <= INIT;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            INIT: begin
                next_state = FETCH;
            end
            FETCH: begin
                if(icache_valid && icache_ready) begin
                    next_state = IDLE;
                end
            end
            IDLE: begin
                if(ifu_valid && idu_ready) begin
                    next_state = FETCH;
                end
            end
            default: begin end
        endcase
    end

// ======================Output Logic=======================
    always @(posedge clk) begin
        if(rst) begin
            icache_valid <= 1'b0;
            ifu_valid <= 1'b0;
        end
        else begin
            case(state)
                INIT: begin
                    icache_valid <= 1'b1;
                end
                FETCH: begin
                    if(icache_valid && icache_ready) begin
                        icache_valid <= 1'b0;
                        ifu_valid <= 1'b1;
                        instr <= icache_instr;

                        `ifdef FETCH_EVENT
                            fetch_event_cnt <= fetch_event_cnt + 1;
                        `endif
                    end
                end
                IDLE: begin
                    if(ifu_valid && idu_ready) begin
                        ifu_valid <= 1'b0;
                        icache_valid <= 1'b1;
                    end
                end
                default: begin end
            endcase
        end
    end

    assign ifu_ready = 1'b1;

endmodule
