`timescale 1ns / 1ns
module top;

    /* parameter */
    parameter [31:0] clock_period = 10;

    /* ps2_keyboard interface signals */
    reg clk,clrn;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [7:0] data;
    wire ready,overflow;
    /* verilator lint_on UNUSEDSIGNAL */
    wire kbd_clk, kbd_data;
    reg nextdata_n;
    wire [7:0] key;
    wire [7:0] cnt;

    ps2_keyboard_model model(
                           .ps2_clk(kbd_clk),
                           .ps2_data(kbd_data)
                       );

    keyboard_handler handler(
                .clk(clk),
                .reset(clrn),
                .ready(ready),
                .nextdata_n(nextdata_n),
                .data (data),
                .key(key),
                .cnt(cnt)
            );

    ps2_keyboard_controller inst(
                                .clk(clk),
                                .clrn(clrn),
                                .ps2_clk(kbd_clk),
                                .ps2_data(kbd_data),
                                .data(data),
                                .ready(ready),
                                .nextdata_n(nextdata_n),
                                .overflow(overflow)
                            );



    initial begin /* clock driver */
        clk = 0;
        forever
            #(clock_period/2) clk = ~clk;
    end

    initial begin
        clrn = 1'b0;
        #20;
        clrn = 1'b1;
        #20;
        model.kbd_sendcode(8'h1C); // press 'A'
        #20;
        $display("%d pressed, current key is %h", cnt, key);
        model.kbd_sendcode(8'h45); // break code
        #20;
        $display("%d pressed, current key is %h", cnt, key);
        model.kbd_sendcode(8'h32); // release 'A'
        #20;
        $display("%d pressed, current key is %h", cnt, key);
        $finish;
    end

endmodule
