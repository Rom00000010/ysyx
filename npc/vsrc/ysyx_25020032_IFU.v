/* verilator lint_off UNUSEDSIGNAL */

module ysyx_25020032_IFU(
        input clk,
        input rst,

        output reg ifu_valid,
        input idu_ready,

        input wbu_valid,
        output reg ifu_ready,

        input branch_taken,
        input [31:0]branch_target,
        input access_fault,

        output [31:0]pc,
        output reg[31:0]instr,

        input [31:0] icache_instr,
        output reg addr_valid,
        input addr_ready,
        input cache_valid,
        output cache_ready
    );

    `ifdef FETCH_EVENT
        reg [31:0]fetch_event_cnt;
        initial begin
            fetch_event_cnt = 0;
        end
    `endif

    wire [31:0]next_pc = access_fault ? 32'h0000_0000 : (branch_taken ? branch_target : pc + 32'd4);
    // PC register
    ysyx_25020032_Reg #(.WIDTH(32), .RESET_VAL(32'h3000_0000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(next_pc), .dout(pc), .wen(wbu_valid && ifu_ready)
        );
   
// ======================State Machine=======================
    localparam INIT = 1'b0,
               FETCH = 1'b1;

    reg state, next_state;
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
                next_state = FETCH;
            end
        endcase
    end

// ======================Output Logic=======================
    always @(posedge clk) begin
        if(rst) begin
            addr_valid <= 1'b0;
            ifu_valid <= 1'b0;
            instr <= 32'h0000_0000;
        end
        else begin
            case(state)
                INIT: begin
                    addr_valid <= 1'b1;
                end
                FETCH: begin
                    ifu_valid <= 1'b0;
                    if(wbu_valid && ifu_ready) begin
                        addr_valid <= 1'b1;
                        instr <= 32'h0000_0000;
                    end
                    if(cache_valid && cache_ready) begin
                        addr_valid <= 1'b0;
                        ifu_valid <= 1'b1;
                        instr <= icache_instr;

                        `ifdef FETCH_EVENT
                            fetch_event_cnt <= fetch_event_cnt + 1;
                        `endif
                    end
                end
            endcase
        end
    end

    assign cache_ready = (state == FETCH) ? 1'b1 : 1'b0;
    assign ifu_ready = (state == FETCH) ? 1'b1 : 1'b0;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
