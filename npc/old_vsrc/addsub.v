module addsub(
        input [3:0] a,b,
        input sel,
        output [3:0] res,
        output zero,
        output reg cout, overflow
    );
    wire [3:0]nb;
    wire outc, add_overflow;
    assign nb = {4{ sel }}^b;

    adder #(4) alu(a,nb,sel,res,outc,add_overflow);

    always @(*)
        begin
            if (sel == 1'b1)
                cout = res[3] ^ overflow;
            else
                cout = outc;
        end

    assign zero = ~(| res);
    
    always @(*)
        begin
            if (sel == 1'b1 && b == 4'b1000)
                overflow = (a[3] == nb[3]) && (res[3] != a[3]);
            else
                overflow = add_overflow;
        end
endmodule
