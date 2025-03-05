module IFU(
        input clk,
        input rst,
        input [31:0]next_pc,
        output [31:0]pc_val,
        output reg [31:0]instr
    );

    // PC register
    Reg #( 
            .WIDTH(32), .RESET_VAL(32'h80000000) ) pc (
            .clk(clk), .rst(rst),
            .din(next_pc), .dout(pc_val), .wen(1'b1)
        );

    // Fetch instruction
    always @(*) begin
        instr = pmem_read(pc_val);
        // ebreak: stop similation
        if(instr == 32'h00100073)
            set_finish();
    end

endmodule
