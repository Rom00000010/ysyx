`timescale 1ns / 1ns
module keyboard_handler(
        input ready,
        input clk,
        input [7:0] data,
        input reset,
        output [7:0]key,
        output reg nextdata_n,
        output reg [7:0]cnt,
        output reg [7:0]scan_code);

    always @(negedge clk)
        if(reset == 0) begin
            cnt <= 8'd0;
            nextdata_n <= 1'b1;
        end
        else begin
            if(ready) begin
                if(scan_code == 8'hF0) begin
                    scan_code <= 8'h0;
                end
                else begin
                    if(scan_code != data) begin
                        scan_code <= data;
                        if(data != 8'hF0)
                            cnt <= cnt + 1'b1;
                    end

                end
                nextdata_n <= 0;
            end
            else
                nextdata_n <= 1;
        end

    keycode_lut lut(.scan_code(scan_code),.ascii_code(key));

endmodule
