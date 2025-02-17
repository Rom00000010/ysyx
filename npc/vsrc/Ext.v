`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
module Ext(
        input InstrType imm_src,
        input [31:0]instr,
        output [31:0]imm
    );

    wire [2:0] func3 = instr[14:12];
    wire [6:0] opcode = instr[6:0]; 
    wire shamt = (opcode == 7'b0010011) && (func3 == 3'b101 || func3 == 3'b001);

    wire [31:0] itype_imm = shamt ? { {27{1'b0}}, instr[24:20] } : { {20{instr[31]}}, instr[31:20] };
    wire [31:0] utype_imm = { instr[31:12], 12'b0 };
    wire [31:0] jtype_imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    wire [31:0] stype_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] btype_imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    MuxKey #(5, 3, 32) extender (
               imm, imm_src, {
                   I_TYPE, itype_imm,
                   U_TYPE, utype_imm,
                   J_TYPE, jtype_imm,
                   S_TYPE, stype_imm,
                   B_TYPE, btype_imm
               }
           );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
