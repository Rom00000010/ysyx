`timescale 1ns / 1ns
module test_keyboard;

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

ps2_keyboard_model model(
    .ps2_clk(kbd_clk),
    .ps2_data(kbd_data)
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
    nextdata_n =1'b1;
    clrn = 1'b0;  #20;
    clrn = 1'b1;  #20;
    model.kbd_sendcode(8'h1C); // press 'A'
    model.kbd_sendcode(8'hF0); // break code
    #20 nextdata_n =1'b0; #20 nextdata_n =1'b1; //read data
    model.kbd_sendcode(8'h1C); // release 'A'
    #20 nextdata_n =1'b0; #20 nextdata_n =1'b1; //read data
    model.kbd_sendcode(8'h1B); // press 'S'
    #20 model.kbd_sendcode(8'h1B); // keep pressing 'S'
    #20 model.kbd_sendcode(8'h1B); // keep pressing 'S'
    model.kbd_sendcode(8'hF0); // break code
    model.kbd_sendcode(8'h1B); // release 'S'
    #20;
    $finish;
end

endmodule
