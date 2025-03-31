module ysyx_25020032_Csr (
  input clk,
  input rst,
  
  input [31:0] addr,
  input [31:0] csr_in,
  input csr_wen,

  input        exception,    
  input [31:0] exception_pc,     
  input [31:0] exception_cause,

  output reg [31:0]mtvec,
  output reg [31:0]mepc,
  output reg [31:0] csr_out
);
  reg [31:0]mstatus;
  reg [31:0]mcause;
  wire [31:0]mvendorid = 32'h79737978;
  wire [31:0]marchid = 32'h017dc680;

  wire [31:0]mask_addr = addr & 32'h00000fff;

  always @(posedge clk or posedge rst) begin
    if (rst) begin 
      mstatus <= 32'h1800;  
      mtvec   <= 32'h0;     
      mepc    <= 32'h0;      
      mcause  <= 32'h0;   
    end
    else if(exception)begin 
      mcause <= exception_cause;
      mepc   <= exception_pc;
    end
    else if (csr_wen) begin  
      if(mask_addr == 32'h00000305) mtvec <= csr_in;
      else if(mask_addr == 32'h00000300) mstatus <= csr_in;
      else if(mask_addr == 32'h00000341) mepc    <= csr_in;
      else if(mask_addr == 32'h00000342) mcause  <= csr_in;
    end
  end

  ysyx_25020032_MuxKey #(6, 32, 32) out_mux(
    csr_out, mask_addr, {
      32'h00000305, mtvec,
      32'h00000300, mstatus,
      32'h00000341, mepc,
      32'h00000342, mcause,
      32'h00000f11, mvendorid,
      32'h00000f12, marchid
    }
  );
endmodule
