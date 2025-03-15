module Lfsr(
    input clk,
    input rst,
    input [3:0] seed,
    output [3:0] lfsr_out
);
    reg [2:0] ctrl;

    // Instantiate the shift register
    ShiftReg #(.N(4)) my_shift_reg (
        .clk(clk),
        .ctrl(ctrl),
        .data_in(seed),
        .instream(feedback),
        .data_out(lfsr_out)
    );

    wire feedback;

    assign feedback = lfsr_out[0] ^ lfsr_out[3];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ctrl <= 3'b001;  // Load initial data into the shift register
        end else begin
            ctrl <= 3'b101;  // Shift right with instream
        end
    end

endmodule
