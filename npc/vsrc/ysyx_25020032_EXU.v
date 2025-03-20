/* verilator lint_off UNUSEDSIGNAL */
module ysyx_25020032_EXU(
        input clk,
        input rst,

        input idu_valid,
        output reg exu_ready,

        output reg exu_valid,
        input wbu_ready,

        input [1:0]alu_srca,
        input [1:0]alu_srcb,
        input [3:0]alu_ctrl,
        input Branch branch_type,
        input [2:0]mem_width,

        input [31:0]data_reg1,
        input [31:0]data_reg2,
        input [31:0]ext_imm,
        input [31:0]pc,
        input [31:0]mtvec,
        input [31:0]mepc,

        output wire [31:0]alu_res,
        output [31:0]branch_target,
        output branch_taken,

        output [31:0]waddr,
        output [31:0]raddr,
        output [31:0]wdata,
        output [3:0]wmask
    );

    always @(*) begin
        if(rst) begin
            exu_valid = 1'b0;
            exu_ready = 1'b0;
        end
        else begin
            exu_valid = idu_valid && exu_ready;
            exu_ready = 1'b1;
        end
    end

    wire [31:0]opl;
    ysyx_25020032_MuxKey #(3, 2, 32) op1 (
               opl, alu_srca,{
                   2'b00, data_reg1,
                   2'b01, 32'b0,
                   2'b10, pc
               }
           );

    wire [31:0]opr;
    ysyx_25020032_MuxKey #(3, 2, 32) op2 (
               opr, alu_srcb, {
                   2'b00, data_reg2,
                   2'b01, ext_imm,
                   2'b10, data_reg2 & 32'h0000001f
               }
           );

    ysyx_25020032_Alu alu(.alu_ctrl(alu_ctrl), .a(opl), .b(opr), .result(alu_res));

    // Calculate whether branch taken and target address

    ysyx_25020032_MuxKey #(10, 4, 32) next_pc_mux(
               branch_target, branch_type, {
                   JAL,   pc+ext_imm,
                   JALR,  (data_reg1 + ext_imm)&~1,
                   BEQ,   pc+ext_imm,
                   BNE,   pc+ext_imm,
                   BLT,   pc+ext_imm,
                   BGE,   pc+ext_imm,
                   BLTU,  pc+ext_imm,
                   BGEU,  pc+ext_imm,
                   ECALL, mtvec,
                   MRET,  mepc
               }
           );

    ysyx_25020032_MuxKeyWithDefault #(10, 4, 1) branch_taken_mux(
                          branch_taken, branch_type, 0, {
                              BEQ,   alu_res == 0,
                              BNE,   alu_res!= 0,
                              BLT,   alu_res == 1,
                              BGE,   alu_res!= 1,
                              BLTU,  alu_res == 1,
                              BGEU,  alu_res!= 1,
                              JAL,   1'b1,
                              JALR,  1'b1,
                              ECALL, 1'b1,
                              MRET,  1'b1
                          }
                      );

    // Calculate memory write signal
    assign waddr = alu_res;
    assign raddr = alu_res;
    assign wdata = data_reg2;

    // Generate wmask based on which part of the 4 bytes need to write
    wire [3:0] sb_mask = (4'b0001 << waddr[1:0]);
    wire [3:0] sh_mask = (waddr[1:0] == 2'b00) ? 4'b0011 :
         (waddr[1:0] == 2'b10) ? 4'b1100 :
         4'b0000;

    wire [3:0] sw_mask = 4'b1111;

    ysyx_25020032_MuxKey #(3, 3, 4) wmask_mux(
               wmask, mem_width, {
                   3'b000, sb_mask,
                   3'b001, sh_mask,
                   3'b010, sw_mask
               }
           );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
