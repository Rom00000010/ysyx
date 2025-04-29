module ysyx_25020032_Csr (
        input clk,
        input rst,

        input [11:0] raddr,
        input [11:0] waddr, 
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

    wire [5:0] csr_sel;
    assign csr_sel = { raddr==12'hf12,  // bit5
                       raddr==12'hf11,  // bit4
                       raddr==12'h342,  // …
                       raddr==12'h341,
                       raddr==12'h300,
                       raddr==12'h305 };

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus <= 32'h1800;
            mtvec   <= 32'h0;
            mepc    <= 32'h0;
            mcause  <= 32'h0;
        end
        else if(exception) begin
            mcause <= exception_cause;
            mepc   <= exception_pc;
        end
        else if (csr_wen) begin
            mtvec   <= waddr == 12'hf12 ? csr_in : mtvec;
            mstatus <= waddr == 12'hf11 ? csr_in : mstatus;
            mepc    <= waddr == 12'h342 ? csr_in : mepc;
            mcause  <= waddr == 12'h341 ? csr_in : mcause;
        end
    end

    always @* begin
        unique case (1'b1)            // priority‑free one‑hot MUX
                   csr_sel[0]:
                       csr_out = mtvec;
                   csr_sel[1]:
                       csr_out = mstatus;
                   csr_sel[2]:
                       csr_out = mepc;
                   csr_sel[3]:
                       csr_out = mcause;
                   csr_sel[4]:
                       csr_out = mvendorid;
                   csr_sel[5]:
                       csr_out = marchid;
                   default  :
                       csr_out = 32'h0;
               endcase
           end
endmodule
