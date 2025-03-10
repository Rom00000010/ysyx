/* verilator lint_off UNUSEDSIGNAL */
module IFU(
        input clk,
        input rst,
        input idu_ready,
        output reg ifu_valid,
        input exu_valid,
        output reg ifu_ready,

        input branch_taken,
        input [31:0]branch_target,

        output [31:0]pc,
        output reg [31:0]instr
    );

    // PC register
    Reg #(
            .WIDTH(32), .RESET_VAL(32'h80000000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(branch_taken ? branch_target : pc+4), .dout(pc), .wen(exu_valid && ifu_ready)
        );

    wire [31:0]trash;
    RegisterFile #(
                     .ADDR_WIDTH(8), .DATA_WIDTH(32)) regfile (
                     .clk(clk), .rst(rst),
                     .wdata(32'd1), .waddr(8'd5),
                     .raddr1(pc[7:0]), .rdata1(instr),
                     .raddr2(8'd5), .rdata2(trash),
                     .wen(1'b0)
                 );

    always @(*) begin
        if(rst) begin
            ifu_valid = 1'b0;
            ifu_ready = 1'b0;
        end
        else begin
            ifu_valid = 1'b1;
            ifu_ready = 1'b1;
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
