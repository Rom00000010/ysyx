`include "common.vh"
module top (
        input clk,
        input rst,
        output [31:0]instr,
        output [31:0]pc
        );

    wire ifu_ready;
    wire ifu_valid;
    wire idu_ready;
    wire idu_valid;
    wire exu_ready;
    wire exu_valid;
    wire wbu_ready;
    wire wbu_valid;

    wire [31:0]pc;
    wire [31:0]instr;

    IFU ifu(
            .clk(clk), .rst(rst), 
            .ifu_valid(ifu_valid), .idu_ready(idu_ready),
            .exu_valid(exu_valid), .ifu_ready(ifu_ready),
            .branch_taken(branch_taken), .branch_target(branch_target), 
            .pc(pc), .instr(instr)
    );

    // Control signal
    AluCtrl alu_ctrl;
    wire [1:0]alu_srca;
    wire [1:0]alu_srcb;
    wire [2:0]mem_width;
    Branch branch_type;
    wire [1:0]wb_sel;
    wire mem_wen;
    wire valid;
    wire csr_write_set;

    // Operand / Writeback result
    wire [31:0]data_reg1, data_reg2, wdata_regd;
    wire [31:0]ext_imm;

    wire [31:0]csr_out;
    wire [31:0]csr_in;
    wire [31:0]mtvec;
    wire [31:0]mepc;
    wire [31:0]pc_handshake;

    IDU idu (
            .instr(instr), .pc(pc), .pc_handshake(pc_handshake),
            .wdata_regd(wdata_regd), .csr_in(csr_in), 
            .clk(clk), .rst(rst), 
            .ifu_valid(ifu_valid), .idu_ready(idu_ready),
            .idu_valid(idu_valid),  .exu_ready(exu_ready), .wbu_valid(wbu_valid),
            .alu_ctrl(alu_ctrl), .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .branch_type(branch_type), .wb_sel(wb_sel), 
            .mem_wen(mem_wen), .valid(valid), .mem_width(mem_width),
            .ext_imm(ext_imm), .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .csr_out(csr_out), .mepc(mepc), .mtvec(mtvec), .csr_write_set(csr_write_set)
    );

    wire [31:0]alu_res;
    wire branch_taken;
    wire [31:0]branch_target;
    wire [31:0]raddr;
    wire [31:0]waddr;
    wire [31:0]wdata;
    wire [7:0]wmask;
    EXU exu(  
            .clk(clk), .rst(rst),
            .idu_valid(idu_valid), .exu_ready(exu_ready), 
            .exu_valid(exu_valid), .ifu_ready(ifu_ready), .wbu_ready(wbu_ready), 
            .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .alu_ctrl(alu_ctrl), .branch_type(branch_type), .mem_width(mem_width),
            .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .pc(pc_handshake), .ext_imm(ext_imm), 
            .mepc(mepc), .mtvec(mtvec),
            .alu_res(alu_res), .branch_taken(branch_taken), .branch_target(branch_target),
            .raddr(raddr), .waddr(waddr), .wdata(wdata), .wmask(wmask)
    );

    WBU wbu(
        .clk(clk), .rst(rst),
        .exu_valid(exu_valid), .wbu_ready(wbu_ready), .idu_valid(idu_valid), 
        .wbu_valid(wbu_valid), .idu_ready(idu_ready),
        .valid(valid), .mem_wen(mem_wen), 
        .wb_sel(wb_sel), .csr_write_set(csr_write_set), .mem_width(mem_width),
        .alu_res(alu_res),  .pc(pc_handshake),  
        .data_reg1(data_reg1), 
        .waddr(waddr), .raddr(raddr), .wdata(wdata), .wmask(wmask),
        .csr_out(csr_out), 
        .wdata_regd(wdata_regd), .csr_in(csr_in)
        );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
