`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
module CtrlU(
        input [6:0]opcode,
        input [2:0]func3,
        input func7,
        output imm_type imm_src,
        output reg_write,
        output branch,
        output jalr
    );

    MuxKey #(6,7,3) imm_src_mux(
               imm_src, opcode, {
                   7'b0110111, IMM_U, // U-type lui
                   7'b0100011, IMM_S, // S-type sw
                   7'b0010011, IMM_I, // I-type addi
                   7'b0010111, IMM_U, // U-type auipc
                   7'b1101111, IMM_J, // J-type jal
                   7'b1100111, IMM_I  // I-type jalr
               }
           );

    MuxKeyWithDefault #(5,7,1) reg_write_mux(
                          reg_write, opcode, 1'b0, {
                              7'b0110111, 1'b1, // U-type lui
                              7'b0010011, 1'b1, // I-type addi
                              7'b0010111, 1'b1, // U-type auipc
                              7'b1101111, 1'b1, // J-type jal
                              7'b1100111, 1'b1  // I-type jalr
                          }
                      );

    MuxKeyWithDefault #(2, 7, 1) branch_mux(
                          branch, opcode, 1'b0, {
                              7'b1101111, 1'b1, // J-type jal
                              7'b1100111, 1'b1  // J-type jalr
                          }
                      );

    MuxKeyWithDefault #(1, 7, 1) jalr_mux(
                          jalr, opcode, 1'b0, {
                              7'b1100111, 1'b1  // J-type jalr
                          }
                      );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
