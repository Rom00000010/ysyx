module bucket_shift(
    input [7:0] din,        // 8-bit input data
    input [2:0] shamt,      // 3-bit shift amount
    input L_R,              // Left/Right shift direction (1 for left, 0 for right)
    input A_L,              // Arithmetic/Logical shift (1 for arithmetic, 0 for logical)
    output reg [7:0] dout   // 8-bit output data
);

always @(*) begin
    // Check the direction of the shift
    if (L_R) begin
        // Left Shift
        dout = din << shamt;
    end else begin
        // Right Shift
        if (A_L) begin
            // Arithmetic Right Shift
            dout = $signed(din) >>> shamt;
        end else begin
            // Logical Right Shift
            dout = din >> shamt;
        end
    end
end

endmodule
