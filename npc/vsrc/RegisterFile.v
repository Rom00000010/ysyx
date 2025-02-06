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
  wire write_enable;
  wire [31:0]zero_reg=32'h00000000;

  assign write_enable = wen & (waddr != 5'd0);

  always @(posedge clk) begin
    if (write_enable && ~rst) rf[waddr] <= wdata;
  end

  assign rdata1 = raddr1 == 5'd0 ? zero_reg : rf[raddr1];
  assign rdata2 = raddr2 == 5'd0 ? zero_reg : rf[raddr2];
endmodule
