/* verilator lint_off UNUSEDSIGNAL */
module Uart (
    input clk,
    input rst,

    // AXI4-Lite slave interface
    // Write address channel
    input [31:0] awaddr,
    input awvalid,
    output reg awready,
    // Write data channel
    input [31:0] wdata,
    input [3:0] wstrb,
    input wvalid,
    output reg wready,
    // Write response channel
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

    // Simple state machine for write
    localparam IDLE = 1'b0;
    localparam RESP = 1'b1;
    reg state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            awready <= 1'b1;
            wready <= 1'b1;
            bvalid <= 1'b0;
            bresp <= 2'b00;
        end else begin
            case (state)
                IDLE: begin
                    if (awvalid && wvalid && awready && wready) begin
                        // Write received, output character
                        difftest_skip_ref();
                        $write("%c", wdata[7:0]);
                        $fflush();
                        
                        // Prepare response
                        bvalid <= 1'b1;
                        bresp <= 2'b00;
                        awready <= 1'b0;
                        wready <= 1'b0;
                        state <= RESP;
                    end
                end
                RESP: begin
                    if (bready && bvalid) begin
                        bvalid <= 1'b0;
                        awready <= 1'b1;
                        wready <= 1'b1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Read always returns 0 (UART status always ready)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            arready <= 1'b1;
            rvalid <= 1'b0;
            rdata <= 32'b0;
            rresp <= 2'b00;
        end else begin
            if (arvalid && arready) begin
                rvalid <= 1'b1;
                rdata <= 32'b0;
                rresp <= 2'b00;
                arready <= 1'b0;
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
                arready <= 1'b1;
            end
        end
    end

endmodule 
/* verilator lint_on UNUSEDSIGNAL */
