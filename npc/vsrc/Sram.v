module Sram(
    input clk,
    input rst,
    input [31:0]addr,
    input req,
    output reg ready,
    output reg [31:0] data
);

    always @(posedge clk) begin
        if(rst) begin
            ready <= 1'b0;
            data <= 32'h0;
        end
        else if(req)begin
            ready <= 1'b1;
            data <= pmem_read(addr);
        end
        else begin
            ready <= 1'b0;
            data <= data;
        end

    end

endmodule
