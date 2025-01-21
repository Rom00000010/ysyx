module encdec(input [7:0] num,
               output [2:0] bcd,
               output indicator,
               output [6:0] seg);

    priority_encoder encoder(num[7:0], bcd, indicator);
    bcd7seg decoder(bcd, seg);
endmodule
