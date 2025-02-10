`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();

module top (
        output [31:0]pc_val,
        output [31:0]ret_val,
        input clk,
        input rst,
        input [31:0]instr);

    wire [31:0]snpc;
    wire [31:0]dnpc;
    wire [31:0]nextpc;

    imm_type imm_src;
    wire branch;
    wire reg_write;
    wire jalr;

    wire [6:0]opcode;
    wire [2:0] func3;
    wire func7;
    wire [3:0]rs1, rs2, rd;

    wire [31:0]data_reg1, data_reg2, wdata_regd;
    wire [31:0]ext_imm;

    // PC register
    Reg #( .WIDTH(32), .RESET_VAL(32'h80000000) ) pc (
            .clk(clk), .rst(rst),
            .din(nextpc), .dout(pc_val), .wen(1'b1)
        );

    // ebreak: stop similation
    always begin
        if(instr == 32'h00100073)
            set_finish();
    end

    // extract operand & opcode/func
    assign rs1 = instr[18:15];
    assign rs2 = instr[23:20];
    assign rd = instr[10:7];
    assign func3 = instr[14:12];
    assign func7 = instr[30];
    assign opcode = instr[6:0];

    CtrlU ctrl (.opcode(opcode), .func3(func3), .func7(func7), .imm_src(imm_src), .reg_write(reg_write), .branch(branch), .jalr(jalr));

    Ext extender (.imm_src(imm_src), .instr(instr), .imm(ext_imm));

    RegisterFile #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) regfile (
                    .clk(clk), .wdata(wdata_regd), .rst(rst),
                    .waddr(rd), .raddr1(rs1), .rdata1(data_reg1),
                    .raddr2(rs2), .rdata2(data_reg2), .wen(reg_write), .ret_val(ret_val)
                );

    wire [31:0]opl;
    MuxKeyWithDefault #(2, 7, 32) op1 (
                opl, opcode, pc_val,{
                    7'b0110111, 32'b0,    // U-type lui
                    7'b0010011, data_reg1 // I-type addi
                }
            );

    wire [31:0]opr;
    MuxKeyWithDefault #(2, 7, 32) op2 (
                opr, opcode, ext_imm, {
                    7'b1101111, 32'd4, // J-type jal
                    7'b1100111, 32'd4  // J-type jalr
                }
            );

    assign wdata_regd = opl + opr;

    assign snpc = pc_val + 32'd4;
    assign dnpc = jalr ? (data_reg1 + ext_imm)&~1 : pc_val + ext_imm;
    assign nextpc = branch? dnpc : snpc;

    function automatic int get_dnpc();
        get_dnpc = dnpc;
    endfunction

    export "DPI-C" function get_dnpc;
endmodule
/* verilator lint_on UNUSEDSIGNAL */
