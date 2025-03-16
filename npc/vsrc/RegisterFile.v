module RegisterFile #(ADDR_WIDTH = 1, DATA_WIDTH = 1) (
        input clk,
        input rst,
        input [DATA_WIDTH-1:0] wdata,
        input [ADDR_WIDTH-1:0] waddr,
        input [ADDR_WIDTH-1:0] raddr1,
        output[DATA_WIDTH-1:0] rdata1,
        input [ADDR_WIDTH-1:0] raddr2,
        output[DATA_WIDTH-1:0] rdata2,
        input wen
    );
    reg [DATA_WIDTH-1:0] rf [2**ADDR_WIDTH-1:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rf[0] <= 32'b0;
        end
        else if (write_enable) begin
            rf[waddr] <= wdata;
        end
    end

    // $0 always keep zero
    wire write_enable = wen & (waddr != 0);

    wire [31:0]zero_reg=32'h00000000;
    assign rdata1 = raddr1 == 0 ? zero_reg : rf[raddr1];
    assign rdata2 = raddr2 == 0 ? zero_reg : rf[raddr2];

endmodule
