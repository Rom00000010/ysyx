/* verilator lint_off UNUSEDSIGNAL */
module Clint (
    input clk,
    input rst,

    // AXI4-Lite slave interface
    // Write address channel (not used, read-only)
    input [31:0] awaddr,
    input awvalid,
    output reg awready,
    // Write data channel (not used, read-only)
    input [31:0] wdata,
    input [3:0] wstrb,
    input wvalid,
    output reg wready,
    // Write response channel (not used, read-only)
    output reg [1:0] bresp,
    output reg bvalid,
    input bready,
    // Read address channel
    input [31:0] araddr,
    input arvalid,
    output reg arready,
    // Read data channel
    output reg [31:0] rdata,
    output reg [1:0] rresp,
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
        end else begin
            if (awvalid && wvalid && awready && wready) begin
                // Write attempt - return error
                bvalid <= 1'b1;
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
