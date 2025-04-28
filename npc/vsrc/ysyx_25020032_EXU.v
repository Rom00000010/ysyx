/* verilator lint_off UNUSEDSIGNAL */
`include "common.vh"
module ysyx_25020032_EXU(
        input clk,
        input rst,

        // IDU->EXU synchronization
        input idu_valid,
        output reg exu_ready,

        input [3:0]alu_ctrl,
        input [1:0]alu_srca,
        input [1:0]alu_srcb,
        input Branch branch_type,
        input [2:0]mem_width,
        input mem_wen,
        input valid,
        input [1:0]wb_sel,
        input csr_write_set,
        input id_csr_wen,
        input ecall,
        input [31:0] mcause,
        input reg_write,

        input [31:0]ext_imm,
        input [31:0]data_reg1,
        input [31:0]data_reg2,
        input [31:0]pc,

        // EXU->WBU synchronization
        output reg exu_valid,
        input wbu_ready,
        
        output reg [3:0] id_ex_branch_type,
        output reg [2:0] id_ex_mem_width,
        output reg id_ex_mem_wen,
        output reg id_ex_valid,
        output reg [1:0] id_ex_wb_sel,
        output reg id_ex_csr_write_set,
        output reg id_ex_csr_wen,
        output reg id_ex_reg_write,

        output reg [31:0] id_ex_ext_imm,
        output reg [31:0] id_ex_data_reg1,
        output [31:0] id_ex_csr_out,
        output [31:0] id_ex_mepc,
        output [31:0] id_ex_mtvec,
        output reg [31:0] id_ex_pc,

        output wire [31:0]alu_res,
        output [31:0]raddr,
        output [31:0]wdata,
        output [3:0]wmask,

        input wbu_valid,
        input [31:0]csr_in,
        input csr_wen
    );

    reg [3:0] id_ex_alu_ctrl;
    reg [1:0] id_ex_alu_srca;
    reg [1:0] id_ex_alu_srcb;
    reg [31:0] id_ex_data_reg2;
    reg id_ex_ecall;
    reg [31:0] id_ex_mcause;

    always @(posedge clk) begin
        if(rst) begin
            exu_valid <= 1'b0;
        end
        else begin
            if(idu_valid && exu_ready) begin
                exu_valid <= 1'b1;
                id_ex_alu_ctrl <= alu_ctrl;
                id_ex_alu_srca <= alu_srca;
                id_ex_alu_srcb <= alu_srcb;
                id_ex_branch_type <= branch_type;
                id_ex_mem_width <= mem_width;
                id_ex_mem_wen <= mem_wen;
                id_ex_valid <= valid;
                id_ex_wb_sel <= wb_sel;
                id_ex_csr_write_set <= csr_write_set;
                id_ex_csr_wen <= id_csr_wen;
                id_ex_ecall <= ecall;
                id_ex_mcause <= mcause;
                id_ex_reg_write <= reg_write;

                id_ex_ext_imm <= ext_imm;
                id_ex_data_reg1 <= data_reg1;
                id_ex_data_reg2 <= data_reg2;

                id_ex_pc <= pc;
            end
            else if(exu_valid && wbu_ready) begin
                exu_valid <= 1'b0;
            end
        end
    end

    assign exu_ready = wbu_ready;
    // =========================================================

    ysyx_25020032_Csr csr (
        .clk(clk), .rst(rst),
        .addr(id_ex_ext_imm[11:0]), .csr_out(id_ex_csr_out), 
        .csr_in(csr_in), .csr_wen(csr_wen && wbu_valid && exu_ready),
        .exception(id_ex_ecall), .exception_pc(id_ex_pc), .exception_cause(id_ex_mcause),
        .mtvec(id_ex_mtvec), .mepc(id_ex_mepc)
    );

    // =========================================================

    wire [31:0]opl;
    // ysyx_25020032_MuxKey #(3, 2, 32) op1 (
    //            opl, id_ex_alu_srca,{
    //                2'b00, id_ex_data_reg1,
    //                2'b01, 32'b0,
    //                2'b10, id_ex_pc
    //            }
    //        );

    assign opl = {32{(id_ex_alu_srca == 2'b00)}} & id_ex_data_reg1 |
                 {32{(id_ex_alu_srca == 2'b01)}} & 32'b0 |
                 {32{(id_ex_alu_srca == 2'b10)}} & id_ex_pc;

    wire [31:0]opr;
    // ysyx_25020032_MuxKey #(3, 2, 32) op2 (
    //            opr, id_ex_alu_srcb, {
    //                2'b00, id_ex_data_reg2,
    //                2'b01, id_ex_ext_imm,
    //                2'b10, id_ex_data_reg2 & 32'h0000001f
    //            }
    //        );

    assign opr = {32{(id_ex_alu_srcb == 2'b00)}} & id_ex_data_reg2 |
                     {32{(id_ex_alu_srcb == 2'b01)}} & id_ex_ext_imm |
                     {32{(id_ex_alu_srcb == 2'b10)}} & (id_ex_data_reg2 & 32'h0000001f);

    ysyx_25020032_Alu alu(.alu_ctrl(id_ex_alu_ctrl), .a(opl), .b(opr), .result(alu_res));

    // Calculate memory write signal
    wire [31:0] waddr = alu_res;
    assign raddr = alu_res;

    // Generate wmask based on which part of the 4 bytes need to write
    wire [3:0] sb_mask = (4'b0001 << waddr[1:0]);
    // wire [3:0] sh_mask = (waddr[1:0] == 2'b00) ? 4'b0011 :
    //      (waddr[1:0] == 2'b10) ? 4'b1100 :
    //      4'b0000;

    wire [3:0] sh_mask = {4{waddr[1:0] == 2'b00}} & 4'b0011 |
                         {4{waddr[1:0] == 2'b10}} & 4'b1100 |
                         4'b0000;

    wire [3:0] sw_mask = 4'b1111;

    // ysyx_25020032_MuxKey #(3, 3, 4) wmask_mux(
    //            wmask, id_ex_mem_width, {
    //                3'b000, sb_mask,
    //                3'b001, sh_mask,
    //                3'b010, sw_mask
    //            }
    //        );

    assign wmask = {4{id_ex_mem_width == 3'b000}} & sb_mask |
                   {4{id_ex_mem_width == 3'b001}} & sh_mask |
                   {4{id_ex_mem_width == 3'b010}} & sw_mask;

    wire [31:0]wbdata;
    // assign wbdata = wmask == 4'b0001 ? {24'd0,id_ex_data_reg2[7:0]} :
    //                 (wmask == 4'b0010 ? {16'd0, id_ex_data_reg2[7:0], 8'd0} :
    //                 (wmask == 4'b0100 ? {8'd0, id_ex_data_reg2[7:0], 16'd0} :
    //                 (wmask == 4'b1000 ? {id_ex_data_reg2[7:0], 24'd0} : 32'h0)));

    assign wbdata = {32{wmask == 4'b0001}} & {24'd0,id_ex_data_reg2[7:0]} |
                    {32{wmask == 4'b0010}} & {16'd0, id_ex_data_reg2[7:0], 8'd0} |
                    {32{wmask == 4'b0100}} & {8'd0, id_ex_data_reg2[7:0], 16'd0} |
                    {32{wmask == 4'b1000}} & {id_ex_data_reg2[7:0], 24'd0};

    // ysyx_25020032_MuxKey #(3, 3, 32) wdata_mux(
    //         wdata, id_ex_mem_width, {
    //             3'b000, wbdata,
    //             3'b001, sh_mask == 4'b1100 ? {id_ex_data_reg2[15:0], 16'd0} : {16'd0, id_ex_data_reg2[15:0]},
    //             3'b010, id_ex_data_reg2
    //         }
    //     );

    assign wdata = {32{id_ex_mem_width == 3'b000}} & wbdata |
                   {32{id_ex_mem_width == 3'b001}} & (sh_mask == 4'b1100 ? {id_ex_data_reg2[15:0], 16'd0} : {16'd0, id_ex_data_reg2[15:0]}) |
                   {32{id_ex_mem_width == 3'b010}} & id_ex_data_reg2;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
