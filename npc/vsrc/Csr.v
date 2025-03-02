module Csr (
  input clk,
  input rst,
  input [31:0] addr,
  input [31:0] csr_in,
  output reg [31:0] csr_out,
  input csr_wen,

  input        exception,    
  input [31:0] exception_pc,     
  input [31:0] exception_cause,

  output reg [31:0]mtvec,
  output reg [31:0]mepc
);
  reg [31:0]mstatus;
  reg [31:0]mcause;

  always @(posedge clk) begin
    if (rst) begin 
      mstatus <= 32'h1800;  // 初始值
      mtvec   <= 32'h0;     // 初始化 mtvec 
      mepc    <= 32'h0;     // 初始化 mepc  
      mcause  <= 32'h0;     // 初始化 mcause  
    end
    else if(exception)begin 
      mcause <= exception_cause;
      mepc   <= exception_pc;
    end
    else if (csr_wen) begin  
      if(addr == 32'h305) mtvec <= csr_in;
      else if(addr == 32'h300) mstatus <= csr_in;
      else if(addr == 32'h341) mepc    <= csr_in;
      else if(addr == 32'h342) mcause  <= csr_in;
    end
  end

  MuxKey #(4, 32, 32) out_mux(
    csr_out, addr, {
      32'h305, mtvec,
      32'h300, mstatus,
      32'h341, mepc,
      32'h342, mcause
    }
  );
endmodule
