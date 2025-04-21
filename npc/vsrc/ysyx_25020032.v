`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();
import "DPI-C" function void difftest_skip_ref();

module ysyx_25020032 (
        input clock,
        input reset,
        input io_interrupt,

        // Master AXI interface
        output [31:0] io_master_araddr,
        output io_master_arvalid,
        input io_master_arready,
        input [31:0] io_master_rdata,
        input [1:0] io_master_rresp,
        input io_master_rvalid,
        output io_master_rready,
        output [31:0] io_master_awaddr,
        output io_master_awvalid,
        input io_master_awready,
        output [31:0] io_master_wdata,
        output [3:0] io_master_wstrb,
        output io_master_wvalid,
        input io_master_wready,
        input [1:0] io_master_bresp,
        input io_master_bvalid,
        output io_master_bready,
        output [3:0] io_master_arid,
        output [7:0] io_master_arlen,   
        output [2:0] io_master_arsize,
        output [1:0] io_master_arburst,
        input [3:0] io_master_rid,
        input io_master_rlast,
        output [3:0] io_master_awid,
        output [7:0] io_master_awlen,
        output [2:0] io_master_awsize,
        output [1:0] io_master_awburst,
        output io_master_wlast,
        input [3:0] io_master_bid,

        // Slave AXI interface
        input [31:0] io_slave_araddr,
        input io_slave_arvalid,
        output io_slave_arready,
        output [31:0] io_slave_rdata,
        output [1:0] io_slave_rresp,
        output io_slave_rvalid,
        input io_slave_rready,
        input [31:0] io_slave_awaddr,
        input io_slave_awvalid,
        output io_slave_awready,
        input [31:0] io_slave_wdata,
        input [3:0] io_slave_wstrb,
        input io_slave_wvalid,
        output io_slave_wready,
        output [1:0] io_slave_bresp,
        output io_slave_bvalid,
        input io_slave_bready,
        input [3:0] io_slave_arid,
        input [7:0] io_slave_arlen,
        input [2:0] io_slave_arsize,
        input [1:0] io_slave_arburst,
        output [3:0] io_slave_rid,
        output io_slave_rlast,
        input [3:0] io_slave_awid,
        input [7:0] io_slave_awlen,
        input [2:0] io_slave_awsize,
        input [1:0] io_slave_awburst,
        input io_slave_wlast,
        output [3:0] io_slave_bid
);

`ifndef SYNTHESIS
    // Alarm simulation environment to stop for ebreak instruction
    always @(*) begin
        if(instr == 32'h00100073) begin
                // Performance Counter
                `ifdef FETCH_EVENT
                    $display("Fetch event count: %d", ifu.fetch_event_cnt);
                `endif
                `ifdef DECODE_EVENT
                    $display("Compute instruction count: %d", idu.compute_instr_cnt);
                    $display("Memory instruction count: %d", idu.memory_instr_cnt);
                    $display("Load instruction count: %d", idu.load_instr_cnt);
                    $display("Store instruction count: %d", idu.store_instr_cnt);
                    $display("CSR instruction count: %d", idu.csr_instr_cnt);
                    $display("Branch instruction count: %d", idu.branch_instr_cnt);
                `endif  
                `ifdef MEMORY_EVENT
                    $display("Memory Extra cycle count: %d", wbu.extra_cnt);
                    $display("Wait cycle count: %d", wbu.extra_cnt - wbu.finish_cnt);
                    $display("Access success cycle count: %d", wbu.finish_cnt);
                    $display("Average memory access time: %d", (wbu.extra_cnt / wbu.finish_cnt));
                `endif
                `ifdef CACHE_EVENT
                    $display("Cache miss count: %d", icache.miss_cnt);
                    $display("Cache wait cycle count: %d", icache.wait_cnt);
                `endif
                set_finish();
        end
    end
`endif

    wire ifu_ready;
    wire ifu_valid;
    wire idu_ready;
    wire idu_valid;
    wire exu_ready;
    wire exu_valid;
    wire wbu_ready;
    wire wbu_valid;
    wire icache_valid;
    wire icache_ready;

    wire [31:0] icache_instr;

    ysyx_25020032_Icache icache(
        .clk(clock),
        .rst(reset),

        .pc(pc),
        .instr(icache_instr),
        .icache_valid(icache_valid),
        .icache_ready(icache_ready),

        // AXI interface
        .arid(ifu_arid), .arlen(ifu_arlen), .arburst(ifu_arburst), 
        .arsize(ifu_arsize), .araddr(ifu_araddr), .arvalid(ifu_arvalid), .arready(ifu_arready),

        .rid(ifu_rid), .rlast(ifu_rlast),
        .rvalid(ifu_rvalid), .rready(ifu_rready), .rdata(ifu_rdata), .rresp(ifu_rresp)
    );

    wire [31:0]pc;
    wire [31:0]instr;
    
    ysyx_25020032_IFU ifu(
            .clk(clock), .rst(reset), 

            .ifu_valid(ifu_valid), .idu_ready(idu_ready),
            .pc(pc), .instr(instr),

            .wbu_valid(wbu_valid), .ifu_ready(ifu_ready),
            .branch_taken(branch_taken), .branch_target(branch_target),

            .icache_valid(icache_valid), .icache_ready(icache_ready),
            .icache_instr(icache_instr)
    );
    
    // Control signal
    AluCtrl alu_ctrl;
    wire [1:0]alu_srca;
    wire [1:0]alu_srcb;
    Branch branch_type;
    wire [2:0]mem_width;
    wire mem_wen;
    wire valid;
    wire [1:0]wb_sel;
    wire csr_write_set;

    // Operand 
    wire [31:0]ext_imm;
    wire [31:0]data_reg1, data_reg2;
    // Csr 
    wire [31:0]csr_out;
    wire [31:0]mepc;
    wire [31:0]mtvec;
    // if-id pipeline register
    wire [31:0]if_id_pc;

    ysyx_25020032_IDU idu (
            .clk(clock), .rst(reset), 

            .instr(instr), .pc(pc),
            .ifu_valid(ifu_valid), .idu_ready(idu_ready),

            .idu_valid(idu_valid),  .exu_ready(exu_ready), 
            .if_id_pc(if_id_pc),
            .alu_ctrl(alu_ctrl), .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .branch_type(branch_type), .wb_sel(wb_sel), 
            .mem_wen(mem_wen), .valid(valid), .mem_width(mem_width),
            .ext_imm(ext_imm), .data_reg1(data_reg1), .data_reg2(data_reg2), 
            .csr_out(csr_out), .mepc(mepc), .mtvec(mtvec), .csr_write_set(csr_write_set),

            .wbu_valid(wbu_valid), .wdata_regd(wdata_regd), .csr_in(csr_in)
    );

    wire [31:0]alu_res;
    wire [31:0]raddr;
    wire [31:0]wdata;
    wire [3:0] wmask;

    wire [3:0] id_ex_branch_type;
    wire [2:0] id_ex_mem_width;
    wire       id_ex_mem_wen;
    wire       id_ex_valid;
    wire [1:0] id_ex_wb_sel;
    wire       id_ex_csr_write_set;

    wire [31:0] id_ex_ext_imm;
    wire [31:0] id_ex_data_reg1;
    wire [31:0] id_ex_csr_out;
    wire [31:0] id_ex_mepc;
    wire [31:0] id_ex_mtvec;
    wire [31:0] id_ex_pc;

    ysyx_25020032_EXU exu(  
            .clk(clock), .rst(reset),

            .idu_valid(idu_valid), .exu_ready(exu_ready), 

            .alu_ctrl(alu_ctrl), .branch_type(branch_type), .mem_width(mem_width),
            .valid(valid), .mem_wen(mem_wen), .csr_write_set(csr_write_set), .wb_sel(wb_sel),

            .alu_srca(alu_srca), .alu_srcb(alu_srcb), 
            .data_reg1(data_reg1), .data_reg2(data_reg2), .csr_out(csr_out),
            .pc(if_id_pc), .ext_imm(ext_imm), 
            .mepc(mepc), .mtvec(mtvec),

            .exu_valid(exu_valid), .wbu_ready(wbu_ready), 

            .alu_res(alu_res), .raddr(raddr), .wdata(wdata), .wmask(wmask),

            .id_ex_pc(id_ex_pc), .id_ex_data_reg1(id_ex_data_reg1), .id_ex_ext_imm(id_ex_ext_imm), .id_ex_mtvec(id_ex_mtvec), .id_ex_mepc(id_ex_mepc),

            .id_ex_valid(id_ex_valid), .id_ex_mem_wen(id_ex_mem_wen), .id_ex_mem_width(id_ex_mem_width), .id_ex_wb_sel(id_ex_wb_sel), .id_ex_csr_write_set(id_ex_csr_write_set), .id_ex_branch_type(id_ex_branch_type), .id_ex_csr_out(id_ex_csr_out)
    );

    // Writeback result
    wire [31:0]csr_in, wdata_regd;

    wire access_fault;
    wire branch_taken;
    wire [31:0]branch_target;
    ysyx_25020032_WBU wbu(
        .clk(clock), .rst(reset),

        .exu_valid(exu_valid), .wbu_ready(wbu_ready),

        .valid(id_ex_valid), .mem_wen(id_ex_mem_wen), 
        .wb_sel(id_ex_wb_sel), .csr_write_set(id_ex_csr_write_set), .mem_width(id_ex_mem_width), .branch_type(id_ex_branch_type),
        .csr_out(id_ex_csr_out), .pc(id_ex_pc), 
        .data_reg1(id_ex_data_reg1), .ext_imm(id_ex_ext_imm), .mtvec(id_ex_mtvec), .mepc(id_ex_mepc),
        .raddr(raddr), .wrdata(wdata), .wmask(wmask), .alu_res(alu_res), 

        .wbu_valid(wbu_valid), .idu_ready(idu_ready),

        .wdata_regd(wdata_regd), .csr_in(csr_in), .access_fault(access_fault), 
        .branch_taken(branch_taken), .branch_target(branch_target),

        // AXI interface
        .arid(wbu_arid), .arburst(wbu_arburst), .arlen(wbu_arlen),
        .araddr(wbu_araddr), .arsize(wbu_arsize), .arvalid(wbu_arvalid), .arready(wbu_arready),

        .rid(wbu_rid), .rlast(wbu_rlast),
        .rdata(wbu_rdata), .rresp(wbu_rresp), .rvalid(wbu_rvalid), .rready(wbu_rready),

        .awid(wbu_awid), .awlen(wbu_awlen), .awburst(wbu_awburst),
        .awaddr(wbu_awaddr), .awsize(wbu_awsize), .awvalid(wbu_awvalid), .awready(wbu_awready),

        .wdata(wbu_wdata), .wstrb(wbu_wstrb), .wvalid(wbu_wvalid), .wready(wbu_wready),
        .wlast(wbu_wlast),
        
        .bid(wbu_bid),
        .bresp(wbu_bresp), .bvalid(wbu_bvalid), .bready(wbu_bready)
    );

    // Instantiate the arbiter
    ysyx_25020032_Arbiter arbiter(
        .clk(clock),
        .rst(reset),
        // IFU interface
        .ifu_arid(ifu_arid),
        .ifu_araddr(ifu_araddr),
        .ifu_arlen(ifu_arlen),
        .ifu_arsize(ifu_arsize),
        .ifu_arburst(ifu_arburst),
        .ifu_arvalid(ifu_arvalid),
        .ifu_arready(ifu_arready),
        .ifu_rid(ifu_rid),
        .ifu_rdata(ifu_rdata),
        .ifu_rresp(ifu_rresp),
        .ifu_rlast(ifu_rlast),
        .ifu_rvalid(ifu_rvalid),
        .ifu_rready(ifu_rready),
        // WBU interface
        .wbu_arid(wbu_arid),
        .wbu_araddr(wbu_araddr),
        .wbu_arlen(wbu_arlen),
        .wbu_arsize(wbu_arsize),
        .wbu_arburst(wbu_arburst),
        .wbu_arvalid(wbu_arvalid),
        .wbu_arready(wbu_arready),
        .wbu_awid(wbu_awid),
        .wbu_awaddr(wbu_awaddr),
        .wbu_awlen(wbu_awlen),
        .wbu_awsize(wbu_awsize),
        .wbu_awburst(wbu_awburst),
        .wbu_awvalid(wbu_awvalid),
        .wbu_awready(wbu_awready),
        .wbu_wdata(wbu_wdata),
        .wbu_wstrb(wbu_wstrb),
        .wbu_wlast(wbu_wlast),
        .wbu_wvalid(wbu_wvalid),
        .wbu_wready(wbu_wready),
        .wbu_bid(wbu_bid),
        .wbu_bresp(wbu_bresp),
        .wbu_bvalid(wbu_bvalid),
        .wbu_bready(wbu_bready),
        .wbu_rid(wbu_rid),
        .wbu_rdata(wbu_rdata),
        .wbu_rresp(wbu_rresp),
        .wbu_rlast(wbu_rlast),
        .wbu_rvalid(wbu_rvalid),
        .wbu_rready(wbu_rready),
        // Xbar interface
        .xbar_arid(xbar_arid),
        .xbar_araddr(xbar_araddr),
        .xbar_arlen(xbar_arlen),
        .xbar_arsize(xbar_arsize),
        .xbar_arburst(xbar_arburst),
        .xbar_arvalid(xbar_arvalid),
        .xbar_arready(xbar_arready),
        .xbar_rid(xbar_rid),
        .xbar_rdata(xbar_rdata),
        .xbar_rresp(xbar_rresp),
        .xbar_rlast(xbar_rlast),
        .xbar_rvalid(xbar_rvalid),
        .xbar_rready(xbar_rready),
        .xbar_awid(xbar_awid),
        .xbar_awaddr(xbar_awaddr),
        .xbar_awlen(xbar_awlen),
        .xbar_awsize(xbar_awsize),
        .xbar_awburst(xbar_awburst),
        .xbar_awvalid(xbar_awvalid),
        .xbar_awready(xbar_awready),
        .xbar_wdata(xbar_wdata),
        .xbar_wstrb(xbar_wstrb),
        .xbar_wlast(xbar_wlast),
        .xbar_wvalid(xbar_wvalid),
        .xbar_wready(xbar_wready),
        .xbar_bid(xbar_bid),
        .xbar_bresp(xbar_bresp),
        .xbar_bvalid(xbar_bvalid),
        .xbar_bready(xbar_bready)
    );

    // Instantiate the Xbar
    ysyx_25020032_Xbar xbar(
        .clk(clock),
        .rst(reset),
        // Upstream interface (from Arbiter)
        .s_arid(xbar_arid),
        .s_araddr(xbar_araddr),
        .s_arlen(xbar_arlen),
        .s_arsize(xbar_arsize),
        .s_arburst(xbar_arburst),
        .s_arvalid(xbar_arvalid),
        .s_arready(xbar_arready),
        .s_rid(xbar_rid),
        .s_rdata(xbar_rdata),
        .s_rresp(xbar_rresp),
        .s_rlast(xbar_rlast),
        .s_rvalid(xbar_rvalid),
        .s_rready(xbar_rready),
        .s_awid(xbar_awid),
        .s_awaddr(xbar_awaddr),
        .s_awlen(xbar_awlen),
        .s_awsize(xbar_awsize),
        .s_awburst(xbar_awburst),
        .s_awvalid(xbar_awvalid),
        .s_awready(xbar_awready),
        .s_wdata(xbar_wdata),
        .s_wstrb(xbar_wstrb),
        .s_wlast(xbar_wlast),
        .s_wvalid(xbar_wvalid),
        .s_wready(xbar_wready),
        .s_bid(xbar_bid),
        .s_bresp(xbar_bresp),
        .s_bvalid(xbar_bvalid),
        .s_bready(xbar_bready),
        // External SoC interface
        .soc_arid(io_master_arid),
        .soc_araddr(io_master_araddr),
        .soc_arlen(io_master_arlen),
        .soc_arsize(io_master_arsize),
        .soc_arburst(io_master_arburst),
        .soc_arvalid(io_master_arvalid),
        .soc_arready(io_master_arready),
        .soc_rid(io_master_rid),
        .soc_rdata(io_master_rdata),
        .soc_rresp(io_master_rresp),
        .soc_rlast(io_master_rlast),
        .soc_rvalid(io_master_rvalid),
        .soc_rready(io_master_rready),
        .soc_awid(io_master_awid),
        .soc_awaddr(io_master_awaddr),
        .soc_awlen(io_master_awlen),
        .soc_awsize(io_master_awsize),
        .soc_awburst(io_master_awburst),
        .soc_awvalid(io_master_awvalid),
        .soc_awready(io_master_awready),
        .soc_wdata(io_master_wdata),
        .soc_wstrb(io_master_wstrb),
        .soc_wlast(io_master_wlast),
        .soc_wvalid(io_master_wvalid),
        .soc_wready(io_master_wready),
        .soc_bid(io_master_bid),
        .soc_bresp(io_master_bresp),
        .soc_bvalid(io_master_bvalid),
        .soc_bready(io_master_bready),
        // CLINT interface
        .clint_arid(clint_arid),
        .clint_araddr(clint_araddr),
        .clint_arlen(clint_arlen),
        .clint_arsize(clint_arsize),
        .clint_arburst(clint_arburst),
        .clint_arvalid(clint_arvalid),
        .clint_arready(clint_arready),
        .clint_rid(clint_rid),
        .clint_rdata(clint_rdata),
        .clint_rresp(clint_rresp),
        .clint_rlast(clint_rlast),
        .clint_rvalid(clint_rvalid),
        .clint_rready(clint_rready),
        .clint_awid(clint_awid),
        .clint_awaddr(clint_awaddr),
        .clint_awlen(clint_awlen),
        .clint_awsize(clint_awsize),
        .clint_awburst(clint_awburst),
        .clint_awvalid(clint_awvalid),
        .clint_awready(clint_awready),
        .clint_wdata(clint_wdata),
        .clint_wstrb(clint_wstrb),
        .clint_wlast(clint_wlast),
        .clint_wvalid(clint_wvalid),
        .clint_wready(clint_wready),
        .clint_bid(clint_bid),
        .clint_bresp(clint_bresp),
        .clint_bvalid(clint_bvalid),
        .clint_bready(clint_bready)
    );

    // CLINT instance
    ysyx_25020032_Clint clint(
        .clk(clock),
        .rst(reset),
        // Read address channel
        .arid(clint_arid),
        .araddr(clint_araddr),
        .arlen(clint_arlen),
        .arsize(clint_arsize),
        .arburst(clint_arburst),
        .arvalid(clint_arvalid),
        .arready(clint_arready),
        // Read data channel
        .rid(clint_rid),
        .rdata(clint_rdata),
        .rresp(clint_rresp),
        .rlast(clint_rlast),
        .rvalid(clint_rvalid),
        .rready(clint_rready),
        // Write address channel
        .awid(clint_awid),
        .awaddr(clint_awaddr),
        .awlen(clint_awlen),
        .awsize(clint_awsize),
        .awburst(clint_awburst),
        .awvalid(clint_awvalid),
        .awready(clint_awready),
        // Write data channel
        .wdata(clint_wdata),
        .wstrb(clint_wstrb),
        .wlast(clint_wlast),
        .wvalid(clint_wvalid),
        .wready(clint_wready),
        // Write response channel
        .bid(clint_bid),
        .bresp(clint_bresp),
        .bvalid(clint_bvalid),
        .bready(clint_bready)
    );

    // IFU AXI signals
    wire [31:0] ifu_araddr;
    wire ifu_arvalid;
    wire ifu_arready;
    wire [31:0] ifu_rdata;
    wire [1:0] ifu_rresp;
    wire ifu_rvalid;
    wire ifu_rready;
    wire [3:0] ifu_arid;
    wire [7:0] ifu_arlen;
    wire [2:0] ifu_arsize;
    wire [1:0] ifu_arburst;
    wire [3:0] ifu_rid;
    wire ifu_rlast;

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
    wire [3:0] wbu_wstrb;
    wire wbu_wvalid;
    wire wbu_wready;
    wire wbu_bvalid;
    wire [1:0] wbu_bresp;
    wire wbu_bready;
    wire [3:0] wbu_arid;
    wire [7:0] wbu_arlen;
    wire [2:0] wbu_arsize;
    wire [1:0] wbu_arburst;
    wire [3:0] wbu_awid;
    wire [7:0] wbu_awlen;
    wire [2:0] wbu_awsize;
    wire [1:0] wbu_awburst;
    wire [3:0] wbu_bid;
    wire [3:0] wbu_rid;
    wire wbu_rlast;
    wire wbu_wlast;

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
    wire [3:0] clint_arid;
    wire [7:0] clint_arlen;
    wire [2:0] clint_arsize;
    wire [1:0] clint_arburst;
    wire [3:0] clint_rid;
    wire clint_rlast;
    wire [3:0] clint_awid;
    wire [7:0] clint_awlen;
    wire [2:0] clint_awsize;
    wire [1:0] clint_awburst;
    wire clint_wlast;
    wire [3:0] clint_bid;

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
    wire [3:0] xbar_wstrb;
    wire xbar_wvalid;
    wire xbar_wready;
    wire [1:0] xbar_bresp;
    wire xbar_bvalid;
    wire xbar_bready;
    wire [3:0] xbar_arid;
    wire [7:0] xbar_arlen;
    wire [2:0] xbar_arsize;
    wire [1:0] xbar_arburst;
    wire [3:0] xbar_awid;
    wire [7:0] xbar_awlen;
    wire [2:0] xbar_awsize;
    wire [1:0] xbar_awburst;
    wire [3:0] xbar_rid;
    wire xbar_rlast;
    wire [3:0] xbar_bid;
    wire xbar_wlast;

    // Set all slave interface outputs to zero since core won't be a slave
    assign io_slave_arready = 1'b0;
    assign io_slave_rdata = 32'b0;
    assign io_slave_rresp = 2'b0;
    assign io_slave_rvalid = 1'b0;
    assign io_slave_rid = 4'b0;
    assign io_slave_rlast = 1'b0;
    assign io_slave_awready = 1'b0;
    assign io_slave_wready = 1'b0;
    assign io_slave_bresp = 2'b0;
    assign io_slave_bvalid = 1'b0;
    assign io_slave_bid = 4'b0;

`ifndef SYNTHESIS
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
`endif
endmodule
/* verilator lint_on UNUSEDSIGNAL */
