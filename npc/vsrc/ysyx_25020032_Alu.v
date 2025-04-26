`include "common.vh"
module ysyx_25020032_Alu(
        input AluCtrl alu_ctrl,
        input [31:0]a,
        input [31:0]b,
        output [31:0]result
    );

    // ysyx_25020032_MuxKey #(10, 4, 32) alu_mux(
    //     result, alu_ctrl, {
    //         ADD, a+b,
    //         SUB, a-b,
    //         SLL, a<<b,
    //         LESS, {31'b0, ($signed(a) < $signed(b))},
    //         LESSU, {31'b0, a<b},
    //         XOR, a^b,
    //         SRL, a>>b,
    //         SRA, $signed(a)>>>b,
    //         OR, a|b,
    //         AND, a&b
    //     }
    // );

    assign result = {32{alu_ctrl == ADD}} & (a + b) |
                    {32{alu_ctrl == SUB}} & (a - b) |
                    {32{alu_ctrl == XOR}} & (a ^ b) |
                    {32{alu_ctrl == OR}} & (a | b) |
                    {32{alu_ctrl == AND}} & (a & b) |
                    {32{alu_ctrl == LESS}} & {31'b0, ($signed(a) < $signed(b))} |
                    {32{alu_ctrl == LESSU}} & {31'b0, a < b} |
                    {32{alu_ctrl == SLL}} & (a << b[4:0]) |
                    {32{alu_ctrl == SRL}} & (a >> b[4:0]) |
                    {32{alu_ctrl == SRA}} & sra_res;

    wire signed [31:0] sra_res;
    assign sra_res = $signed(a) >>> $signed(b[4:0]);

    // wire [31:0] add_r  = a + b;
    // wire [31:0] sub_r  = a - b;
    // wire [31:0] xor_r  = a ^ b;
    // wire [31:0] or_r   = a | b;
    // wire [31:0] and_r  = a & b;

    // wire [31:0] shl_r = a << b[4:0];
    // wire [31:0] shr_r = a >> b[4:0];
    // wire [31:0] sra_r = $signed(a) >>> b[4:0];
    // wire [31:0] less_r = {31'b0, sub_r[31] ^ sub_r[30]};
    // wire [31:0] lessu_r = {31'b0, sub_r[31]};

    // always_comb begin
    // unique case (alu_ctrl)
    //   ADD  : result = add_r;
    //   SUB  : result = sub_r;
    //   XOR  : result = xor_r;
    //   OR   : result = or_r;
    //   AND  : result = and_r;
    //   SLL  : result = shl_r;
    //   SRL  : result = shr_r;
    //   SRA  : result = sra_r;
    //   LESS : result = less_r;
    //   LESSU: result = lessu_r;
    //   default: result = 32'hx;
    // endcase
    // end

endmodule