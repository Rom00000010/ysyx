module hex7seg(
    input [3:0] hex,      // 4位输入，表示16进制数字0-F
    output reg [6:0] seg  // 7段数码管的段信号，低电平有效
);
    always @(*) begin
        case (hex)
            4'h0: seg = ~7'b111_1110; // 显示数字0
            4'h1: seg = ~7'b011_0000; // 显示数字1
            4'h2: seg = ~7'b110_1101; // 显示数字2
            4'h3: seg = ~7'b111_1001; // 显示数字3
            4'h4: seg = ~7'b011_0011; // 显示数字4
            4'h5: seg = ~7'b101_1011; // 显示数字5
            4'h6: seg = ~7'b101_1111; // 显示数字6
            4'h7: seg = ~7'b111_0000; // 显示数字7
            4'h8: seg = ~7'b111_1111; // 显示数字8
            4'h9: seg = ~7'b111_1011; // 显示数字9
            4'hA: seg = ~7'b111_0111; // 显示字母A
            4'hB: seg = ~7'b001_1111; // 显示字母b
            4'hC: seg = ~7'b100_1110; // 显示字母C
            4'hD: seg = ~7'b011_1101; // 显示字母d
            4'hE: seg = ~7'b100_1111; // 显示字母E
            4'hF: seg = ~7'b100_0111; // 显示字母F
            default: seg = ~7'b000_0000; // 关闭所有段
        endcase
    end
endmodule