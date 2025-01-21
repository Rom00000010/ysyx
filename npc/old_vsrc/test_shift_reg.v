`timescale 1ns / 1ps

module test_shift_reg;

    parameter N = 4;
    reg clk;
    reg [2:0] ctrl;
    reg [N-1:0] data_in;
    reg instream;
    wire [N-1:0] data_out;

    // Instantiate the shift register module
    shift_reg #(.N(N)) uut (
        .clk(clk),
        .ctrl(ctrl),
        .data_in(data_in),
        .instream(instream),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // Generate a clock with a period of 10 ns
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        ctrl = 3'b000;
        data_in = 4'b1010;
        instream = 1'b1;

        // Reset the shift register
        #10;
        ctrl = 3'b000;  // Reset operation
        #10;

        // Load data into the register
        ctrl = 3'b001;  // Load operation
        #10;

        // Shift right
        ctrl = 3'b010;
        #10;

        // Shift left
        ctrl = 3'b011;
        #10;

        // Arithmetic shift right
        ctrl = 3'b100;
        #10;

        // Serial input shift right
        ctrl = 3'b101;
        #10;

        // Rotate right
        ctrl = 3'b110;
        #10;

        // Rotate left
        ctrl = 3'b111;
        #10;

        // Finish the simulation
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time = %t, ctrl = %b, data_in = %b, instream = %b, data_out = %b",
                 $time, ctrl, data_in, instream, data_out);
    end

endmodule
