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
    input rready
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
                        unique case (araddr)
                            32'h02000000: rdata <= mtime[31:0];   // Lower 32 bits
                            32'h02000004: rdata <= mtime[63:32];  // Upper 32 bits
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
endmodule
/* verilator lint_on UNUSEDSIGNAL */ 
