module LSU(
        input clk,
        input rst,
        input [31:0]addr,
        input req,
        output reg ready,
        output reg [31:0] data,
        input [31:0]wdata,
        input [7:0]wmask,
        input [31:0]waddr,
        input wen
    );

    always @(posedge clk) begin
        if (rst) begin
            ready <= 1'b0;
            data <= 32'h0;
        end
        else if (req) begin
            ready <= 1'b1;
            data <= pmem_read(addr);
        end
        else begin
            ready <= 1'b0;
            data <= 32'h0;
        end
    end

    always @(*) begin
        if(wen && clk == 1'b0) begin
            pmem_write(waddr, wdata, wmask);
        end
    end

endmodule
