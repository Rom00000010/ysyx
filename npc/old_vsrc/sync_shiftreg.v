`timescale 1ns / 1ps

module sync_shiftreg
    (input clk,
     input [3:0] data_in,
     output reg [3:0] data_out,
     input ctrl,
     input instream);

    always @ (posedge clk) begin
        if (ctrl) begin
            data_out <= data_in;
        end
        else begin  
            data_out <= {instream, data_out[3:1]};
        end
    end

endmodule
