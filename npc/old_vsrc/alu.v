module alu(
        input clk,
        input rst,
        input [3:0] alu_ctrl,
        input [31:0]op1,
        input [31:0]op2,
        output reg[31:0]result
    );

    reg [31:0] a;
    reg [31:0] b;
    wire [31:0] res;
    ysyx_25020032_MuxKey #(10, 4, 32) alu_mux(
        res, alu_ctrl, {
            4'b0000, a+b,
            4'b0001, a-b,
            4'b0010, a<<b,
            4'b0011, {31'b0, ($signed(a) < $signed(b))},
            4'b0100, {31'b0, a<b},
            4'b0101, a^b,
            4'b0110, a>>b,
            4'b0111, $signed(a)>>>b,
            4'b1000, a|b,
            4'b1001, a&b
        }
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            result <= 0;
        end
        else begin
            a <= op1;
            b <= op2;
            result <= res;
        end
    end
endmodule
