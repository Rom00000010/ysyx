`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();
import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

module top (
        input clk,
        input rst);

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

    // IFU AXI signals
    wire [31:0] ifu_araddr;
    wire ifu_arvalid;
    wire ifu_arready;
    wire [31:0] ifu_rdata;
    wire [1:0] ifu_rresp;
    wire ifu_rvalid;
    wire ifu_rready;

    // WBU AXI signals
    wire [31:0] wbu_araddr;
    wire wbu_arvalid;
    wire wbu_arready;
    wire [31:0] wbu_rdata;
    wire [1:0] wbu_rresp;
    wire wbu_rvalid;
    wire wbu_rready;
    wire [31:0] wbu_awaddr;
    wire wbu_awvalid;
    wire wbu_awready;
    wire [31:0] wbu_wdata;
    wire [7:0] wbu_wstrb;
    wire wbu_wvalid;
    wire wbu_wready;
    wire wbu_bvalid;
    wire [1:0] wbu_bresp;
    wire wbu_bready;

    // SRAM AXI signals
    wire [31:0] mem_araddr;
    wire mem_arvalid;
    wire mem_arready;
    wire [31:0] mem_rdata;
    wire [1:0] mem_rresp;
    wire mem_rvalid;
    wire mem_rready;
    wire [31:0] mem_awaddr;
    wire mem_awvalid;
    wire mem_awready;
    wire [31:0] mem_wdata;
    wire [7:0] mem_wstrb;
    wire mem_wvalid;
    wire mem_wready;
    wire [1:0] mem_bresp;
    wire mem_bvalid;
    wire mem_bready;

    IFU ifu(
            .clk(clk), .rst(rst), 
            .ifu_valid(ifu_valid), .idu_ready(idu_ready),
            .wbu_valid(wbu_valid), .ifu_ready(ifu_ready),
            .branch_taken(branch_taken), .branch_target(branch_target), 
            .pc(pc), .instr(instr),
            // AXI interface
            .araddr(ifu_araddr),
            .arvalid(ifu_arvalid),
            .arready(ifu_arready),
            .rdata(ifu_rdata),
            .rresp(ifu_rresp),
            .rvalid(ifu_rvalid),
            .rready(ifu_rready)
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

    // Operand 
    wire [31:0]data_reg1, data_reg2;
    wire [31:0]ext_imm;

    // Csr 
    wire [31:0]csr_out;
    wire [31:0]mtvec;
    wire [31:0]mepc;

    // Writeback result
    wire [31:0]csr_in, wdata_regd;

    IDU idu (
            .clk(clk), .rst(rst), 
            .instr(instr), .pc(pc),
            .wdata_regd(wdata_regd), .csr_in(csr_in), 
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
            .exu_valid(exu_valid), .wbu_ready(wbu_ready), 
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
        .exu_valid(exu_valid), .wbu_ready(wbu_ready), .idu_valid(idu_valid), 
        .wbu_valid(wbu_valid), .idu_ready(idu_ready),
        .valid(valid), .mem_wen(mem_wen), 
        .wb_sel(wb_sel), .csr_write_set(csr_write_set), .mem_width(mem_width),
        .alu_res(alu_res), .pc(pc),  
        .data_reg1(data_reg1), 
        .waddr(waddr), .raddr(raddr), .wdata(wdata), .wmask(wmask),
        .csr_out(csr_out), 
        .wdata_regd(wdata_regd), .csr_in(csr_in),
        // AXI interface
        .araddr(wbu_araddr),
        .arvalid(wbu_arvalid),
        .arready(wbu_arready),
        .rdata(wbu_rdata),
        .rresp(wbu_rresp),
        .rvalid(wbu_rvalid),
        .rready(wbu_rready),
        .awaddr(wbu_awaddr),
        .awvalid(wbu_awvalid),
        .awready(wbu_awready),
        .wdata_out(wbu_wdata),
        .wstrb(wbu_wstrb),
        .wvalid(wbu_wvalid),
        .wready(wbu_wready),
        .bvalid(wbu_bvalid),
        .bresp(wbu_bresp),
        .bready(wbu_bready)
    );

    // Instantiate the arbiter
    Arbiter arbiter(
        .clk(clk),
        .rst(rst),
        // IFU interface
        .ifu_araddr(ifu_araddr),
        .ifu_arvalid(ifu_arvalid),
        .ifu_arready(ifu_arready),
        .ifu_rdata(ifu_rdata),
        .ifu_rresp(ifu_rresp),
        .ifu_rvalid(ifu_rvalid),
        .ifu_rready(ifu_rready),
        // WBU interface
        .wbu_araddr(wbu_araddr),
        .wbu_arvalid(wbu_arvalid),
        .wbu_arready(wbu_arready),
        .wbu_rdata(wbu_rdata),
        .wbu_rresp(wbu_rresp),
        .wbu_rvalid(wbu_rvalid),
        .wbu_rready(wbu_rready),
        .wbu_awaddr(wbu_awaddr),
        .wbu_awvalid(wbu_awvalid),
        .wbu_awready(wbu_awready),
        .wbu_wdata(wbu_wdata),
        .wbu_wstrb(wbu_wstrb),
        .wbu_wvalid(wbu_wvalid),
        .wbu_wready(wbu_wready),
        .wbu_bvalid(wbu_bvalid),
        .wbu_bresp(wbu_bresp),
        .wbu_bready(wbu_bready),
        // SRAM interface
        .mem_araddr(mem_araddr),
        .mem_arvalid(mem_arvalid),
        .mem_arready(mem_arready),
        .mem_rdata(mem_rdata),
        .mem_rresp(mem_rresp),
        .mem_rvalid(mem_rvalid),
        .mem_rready(mem_rready),
        .mem_awaddr(mem_awaddr),
        .mem_awvalid(mem_awvalid),
        .mem_awready(mem_awready),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_wvalid(mem_wvalid),
        .mem_wready(mem_wready),
        .mem_bresp(mem_bresp),
        .mem_bvalid(mem_bvalid),
        .mem_bready(mem_bready)
    );

    // Single SRAM instance
    Sram sram(
        .clk(clk),
        .rst(rst),
        .araddr(mem_araddr),
        .arvalid(mem_arvalid),
        .arready(mem_arready),
        .rdata(mem_rdata),
        .rresp(mem_rresp),
        .rvalid(mem_rvalid),
        .rready(mem_rready),
        .awaddr(mem_awaddr),
        .awvalid(mem_awvalid),
        .awready(mem_awready),
        .wdata(mem_wdata),
        .wstrb(mem_wstrb),
        .wvalid(mem_wvalid),
        .wready(mem_wready),
        .bresp(mem_bresp),
        .bvalid(mem_bvalid),
        .bready(mem_bready)
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
