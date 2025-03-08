module IFU(
        input clk,
        input rst,
        input branch_taken,
        input [31:0]branch_target,
        output [31:0]pc,
        output reg [31:0]instr
    );

    // PC register
    Reg #(
            .WIDTH(32), .RESET_VAL(32'h80000000) ) pc_reg (
            .clk(clk), .rst(rst),
            .din(branch_taken ? branch_target : pc+4), .dout(pc), .wen(1'b1)
        );

    // Fetch instruction
    always @(*) begin
        instr <= pmem_read(pc);
    end

    always @(*) begin
        // ebreak: stop similation
        if(instr == 32'h00100073)
            set_finish();
    end

endmodule
