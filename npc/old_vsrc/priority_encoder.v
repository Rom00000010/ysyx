module priority_encoder(input [7:0] num,
                            output reg [2:0] bcd,
                            output reg indicator);
    always @ (*)
    casez (num)
        8'b1???????:
            begin bcd = 3'b111; indicator = 1; end
        8'b01??????:
            begin bcd = 3'b110; indicator = 1; end
        8'b001?????:
            begin bcd = 3'b101; indicator = 1; end
        8'b0001????:
            begin bcd = 3'b100; indicator = 1; end
        8'b00001???:
            begin bcd = 3'b011; indicator = 1; end
        8'b000001??:
            begin bcd = 3'b010; indicator = 1; end
        8'b0000001?:
            begin bcd = 3'b001; indicator = 1; end
        8'b00000001:
            begin bcd = 3'b000; indicator = 1; end
        default:
            begin bcd = 3'bxxx; indicator = 0; end
    endcase
endmodule
