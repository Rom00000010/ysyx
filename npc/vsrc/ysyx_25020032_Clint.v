/* verilator lint_off UNUSEDSIGNAL */
`include "axi_interface.vh"

module ysyx_25020032_Clint (
    input clk,
    input rst,

    // AXI slave interface
    // Read address channel
    input [3:0] arid,
    input [31:0] araddr,
    input [7:0] arlen,
    input [2:0] arsize,
    input [1:0] arburst,
    input arvalid,
    output reg arready,
    // Read data channel
    output reg [3:0] rid,
    output reg [31:0] rdata,
    output reg [1:0] rresp,
    output reg rlast,
    output reg rvalid,
    input rready,
    // Write address channel
    input [3:0] awid,
    input [31:0] awaddr,
    input [7:0] awlen,
    input [2:0] awsize,
    input [1:0] awburst,
    input awvalid,
    output reg awready,
    // Write data channel
    input [31:0] wdata,
    input [3:0] wstrb,
    input wlast,
    input wvalid,
    output reg wready,
    // Write response channel
    output reg [3:0] bid,
    output reg [1:0] bresp,
    output reg bvalid,
    input bready
);

    // 64-bit mtime counter
    reg [63:0] mtime;

    // Increment mtime every cycle
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mtime <= 64'b0;
        end else begin
            mtime <= mtime + 1;
        end
    end

    // Read state machine
    localparam IDLE = 1'b0;
    localparam RESP = 1'b1;
    reg state;

    // Address map:
    // 0x0200_bff8: mtime[31:0]  (lower 32 bits)
    // 0x0200_bffc: mtime[63:32] (upper 32 bits)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            arready <= 1'b1;
            rvalid <= 1'b0;
            rdata <= 32'b0;
            rresp <= 2'b00;
            rid <= 4'b0;
            rlast <= 1'b1;  // Single transfer
        end else begin
            case (state)
                IDLE: begin
                    if (arvalid && arready) begin
                        // Decode address and prepare response
                        case (araddr)
                            32'ha0000048: rdata <= mtime[31:0];   // Lower 32 bits
                            32'ha000004c: rdata <= mtime[63:32];  // Upper 32 bits
                            default: rdata <= 32'b0;              // Invalid address
                        endcase
                        rid <= arid;
                        rvalid <= 1'b1;
                        rresp <= 2'b00;
                        arready <= 1'b0;
                        state <= RESP;
                    end
                end
                RESP: begin
                    if (rvalid && rready) begin
                        rvalid <= 1'b0;
                        arready <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Write interface (always return error since mtime is read-only)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            awready <= 1'b1;
            wready <= 1'b1;
            bvalid <= 1'b0;
            bresp <= 2'b00;
            bid <= 4'b0;
        end else begin
            if (awvalid && wvalid && awready && wready) begin
                // Write attempt - return error
                bvalid <= 1'b1;
                bid <= awid;
                bresp <= 2'b10;  // SLVERR for write attempt to read-only register
                awready <= 1'b0;
                wready <= 1'b0;
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
                awready <= 1'b1;
                wready <= 1'b1;
            end
        end
    end

endmodule
/* verilator lint_on UNUSEDSIGNAL */ 
