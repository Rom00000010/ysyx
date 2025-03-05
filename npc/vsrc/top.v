`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();
import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

module top (
        input clk,
        input rst);

    wire [31:0]next_pc;
    wire [31:0]pc_val;
    wire [31:0]instr;

    IFU ifu(
            .clk(clk), .rst(rst), 
            .next_pc(next_pc), 
            .pc_val(pc_val), .instr(instr)
    );

    // Control signal
    AluCtrl alu_ctrl;
    wire [1:0]alu_srca;
    wire [1:0]alu_srcb;
    wire [2:0]mem_width;
    Branch branch;
    wire [1:0]write_src;
    wire mem_wen;
    wire valid;

    // Operand / Writeback result
    wire [31:0]data_reg1, data_reg2, wdata_regd;
    wire [31:0]ext_imm;

    wire [31:0]csr_out;
    wire [31:0]csr_in;
    wire [31:0]mtvec;
    wire [31:0]mepc;

    IDU idu (
            .instr(instr), .pc_val(pc_val), 
            .wdata_regd(wdata_regd), .csr_in(csr_in), 
            .clk(clk), .rst(rst), 
            .alu_ctrl(alu_ctrl), .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .branch(branch), .write_src(write_src), 
            .mem_wen(mem_wen), .valid(valid), .mem_width(mem_width),
            .ext_imm(ext_imm), .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .csr_out(csr_out), .mepc(mepc), .mtvec(mtvec)
    );

    wire [31:0]alu_res;
    EXU exu(
            .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .alu_ctrl(alu_ctrl), 
            .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .pc_val(pc_val), .ext_imm(ext_imm), 
            .alu_res(alu_res)
    );

    WBU wbu(
        .clk(clk), 
        .valid(valid), .mem_wen(mem_wen), 
        .mem_width(mem_width), .branch(branch), .write_src(write_src), 
        .alu_res(alu_res), .ext_imm(ext_imm), .pc_val(pc_val),  
        .data_reg1(data_reg1), .data_reg2(data_reg2), 
        .mepc(mepc), .mtvec(mtvec), .csr_out(csr_out), 
        .next_pc(next_pc), .wdata_regd(wdata_regd), .csr_in(csr_in)
        );

    function automatic int get_dnpc();
        get_dnpc = next_pc;
    endfunction

    function automatic int get_instr();
        get_instr = instr;
    endfunction

    function automatic int get_pc_val();
        get_pc_val = pc_val;
    endfunction

    export "DPI-C" function get_dnpc;
    export "DPI-C" function get_instr;
    export "DPI-C" function get_pc_val;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
