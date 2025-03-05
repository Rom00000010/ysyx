module EXU(
    input [1:0]alu_srca,
    input [1:0]alu_srcb,
    input [3:0]alu_ctrl,
    input [31:0]data_reg1,
    input [31:0]data_reg2,
    input [31:0]ext_imm,
    input [31:0]pc_val,
    
    output wire [31:0]alu_res
);
    wire [31:0]opl;
    MuxKey #(3, 2, 32) op1 (
                opl, alu_srca,{
                    2'b00, data_reg1,
                    2'b01, 32'b0,
                    2'b10, pc_val                                   
                }
            );

    wire [31:0]opr;
    MuxKey #(3, 2, 32) op2 (
                opr, alu_srcb, {
                    2'b00, data_reg2,
                    2'b01, ext_imm,
                    2'b10, data_reg2 & 32'h0000001f
                }
            );

    Alu alu(.alu_ctrl(alu_ctrl), .a(opl), .b(opr), .result(alu_res));

endmodule
