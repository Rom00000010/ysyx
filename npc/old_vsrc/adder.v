module adder #(parameter N=4)
    (input [N-1:0] a,b,
     input  cin,
     output reg     [N-1:0] s,
     output outc, overflow);

    wire [N-1:0] bcy;
    assign bcy = b+{{(N-1){1'b0}}, cin};

    assign {outc, s} = a+bcy;

    assign overflow = (a[N-1] == bcy[N-1]) && (s[N-1] != a[N-1]);

endmodule
