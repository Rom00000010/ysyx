/* verilator lint_off UNOPTFLAT */
module alu(input [3:0] a,b,
               input [2:0] f,
               output reg [3:0] y,
               output zf, of ,cf);

    reg [3:0] bb;
    reg cin;
    wire [3:0] xy;
    /* verilator lint_on UNOPTFLAT */

    addsub add4er(
               .a(a),
               .b(bb),
               .sel(cin),
               .res(xy),
               .cout(cf),
               .zero(zf),
               .overflow(of)
           );

    always @(*) begin
        case(f)
            3'b000: begin
                cin = 1'b0;
                bb = b;
                y=xy;
            end

            3'b001: begin
                cin = 1'b1;
                bb = b;
                y=xy;
            end

            3'b010: begin
                cin = 1'b0;
                bb = 4'b1111;
                y = a ^ bb;
            end

            3'b011: begin
                cin = 1'b0;
                bb = b;
                y = a & bb;
            end

            3'b100: begin
                cin = 1'b0;
                bb = b;
                y = a | bb;
            end

            3'b101: begin
                cin = 1'b0;
                bb = b;
                y = a ^ bb;
            end

            3'b110: begin
                cin = 1'b1;
                bb = b;
                y = {3'b000, cf};
            end

            3'b111: begin
                cin = 1'b1;
                bb = b;
                y = {3'b000, zf};
            end

            default: begin
                cin = 1'b0;
                bb = b;
                y=xy;
            end
        endcase
    end

endmodule
