`include "common.vh"
module Alu(
        input AluCtrl alu_ctrl,
        input [31:0]a,
        input [31:0]b,
        output [31:0]result
    );

    MuxKey #(10, 4, 32) alu_mux(
        result, alu_ctrl, {
            ADD, a+b,
            SUB, a-b,
            SLL, a<<b,
            LESS, {31'b0, ($signed(a) < $signed(b))},
            LESSU, {31'b0, a<b},
            XOR, a^b,
            SRL, a>>b,
            SRA, $signed(a)>>>b,
            OR, a|b,
            AND, a&b
        }
    );

endmodule
