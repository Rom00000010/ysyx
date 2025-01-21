module test_bucket;

    reg [7:0] din;
    reg [2:0] shamt;
    reg L_R;
    reg A_L;
    wire [7:0] dout;

    // Instantiate the bucket shift module
    bucket_shift uut (
        .din(din),
        .shamt(shamt),
        .L_R(L_R),
        .A_L(A_L),
        .dout(dout)
    );

    // Test stimulus
    initial begin
        // Initialize inputs
        din = 8'b11010101;  // Example input data
        shamt = 3'b010;     // Example shift amount
        L_R = 0;            // Start with right shift
        A_L = 0;            // Logical shift

        // Test Logical Right Shift
        #10;
        L_R = 0;
        A_L = 0;
        shamt = 3'b001;    // Shift by 1 bit
        #10;

        // Test Arithmetic Right Shift
        L_R = 0;
        A_L = 1;
        shamt = 3'b010;    // Shift by 2 bits
        #10;

        // Test Left Shift
        L_R = 1;
        A_L = 0;           // Not used for left shifts
        shamt = 3'b011;    // Shift by 3 bits
        #10;

        // Finish the simulation
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("din = %b, shamt = %b, L_R = %b, A_L = %b, dout = %b",
                 din, shamt, L_R, A_L, dout);
    end

endmodule
