`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();

// 不带默认值的选择器模板
module MuxKey #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1) (
  output [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);
  MuxKeyInternal #(NR_KEY, KEY_LEN, DATA_LEN, 0) i0 (out, key, {DATA_LEN{1'b0}}, lut);
endmodule

// 带默认值的选择器模板
module MuxKeyWithDefault #(NR_KEY = 2, KEY_LEN = 1, DATA_LEN = 1) (
  output [DATA_LEN-1:0] out,
  input [KEY_LEN-1:0] key,
  input [DATA_LEN-1:0] default_out,
  input [NR_KEY*(KEY_LEN + DATA_LEN)-1:0] lut
);
  MuxKeyInternal #(NR_KEY, KEY_LEN, DATA_LEN, 1) i0 (out, key, default_out, lut);
endmodule
/* verilator lint_on DECLFILENAME */

module top (
        output [31:0]pc_val,
        input clk,
        input rst,
        input [31:0]instr);

    wire [31:0]snpc;
    wire [31:0]dnpc;
    wire [31:0]nextpc;
    wire [31:0]ext_imm;

    imm_type imm_src;
    wire branch;
    wire reg_write;
    wire [6:0]opcode;
    wire [2:0] func3;
    wire func7;

    wire [4:0]rs1, rs2, rd;
    wire [31:0]data_reg1, data_reg2, wdata_regd;

    // PC register
    Reg #( .WIDTH(32), .RESET_VAL(32'h80000000) ) pc (
            .clk(clk), .rst(rst),
            .din(dnpc), .dout(pc_val), .wen(1'b1)
        );

    // ebreak: stop similation
    always begin
        if(instr == 32'h00100073)
            set_finish();
    end

    // extract operand & opcode/func
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd = instr[11:7];
    assign func3 = instr[14:12];
    assign func7 = instr[30];
    assign opcode = instr[6:0];

    assign snpc = pc_val + 32'd4;
    assign dnpc = pc_val + ext_imm;
    MuxKeyWithDefault #(1, 1, 32) pc_mux(
        nextpc, branch, snpc, {
            1'b1, dnpc,
        }
    );

    CtrlU ctrl (.opcode(opcode), .func3(func3), .func7(func7), .imm_src(imm_src), .reg_write(reg_write), .branch(branch));

    Ext extender (.imm_src(imm_src), .instr(instr), .imm(ext_imm));

    RegisterFile #(.ADDR_WIDTH(5), .DATA_WIDTH(32)) regfile (
                    .clk(clk), .wdata(wdata_regd), .rst(rst),
                    .waddr(rd), .raddr1(rs1), .rdata1(data_reg1),
                    .raddr2(rs2), .rdata2(data_reg2), .wen(reg_write)
                );


    wire [31:0]opl;
    MuxKey #(4, 7, 32) op1 (
                opl, opcode, {
                    7'b0110111, 32'b0, // U-type lui
                    7'b0010011, data_reg1, //I-type addi
                    7'b0010111, pc_val, // U-type auipc
                    7'b1101111, pc_val, // J-type jal
                    7'b1100111, pc_val // J-type jal
                }
            );

    wire [31:0]opr;
    MuxKeyWithDefault #(1, 7, 32) op2 (
                opr, opcode, ext_imm, {
                    7'b1101111, 32'd4, // J-type jal
                    7'b1100111, 32'd4  // J-type jalr
                }
            );

    assign wdata_regd = opl + opr;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
