/* verilator lint_off UNUSEDSIGNAL */
module Xbar (
        input clk,
        input rst,

        // Upstream (master) interface
        input [31:0] s_araddr,
        input s_arvalid,
        output reg s_arready,
        output reg [31:0] s_rdata,
        output reg [1:0] s_rresp,
        output reg s_rvalid,
        input s_rready,
        input [31:0] s_awaddr,
        input s_awvalid,
        output reg s_awready,
        input [31:0] s_wdata,
        input [7:0] s_wstrb,
        input s_wvalid,
        output reg s_wready,
        output reg [1:0] s_bresp,
        output reg s_bvalid,
        input s_bready,

        // SRAM interface
        output reg [31:0] sram_araddr,
        output reg sram_arvalid,
        input sram_arready,
        input [31:0] sram_rdata,
        input [1:0] sram_rresp,
        input sram_rvalid,
        output reg sram_rready,
        output reg [31:0] sram_awaddr,
        output reg sram_awvalid,
        input sram_awready,
        output reg [31:0] sram_wdata,
        output reg [7:0] sram_wstrb,
        output reg sram_wvalid,
        input sram_wready,
        input [1:0] sram_bresp,
        input sram_bvalid,
        output reg sram_bready,

        // UART interface
        output reg [31:0] uart_araddr,
        output reg uart_arvalid,
        input uart_arready,
        input [31:0] uart_rdata,
        input [1:0] uart_rresp,
        input uart_rvalid,
        output reg uart_rready,
        output reg [31:0] uart_awaddr,
        output reg uart_awvalid,
        input uart_awready,
        output reg [31:0] uart_wdata,
        output reg [7:0] uart_wstrb,
        output reg uart_wvalid,
        input uart_wready,
        input [1:0] uart_bresp,
        input uart_bvalid,
        output reg uart_bready,

        // CLINT interface
        output reg [31:0] clint_araddr,
        output reg clint_arvalid,
        input clint_arready,
        input [31:0] clint_rdata,
        input [1:0] clint_rresp,
        input clint_rvalid,
        output reg clint_rready,
        output reg [31:0] clint_awaddr,
        output reg clint_awvalid,
        input clint_awready,
        output reg [31:0] clint_wdata,
        output reg [3:0] clint_wstrb,
        output reg clint_wvalid,
        input clint_wready,
        input [1:0] clint_bresp,
        input clint_bvalid,
        output reg clint_bready
    );

    // Address decoding - only based on address values
    wire is_uart_addr = (s_araddr == 32'ha00003f8) || (s_awaddr == 32'ha00003f8);
    wire is_sram_addr = (s_araddr >= 32'h80000000) || (s_awaddr >= 32'h80000000);
    wire is_clint_addr = (s_araddr >= 32'ha0000048 && s_araddr <= 32'ha000004c) || (s_awaddr >= 32'ha0000048 && s_awaddr <= 32'ha000004c);

    // Read channel routing
    always @(*) begin
        sram_arvalid = 0;
        uart_arvalid = 0;
        clint_arvalid = 0;
        sram_araddr = 0;
        uart_araddr = 0;
        clint_araddr = 0;
        s_arready = 0;
        s_rvalid = 0;
        s_rdata = 0;
        s_rresp = 0;
        sram_rready = 0;
        uart_rready = 0;
        clint_rready = 0;

        if (is_uart_addr) begin
            uart_araddr = s_araddr;
            uart_arvalid = s_arvalid;
            s_arready = uart_arready;
            s_rvalid = uart_rvalid;
            s_rdata = uart_rdata;
            s_rresp = uart_rresp;
            uart_rready = s_rready;
        end
        else if (is_sram_addr) begin
            sram_araddr = s_araddr;
            sram_arvalid = s_arvalid;
            s_arready = sram_arready;
            s_rvalid = sram_rvalid;
            s_rdata = sram_rdata;
            s_rresp = sram_rresp;
            sram_rready = s_rready;
        end
        else if (is_clint_addr) begin
            clint_araddr = s_araddr;
            clint_arvalid = s_arvalid;
            s_arready = clint_arready;
            s_rvalid = clint_rvalid;
            s_rdata = clint_rdata;
            s_rresp = clint_rresp;
            clint_rready = s_rready;
        end else if (s_arvalid) begin
            // Invalid address
            s_arready = 1'b1;
            s_rvalid = 1'b1;
            s_rresp = 2'b11;  // DECERR
        end
    end

    // Write channel routing
    always @(*) begin
        sram_awvalid = 0;
        uart_awvalid = 0;
        clint_awvalid = 0;
        uart_awaddr = 0;
        sram_awaddr = 0;
        clint_awaddr = 0;
        s_awready = 0;
        sram_wvalid = 0;
        uart_wvalid = 0;
        clint_wvalid = 0;
        s_wready = 0;
        s_bvalid = 0;
        s_bresp = 0;
        sram_bready = 0;
        uart_bready = 0;
        clint_bready = 0;
        sram_wdata = 0;
        uart_wdata = 0;
        clint_wdata = 0;
        sram_wstrb = 0;
        uart_wstrb = 0;
        clint_wstrb = 0;

        if (is_uart_addr) begin
            uart_awaddr = s_awaddr;
            uart_awvalid = s_awvalid;
            s_awready = uart_awready;
            uart_wdata = s_wdata;
            uart_wstrb = s_wstrb;
            uart_wvalid = s_wvalid;
            s_wready = uart_wready;
            s_bvalid = uart_bvalid;
            s_bresp = uart_bresp;
            uart_bready = s_bready;
        end
        else if (is_sram_addr) begin
            sram_awaddr = s_awaddr;
            sram_awvalid = s_awvalid;
            s_awready = sram_awready;
            sram_wdata = s_wdata;
            sram_wstrb = s_wstrb;
            sram_wvalid = s_wvalid;
            s_wready = sram_wready;
            s_bvalid = sram_bvalid;
            s_bresp = sram_bresp;
            sram_bready = s_bready;
        end
        else if (is_clint_addr) begin
            clint_awaddr = s_awaddr;
            clint_awvalid = s_awvalid;
            s_awready = clint_awready;
            clint_wdata = s_wdata;
            clint_wstrb = s_wstrb[3:0];  // CLINT only uses lower 4 bits
            clint_wvalid = s_wvalid;
            s_wready = clint_wready;
            s_bvalid = clint_bvalid;
            s_bresp = clint_bresp;
            clint_bready = s_bready;
        end else if (s_awvalid || s_wvalid) begin
            // Invalid address
            s_awready = 1'b1;
            s_wready = 1'b1;
            s_bvalid = 1'b1;
            s_bresp = 2'b11;  // DECERR
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */
