`timescale 1ns / 1ps

module test_random;
    reg clk;
    reg reset;
    reg [7:0] seed;
    wire [7:0] random_value;  // Changed to wire to connect to the module output

    random dut(
        .clk(clk),
        .reset(reset),
        .seed(seed),
        .lfsr_out(random_value)  // Connect the output correctly
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Generate a clock with a period of 10 ns
    end

    initial begin
        reset = 1'b1;
        seed = 8'b00000001;
        #10 reset = 0;
    end

    initial begin
        $monitor("Random value: %b", random_value);
    end

endmodule
