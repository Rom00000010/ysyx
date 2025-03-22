/* verilator lint_off UNUSEDSIGNAL */
`include "axi_interface.vh"

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
        output reg [31:0]instr,

        // AXI interface
        `AXI_MASTER_READ_ADDR_PORTS
    );

    wire [31:0]next_pc = access_fault ? 32'h0000_0000 : (branch_taken ? branch_target : pc+4);
    // PC register
    ysyx_25020032_Reg #(.WIDTH(32), .RESET_VAL(32'h2000_0000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(next_pc), .dout(pc), .wen(wbu_valid && ifu_ready)
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

    reg [31:0]instr_latch;
    reg [1:0]rresp_latch;
    // Output logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            arvalid <= 1'b0;
            rready <= 1'b0;
            ifu_valid <= 1'b0;
            ifu_ready <= 1'b0;
            instr_latch <= 32'h0;
            rresp_latch <= 2'b00;
            // Set default values for AXI signals
            arid <= `AXI_DEFAULT_ID;
            arlen <= `AXI_DEFAULT_LEN;
            arsize <= `AXI_DEFAULT_SIZE;
            arburst <= `AXI_DEFAULT_BURST;
        end
        else begin
            case (state)
                IDLE: begin
                    ifu_valid <= 1'b0;
                    ifu_ready <= 1'b1;
                    if(wbu_valid && ifu_ready) begin
                        arvalid <= 1'b1;
                        rready <= 1'b1;
                        araddr <= next_pc;
                        instr_latch <= 32'h0;
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
                        instr_latch <= rdata;
                        rresp_latch <= rresp;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    assign instr = rresp_latch == 2'b00 ? instr_latch : 32'h0;

    // Alarm simulation environment to stop for ebreak instruction
    always @(*) begin
        if(instr == 32'h00100073) begin
            set_finish();
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
