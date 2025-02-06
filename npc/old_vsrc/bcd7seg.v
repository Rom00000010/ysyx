module bcd7seg(input [2:0] bcd,
                   output reg [6:0] seg);
    always @ (*)
        casez (bcd)
            //          abc-defg
            0:seg = ~7'b111_1110;
            1:seg = ~7'b011_0000;
            2:seg = ~7'b110_1101;
            3:seg = ~7'b111_1001;
            4:seg = ~7'b011_0011;
            5:seg = ~7'b101_1011;
            6:seg = ~7'b101_1111;
            7:seg = ~7'b111_0000;
            default: seg = ~7'b000_0000;
        endcase
endmodule
  