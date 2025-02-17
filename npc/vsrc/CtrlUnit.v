`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
module CtrlUnit(
        input [6:0]opcode,
        input [2:0]func3,
        input func7,
        output InstrType imm_src,
        output AluCtrl alu_ctrl,
        output [1:0]alu_srca,
        output [1:0]alu_srcb,
        output reg_write,
        output write_src,
        output Branch branch,
        output mem_wen
    );

    InstrType instr_type;
    MuxKey #(9,7,3) instr_type_mux(
               instr_type, opcode, {
                   7'b0110111, U_TYPE, // U-type lui
                   7'b0110011, R_TYPE, // R-type arithmetic
                   7'b0100011, S_TYPE, // S-type sw
                   7'b0010011, I_TYPE, // I-type arithmetic
                   7'b0010111, U_TYPE, // U-type auipc
                   7'b1101111, J_TYPE, // J-type jal
                   7'b1100111, I_TYPE, // I-type jalr
                   7'b1100011, B_TYPE,
                   7'b0000011, I_TYPE  // I-type lw
               }
           );
    // Extend imm based on instruction type
    assign imm_src = instr_type;

    // Itype: lw(add for address), I/R type arithmetic, jalr(don't use alu to calculate)
    wire [3:0]srial = (func3==3'b101)? {func7, func3} : {1'b0, func3};
    wire [3:0]itype_ctrl = (opcode==7'b0000011) ? 4'b0000 : srial;
    wire [3:0]btype_ctrl;
    MuxKey #(5,3,4) alu_ctrl_mux(
               alu_ctrl, instr_type, {
                   U_TYPE, ADD,         
                   I_TYPE, itype_ctrl,
                   R_TYPE, {func7,func3},// arithmetic
                   B_TYPE, btype_ctrl,   // branch condition
                   S_TYPE, ADD           // address
               }
           );

    MuxKey #(6, 4, 4) btype_ctrl_mux(
               btype_ctrl, btype_branch, {
                   BEQ,  SUB,
                   BNE,  SUB,
                   BLT,  LESS,
                   BGE,  LESS,
                   BLTU, LESSU,
                   BGEU, LESSU
               }
           );

    // for lui & auipc special case 
    wire [1:0] u_srca = (opcode == 7'b0110111) ? 2'b01 : 2'b10;
    wire shamtr_srca = (opcode == 7'b0110011 && (func3 == 3'b101 || func3 == 3'b001));
    // J-type don't use alu
    MuxKey #(5,3,2) alu_srca_mux(
               alu_srca, instr_type, {
                   I_TYPE, 2'b00,   // rs1
                   R_TYPE, 2'b00,   // rs1
                   B_TYPE, 2'b00,   // rs1
                   U_TYPE, u_srca,  // zero / pc
                   S_TYPE, 2'b00    // rs1
               }
           );

    MuxKey #(5,3,2) alu_srcb_mux(
               alu_srcb, instr_type, {
                   R_TYPE, shamtr_srca ? 2'b10 : 2'b00, // rs2
                   B_TYPE, 2'b0, // rs2
                   I_TYPE, 2'b1, // imm
                   U_TYPE, 2'b1, // imm
                   S_TYPE, 2'b1  // imm
               }
           );

    MuxKey #(6,3,1) reg_write_mux(
               reg_write, instr_type, {
                   I_TYPE, 1'b1,
                   R_TYPE, 1'b1,
                   S_TYPE, 1'b0,
                   U_TYPE, 1'b1,
                   J_TYPE, 1'b1,
                   B_TYPE, 1'b0
               }
           );

    Branch btype_branch;
    MuxKey #(6, 3, 4) btype_mux(
               btype_branch, func3, {
                   3'b000, BEQ,
                   3'b001, BNE,
                   3'b100, BLT,
                   3'b101, BGE,
                   3'b110, BLTU,
                   3'b111, BGEU
               }
           );

    MuxKey #(3, 7, 4) branch_mux(
               branch, opcode, {
                   7'b1101111, JAL,
                   7'b1100111, JALR,
                   7'b1100011, btype_branch
               }
           );

    MuxKey #(3, 4, 1) write_src_mux(
               write_src, branch, {
                   NO, 1'b0,   // alu_res
                   JAL, 1'b1,   // pc+4 for link
                   JALR, 1'b1
               }
           );

    MuxKey #(1, 7, 1) mem_wen_mux(
        mem_wen, opcode, {
            7'b0100011, 1'b1
        }
    );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
