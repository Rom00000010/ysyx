`include "axi_interface.vh"

module ysyx_25020032_Arbiter(
    input clk,
    input rst,

    // ================ IFU (Instruction Fetch Unit) Channel - Master 0 ================
    // Read Address Channel
    input [3:0] ifu_arid,
    input [31:0] ifu_araddr,
    input [7:0] ifu_arlen,
    input [2:0] ifu_arsize,
    input [1:0] ifu_arburst,
    input ifu_arvalid,
    output reg ifu_arready,
    // Read Data Channel
    output reg [3:0] ifu_rid,
    output reg [31:0] ifu_rdata,
    output reg [1:0] ifu_rresp,
    output reg ifu_rlast,
    output reg ifu_rvalid,
    input ifu_rready,

    // ================ WBU (Write Back Unit) Channel - Master 1 ================
    // Read Address Channel
    input [3:0] wbu_arid,
    input [31:0] wbu_araddr,
    input [7:0] wbu_arlen,
    input [2:0] wbu_arsize,
    input [1:0] wbu_arburst,
    input wbu_arvalid,
    output reg wbu_arready,
    // Write Address Channel
    input [3:0] wbu_awid,
    input [31:0] wbu_awaddr,
    input [7:0] wbu_awlen,
    input [2:0] wbu_awsize,
    input [1:0] wbu_awburst,
    input wbu_awvalid,
    output reg wbu_awready,
    // Write Data Channel
    input [31:0] wbu_wdata,
    input [3:0] wbu_wstrb,
    input wbu_wlast,
    input wbu_wvalid,
    output reg wbu_wready,
    // Write Response Channel
    output reg [3:0] wbu_bid,
    output reg [1:0] wbu_bresp,
    output reg wbu_bvalid,
    input wbu_bready,
    // Read Data Channel
    output reg [3:0] wbu_rid,
    output reg [31:0] wbu_rdata,
    output reg [1:0] wbu_rresp,
    output reg wbu_rlast,
    output reg wbu_rvalid,
    input wbu_rready,

    // ================ Memory Interface (Xbar) - Slave ================
    // Read Address Channel
    output reg [3:0] xbar_arid,
    output reg [31:0] xbar_araddr,
    output reg [7:0] xbar_arlen,
    output reg [2:0] xbar_arsize,
    output reg [1:0] xbar_arburst,
    output reg xbar_arvalid,
    input xbar_arready,
    // Read Data Channel
    input [3:0] xbar_rid,
    input [31:0] xbar_rdata,
    input [1:0] xbar_rresp,
    input xbar_rlast,
    input xbar_rvalid,
    output reg xbar_rready,
    // Write Address Channel
    output reg [3:0] xbar_awid,
    output reg [31:0] xbar_awaddr,
    output reg [7:0] xbar_awlen,
    output reg [2:0] xbar_awsize,
    output reg [1:0] xbar_awburst,
    output reg xbar_awvalid,
    input xbar_awready,
    // Write Data Channel
    output reg [31:0] xbar_wdata,
    output reg [3:0] xbar_wstrb,
    output reg xbar_wlast,
    output reg xbar_wvalid,
    input xbar_wready,
    // Write Response Channel
    input [3:0] xbar_bid,
    input [1:0] xbar_bresp,
    input xbar_bvalid,
    output reg xbar_bready
);

    // State encoding
    // TODO: MAYBE NEED MORE STATES(SUCH AS WAITING FOR ADDR HANDSHAKE)
    localparam IDLE = 2'd0;
    localparam IFU_READ = 2'd1;
    localparam WBU_READ = 2'd2;
    localparam WBU_WRITE = 2'd3;

    reg [1:0] state, next_state;
    reg last_grant_ifu; // For round-robin arbitration

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            last_grant_ifu <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE) begin
                if (next_state == IFU_READ)
                    last_grant_ifu <= 1;
                else if (next_state == WBU_READ || next_state == WBU_WRITE)
                    last_grant_ifu <= 0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ifu_arvalid && xbar_arready && wbu_awvalid && wbu_wvalid && xbar_awready && xbar_wready) begin
                    // Both requesting - use round robin
                    next_state = last_grant_ifu ? WBU_WRITE : IFU_READ;
                end
                else if (ifu_arvalid && xbar_arready && wbu_arvalid && xbar_arready) begin
                    // Both want to read - use round robin
                    next_state = last_grant_ifu ? WBU_READ : IFU_READ;
                end
                else if (ifu_arvalid && xbar_arready)
                    next_state = IFU_READ;
                else if (wbu_awvalid && wbu_wvalid && xbar_awready && xbar_wready)
                    next_state = WBU_WRITE;
                else if (wbu_arvalid && xbar_arready)
                    next_state = WBU_READ;
            end
            IFU_READ: begin
                if (xbar_rvalid && ifu_rready)
                    next_state = IDLE;
            end
            WBU_READ: begin
                if (xbar_rvalid && wbu_rready)
                    next_state = IDLE;
            end
            WBU_WRITE: begin
                if (xbar_bvalid && wbu_bready)
                    next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        // Default values
        ifu_arready = 0;
        ifu_rvalid = 0;
        ifu_rdata = 0;
        ifu_rresp = 0;
        ifu_rid = 0;
        ifu_rlast = 0;
        
        wbu_arready = 0;
        wbu_awready = 0;
        wbu_wready = 0;
        wbu_bvalid = 0;
        wbu_bresp = 0;
        wbu_bid = 0;
        wbu_rvalid = 0;
        wbu_rdata = 0;
        wbu_rresp = 0;
        wbu_rid = 0;
        wbu_rlast = 0;

        xbar_arvalid = 0;
        xbar_araddr = 0;
        xbar_arid = 0;
        xbar_arlen = 0;
        xbar_arsize = 0;
        xbar_arburst = 0;
        xbar_rready = 0;
        xbar_awvalid = 0;
        xbar_awaddr = 0;
        xbar_awid = 0;
        xbar_awlen = 0;
        xbar_awsize = 0;
        xbar_awburst = 0;
        xbar_wvalid = 0;
        xbar_wdata = 0;
        xbar_wstrb = 0;
        xbar_wlast = 0;
        xbar_bready = 0;

        case (state)
            IDLE: begin
                ifu_arready = xbar_arready;
                wbu_arready = xbar_arready;
                wbu_awready = xbar_awready;
                wbu_wready = xbar_wready;

                // TODO: HANDLE SIMULTANEOUSLY ACCESS CASE
                if(ifu_arvalid) begin
                    xbar_arvalid = 1;
                    xbar_araddr = ifu_araddr;
                    xbar_arid = ifu_arid;
                    xbar_arlen = ifu_arlen;
                    xbar_arsize = ifu_arsize;
                    xbar_arburst = ifu_arburst;
                end
                else if(wbu_awvalid && wbu_wvalid) begin
                    xbar_awvalid = 1;
                    xbar_awaddr = wbu_awaddr;
                    xbar_awid = wbu_awid;
                    xbar_awlen = wbu_awlen;
                    xbar_awsize = wbu_awsize;
                    xbar_awburst = wbu_awburst;
                    xbar_wvalid = 1;
                    xbar_wdata = wbu_wdata;
                    xbar_wstrb = wbu_wstrb;
                    xbar_wlast = wbu_wlast;
                end
                else if(wbu_arvalid) begin
                    xbar_arvalid = 1;
                    xbar_araddr = wbu_araddr;
                    xbar_arid = wbu_arid;
                    xbar_arlen = wbu_arlen;
                    xbar_arsize = wbu_arsize;
                    xbar_arburst = wbu_arburst;
                end
            end
            IFU_READ: begin
                xbar_araddr = ifu_araddr;
                xbar_rready = ifu_rready;
                ifu_rvalid = xbar_rvalid;
                ifu_rdata = xbar_rdata;
                ifu_rresp = xbar_rresp;
                ifu_rid = xbar_rid;
                ifu_rlast = xbar_rlast;
            end
            WBU_READ: begin
                xbar_araddr = wbu_araddr;
                xbar_rready = wbu_rready;
                wbu_rvalid = xbar_rvalid;
                wbu_rdata = xbar_rdata;
                wbu_rresp = xbar_rresp;
                wbu_rid = xbar_rid;
                wbu_rlast = xbar_rlast;
            end
            WBU_WRITE: begin
                xbar_awaddr = wbu_awaddr;
                xbar_bready = wbu_bready;
                wbu_bvalid = xbar_bvalid;
                wbu_bresp = xbar_bresp;
                wbu_bid = xbar_bid;
            end

            default: begin
            end
        endcase
    end

endmodule 
