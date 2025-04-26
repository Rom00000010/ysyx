/* verilator lint_off UNUSEDSIGNAL */
`include "axi_interface.vh"

module ysyx_25020032_Xbar (
        input clk,
        input rst,

        // Upstream (master) interface
        input [3:0] s_arid,
        input [31:0] s_araddr,
        input [7:0] s_arlen,
        input [2:0] s_arsize,
        input [1:0] s_arburst,
        input s_arvalid,
        output reg s_arready,
        output reg [3:0] s_rid,
        output reg [31:0] s_rdata,
        output reg [1:0] s_rresp,
        output reg s_rlast,
        output reg s_rvalid,
        input s_rready,
        input [3:0] s_awid,
        input [31:0] s_awaddr,
        input [7:0] s_awlen,
        input [2:0] s_awsize,
        input [1:0] s_awburst,
        input s_awvalid,
        output reg s_awready,
        input [31:0] s_wdata,
        input [3:0] s_wstrb,
        input s_wlast,
        input s_wvalid,
        output reg s_wready,
        output reg [3:0] s_bid,
        output reg [1:0] s_bresp,
        output reg s_bvalid,
        input s_bready,

        // External SoC interface
        output reg [3:0] soc_arid,
        output reg [31:0] soc_araddr,
        output reg [7:0] soc_arlen,
        output reg [2:0] soc_arsize,
        output reg [1:0] soc_arburst,
        output reg soc_arvalid,
        input soc_arready,
        input [3:0] soc_rid,
        input [31:0] soc_rdata,
        input [1:0] soc_rresp,
        input soc_rlast,
        input soc_rvalid,
        output reg soc_rready,
        output reg [3:0] soc_awid,
        output reg [31:0] soc_awaddr,
        output reg [7:0] soc_awlen,
        output reg [2:0] soc_awsize,
        output reg [1:0] soc_awburst,
        output reg soc_awvalid,
        input soc_awready,
        output reg [31:0] soc_wdata,
        output reg [3:0] soc_wstrb,
        output reg soc_wlast,
        output reg soc_wvalid,
        input soc_wready,
        input [3:0] soc_bid,
        input [1:0] soc_bresp,
        input soc_bvalid,
        output reg soc_bready,

        // CLINT interface
        output reg [3:0] clint_arid,
        output reg [31:0] clint_araddr,
        output reg [7:0] clint_arlen,
        output reg [2:0] clint_arsize,
        output reg [1:0] clint_arburst,
        output reg clint_arvalid,
        input clint_arready,
        input [3:0] clint_rid,
        input [31:0] clint_rdata,
        input [1:0] clint_rresp,
        input clint_rlast,
        input clint_rvalid,
        output reg clint_rready
    );

    // Address decoding - only based on address values
    wire is_clint_addr = (s_araddr >= 32'h02000000 && s_araddr <= 32'h0200ffff) || (s_awaddr >= 32'h02000000 && s_awaddr <= 32'h0200ffff);
    wire is_soc_addr = !is_clint_addr;  // All non-CLINT addresses go to SoC

    // Read channel routings
    always @(*) begin
        if (is_clint_addr) begin
            clint_araddr = s_araddr;
            clint_arid = s_arid;
            clint_arlen = s_arlen;
            clint_arsize = s_arsize;
            clint_arburst = s_arburst;
            clint_arvalid = s_arvalid;
            s_arready = clint_arready;
            s_rvalid = clint_rvalid;
            s_rdata = clint_rdata;
            s_rresp = clint_rresp;
            s_rid = clint_rid;
            s_rlast = clint_rlast;
            clint_rready = s_rready;

            soc_araddr = 32'h0;
            soc_arid = 4'h0;
            soc_arlen = 8'h0;
            soc_arsize = 3'h0;
            soc_arburst = 2'h0;
            soc_arvalid = 1'h0;
            soc_rready = 1'h0;
        end
        else begin
            soc_araddr = s_araddr;
            soc_arid = s_arid;
            soc_arlen = s_arlen;
            soc_arsize = s_arsize;
            soc_arburst = s_arburst;
            soc_arvalid = s_arvalid;
            s_arready = soc_arready;
            s_rvalid = soc_rvalid;
            s_rdata = soc_rdata;
            s_rresp = soc_rresp;
            s_rid = soc_rid;
            s_rlast = soc_rlast;
            soc_rready = s_rready;

            clint_araddr = 32'h0;
            clint_arid = 4'h0;
            clint_arlen = 8'h0;
            clint_arsize = 3'h0;
            clint_arburst = 2'h0;
            clint_arvalid = 1'h0;
            clint_rready = 1'h0;
        end
    end

    // Write channel routing
    always @(*) begin
        soc_awaddr = s_awaddr;
        soc_awid = s_awid;
        soc_awlen = s_awlen;
        soc_awsize = s_awsize;
        soc_awburst = s_awburst;
        soc_awvalid = s_awvalid;
        s_awready = soc_awready;
        soc_wdata = s_wdata;
        soc_wstrb = s_wstrb;
        soc_wlast = s_wlast;
        soc_wvalid = s_wvalid;
        s_wready = soc_wready;
        s_bvalid = soc_bvalid;
        s_bresp = soc_bresp;
        s_bid = soc_bid;
        soc_bready = s_bready;
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
