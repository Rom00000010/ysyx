    `include "common.vh"
    /* verilator lint_off UNUSEDSIGNAL */
    import "DPI-C" function void set_finish ();
    import "DPI-C" function int pmem_read(input int raddr);
    import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);
    import "DPI-C" function void difftest_skip_ref();

    module top (
            input clk,
            input rst,
            // SoC AXI interface
            output [31:0] soc_araddr,
            output soc_arvalid,
            input soc_arready,
            input [31:0] soc_rdata,
            input [1:0] soc_rresp,
            input soc_rvalid,
            output soc_rready,
            output [31:0] soc_awaddr,
            output soc_awvalid,
            input soc_awready,
            output [31:0] soc_wdata,
            output [7:0] soc_wstrb,
            output soc_wvalid,
            input soc_wready,
            input [1:0] soc_bresp,
            input soc_bvalid,
            output soc_bready
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

        // CLINT AXI signals
        wire [31:0] clint_araddr;
        wire clint_arvalid;
        wire clint_arready;
        wire [31:0] clint_rdata;
        wire [1:0] clint_rresp;
        wire clint_rvalid;
        wire clint_rready;
        wire [31:0] clint_awaddr;
        wire clint_awvalid;
        wire clint_awready;
        wire [31:0] clint_wdata;
        wire [3:0] clint_wstrb;
        wire clint_wvalid;
        wire clint_wready;
        wire [1:0] clint_bresp;
        wire clint_bvalid;
        wire clint_bready;

        // Xbar AXI signals
        wire [31:0] xbar_araddr;
        wire xbar_arvalid;
        wire xbar_arready;
        wire [31:0] xbar_rdata;
        wire [1:0] xbar_rresp;
        wire xbar_rvalid;
        wire xbar_rready;
        wire [31:0] xbar_awaddr;
        wire xbar_awvalid;
        wire xbar_awready;
        wire [31:0] xbar_wdata;
        wire [7:0] xbar_wstrb;
        wire xbar_wvalid;
        wire xbar_wready;
        wire [1:0] xbar_bresp;
        wire xbar_bvalid;
        wire xbar_bready;
        
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
            // Connect to Xbar
            .mem_araddr(xbar_araddr),
            .mem_arvalid(xbar_arvalid),
            .mem_arready(xbar_arready),
            .mem_rdata(xbar_rdata),
            .mem_rresp(xbar_rresp),
            .mem_rvalid(xbar_rvalid),
            .mem_rready(xbar_rready),
            .mem_awaddr(xbar_awaddr),
            .mem_awvalid(xbar_awvalid),
            .mem_awready(xbar_awready),
            .mem_wdata(xbar_wdata),
            .mem_wstrb(xbar_wstrb),
            .mem_wvalid(xbar_wvalid),
            .mem_wready(xbar_wready),
            .mem_bresp(xbar_bresp),
            .mem_bvalid(xbar_bvalid),
            .mem_bready(xbar_bready)
        );

        // Instantiate the Xbar
        Xbar xbar(
            .clk(clk),
            .rst(rst),
            // Upstream interface (from Arbiter)
            .s_araddr(xbar_araddr),
            .s_arvalid(xbar_arvalid),
            .s_arready(xbar_arready),
            .s_rdata(xbar_rdata),
            .s_rresp(xbar_rresp),
            .s_rvalid(xbar_rvalid),
            .s_rready(xbar_rready),
            .s_awaddr(xbar_awaddr),
            .s_awvalid(xbar_awvalid),
            .s_awready(xbar_awready),
            .s_wdata(xbar_wdata),
            .s_wstrb(xbar_wstrb),
            .s_wvalid(xbar_wvalid),
            .s_wready(xbar_wready),
            .s_bresp(xbar_bresp),
            .s_bvalid(xbar_bvalid),
            .s_bready(xbar_bready),
            // External SoC interface
            .soc_araddr(soc_araddr),
            .soc_arvalid(soc_arvalid),
            .soc_arready(soc_arready),
            .soc_rdata(soc_rdata),
            .soc_rresp(soc_rresp),
            .soc_rvalid(soc_rvalid),
            .soc_rready(soc_rready),
            .soc_awaddr(soc_awaddr),
            .soc_awvalid(soc_awvalid),
            .soc_awready(soc_awready),
            .soc_wdata(soc_wdata),
            .soc_wstrb(soc_wstrb),
            .soc_wvalid(soc_wvalid),
            .soc_wready(soc_wready),
            .soc_bresp(soc_bresp),
            .soc_bvalid(soc_bvalid),
            .soc_bready(soc_bready),
            // CLINT interface
            .clint_araddr(clint_araddr),
            .clint_arvalid(clint_arvalid),
            .clint_arready(clint_arready),
            .clint_rdata(clint_rdata),
            .clint_rresp(clint_rresp),
            .clint_rvalid(clint_rvalid),
            .clint_rready(clint_rready),
            .clint_awaddr(clint_awaddr),
            .clint_awvalid(clint_awvalid),
            .clint_awready(clint_awready),
            .clint_wdata(clint_wdata),
            .clint_wstrb(clint_wstrb),
            .clint_wvalid(clint_wvalid),
            .clint_wready(clint_wready),
            .clint_bresp(clint_bresp),
            .clint_bvalid(clint_bvalid),
            .clint_bready(clint_bready)
        );

        // CLINT instance
        Clint clint(
            .clk(clk),
            .rst(rst),
            .araddr(clint_araddr),
            .arvalid(clint_arvalid),
            .arready(clint_arready),
            .rdata(clint_rdata),
            .rresp(clint_rresp),
            .rvalid(clint_rvalid),
            .rready(clint_rready),
            .awaddr(clint_awaddr),
            .awvalid(clint_awvalid),
            .awready(clint_awready),
            .wdata(clint_wdata),
            .wstrb(clint_wstrb),
            .wvalid(clint_wvalid),
            .wready(clint_wready),
            .bresp(clint_bresp),
            .bvalid(clint_bvalid),
            .bready(clint_bready)
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
