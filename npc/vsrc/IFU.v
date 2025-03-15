/* verilator lint_off UNUSEDSIGNAL */
module IFU(
        input clk,
        input rst,

        output reg ifu_valid,
        input idu_ready,

        input wbu_valid,
        output reg ifu_ready,

        input branch_taken,
        input [31:0]branch_target,

        output [31:0]pc,
        output reg [31:0]instr,

        // AXI interface
        output reg [31:0] araddr,
        output reg arvalid,
        input arready,
        input [31:0] rdata,
        input [1:0] rresp,
        input rvalid,
        output reg rready
    );

    // PC register
    Reg #(.WIDTH(32), .RESET_VAL(32'h80000000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(branch_taken ? branch_target : pc+4), .dout(pc), .wen(wbu_valid && ifu_ready)
        );

    // =================================State Machine===========================================

    localparam IDLE = 2'd0;
    localparam FETCH = 2'd1;
    localparam WAIT = 2'd2;

    reg [1:0]state, next_state;

    always @(posedge clk or posedge rst) begin
        if(rst)
            state <= FETCH;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if(wbu_valid && ifu_ready) begin
                    next_state = FETCH;
                end
            end
            FETCH: begin
                if(arready && arvalid) begin
                    next_state = WAIT;
                end
            end
            WAIT: begin
                if(rvalid && rready) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            arvalid <= 1'b0;
            rready <= 1'b0;
            ifu_valid <= 1'b0;
            ifu_ready <= 1'b0;
            instr <= 32'h0;
        end
        else begin
            case (state)
                IDLE: begin
                    ifu_valid <= 1'b0;
                    ifu_ready <= 1'b1;
                    if(wbu_valid && ifu_ready) begin
                        arvalid <= 1'b1;
                        rready <= 1'b1;
                        instr <= 32'h0;
                    end
                end
                FETCH: begin
                    arvalid <= 1'b1;
                    araddr <= pc;
                    rready <= 1'b1;
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                    end
                end
                WAIT: begin
                    if(rvalid && rready) begin
                        ifu_valid <= 1'b1;
                        ifu_ready <= 1'b1;
                        rready <= 1'b0;
                        instr <= rdata;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    // Alarm simulation environment to stop for ebreak instruction
    always @(*) begin
        if(instr == 32'h00100073) begin
            set_finish();
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
