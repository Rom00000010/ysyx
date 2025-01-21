`timescale 1ns / 1ps

module linear_shift(
    input clk,
    input reset,
    input [7:0] seed,
    output [7:0] lfsr_out
);
    reg [2:0] ctrl;

    // Instantiate the shift register
    shift_reg #(.N(8)) my_shift_reg (
        .clk(clk),
        .ctrl(ctrl),
        .data_in(seed),
        .instream(feedback),
        .data_out(lfsr_out)
    );

    wire feedback;

    assign feedback = lfsr_out[0] ^ lfsr_out[2] ^ lfsr_out[3] ^ lfsr_out[4];

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            ctrl <= 3'b001;  // Load initial data into the shift register
        end else begin
            ctrl <= 3'b101;  // Shift right with instream
        end
    end

endmodule
