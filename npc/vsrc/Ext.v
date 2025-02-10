`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
module Ext(
        input imm_type imm_src,
        input [31:0]instr,
        output [31:0]imm
    );

    wire [31:0] itype_imm;
    wire [31:0] utype_imm;
    wire [31:0] jtype_imm;
    wire [31:0] stype_imm;

    assign itype_imm = { {20{instr[31]}}, instr[31:20] };
    assign utype_imm = { instr[31:12], 12'b0 };
    assign jtype_imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    assign stype_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    MuxKey #(4, 3, 32) extender (
               imm, imm_src, {
                   IMM_I, itype_imm,
                   IMM_U, utype_imm,
                   IMM_J, jtype_imm,
                   IMM_S, stype_imm
               }
           );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
