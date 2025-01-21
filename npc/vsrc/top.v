module top(
        input clk,
        input rst,
        input ps2_clk,ps2_data,
        output [6:0] seg0,
        output [6:0] seg1,
        output [6:0] seg2,
        output [6:0] seg3,
        output [6:0] seg4,
        output [6:0] seg5
    );

    wire nextdata_n;
    wire ready;
    wire overflow;
    wire [7:0]cnt;
    wire [7:0]key;
    wire [7:0]data;
    wire [7:0]scan_code;

    keyboard_handler handler(
                         .clk(clk),
                         .reset(~rst),
                         .ready(ready),
                         .nextdata_n(nextdata_n),
                         .data (data),
                         .key(key),
                         .cnt(cnt),
                         .scan_code(scan_code)
                     );

    ps2_keyboard_controller inst(
                                .clk(clk),
                                .clrn(~rst),
                                .ps2_clk(ps2_clk),
                                .ps2_data(ps2_data),
                                .data(data),
                                .ready(ready),
                                .nextdata_n(nextdata_n),
                                .overflow(overflow)
                            );

    hex7seg hex_seg0(
                .hex(scan_code[3:0]),
                .seg(seg0)
            );

    hex7seg hex_seg1(
                .hex(scan_code[7:4]),
                .seg(seg1)
            );

    hex7seg hex_seg2(
                .hex(key[3:0]),
                .seg(seg2)
            );

    hex7seg hex_seg3(
                .hex(key[7:4]),
                .seg(seg3)
            );

    hex7seg hex_seg4(
                .hex(cnt[3:0]),
                .seg(seg4)
            );

    hex7seg hex_seg5(
                .hex(cnt[7:4]),
                .seg(seg5)
            );

endmodule
