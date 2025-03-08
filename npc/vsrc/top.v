`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();
import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

module top (
        input clk,
        input rst);

    wire [31:0]pc;
    wire [31:0]instr;

    IFU ifu(
            .clk(clk), .rst(rst), 
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

    IDU idu (
            .instr(instr), .pc(pc), 
            .wdata_regd(wdata_regd), .csr_in(csr_in), 
            .clk(clk), .rst(rst), 
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
            .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .alu_ctrl(alu_ctrl), .branch_type(branch_type), .mem_width(mem_width),
            .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .pc(pc), .ext_imm(ext_imm), 
            .mepc(mepc), .mtvec(mtvec),
            .alu_res(alu_res), .branch_taken(branch_taken), .branch_target(branch_target),
            .raddr(raddr), .waddr(waddr), .wdata(wdata), .wmask(wmask)
    );

    WBU wbu(
        .clk(clk), .rst(rst),
        .valid(valid), .mem_wen(mem_wen), 
        .wb_sel(wb_sel), .csr_write_set(csr_write_set), .mem_width(mem_width),
        .alu_res(alu_res),  .pc(pc),  
        .data_reg1(data_reg1), 
        .waddr(waddr), .raddr(raddr), .wdata(wdata), .wmask(wmask),
        .csr_out(csr_out), 
        .wdata_regd(wdata_regd), .csr_in(csr_in)
        );

    function automatic int get_dnpc();
        get_dnpc = branch_target;
    endfunction

    function automatic int get_instr();
        get_instr = instr;
    endfunction

    function automatic int get_pc_val();
        get_pc_val = pc;
    endfunction

    export "DPI-C" function get_dnpc;
    export "DPI-C" function get_instr;
    export "DPI-C" function get_pc_val;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
