`timescale 1ns / 1ps

module shift_reg #(parameter N=4)
    (
        input clk,
        input [2:0] ctrl,
        input [N-1:0] data_in,
        input instream,
        output reg [N-1:0] data_out
    );

    always @ (posedge clk) begin
        case (ctrl)
            3'b000: data_out <= 0;
            3'b001: data_out <= data_in;
            3'b010: data_out <= {1'b0, data_out[N-1:1]};
            3'b011: data_out <= {data_out[N-2:0], 1'b0};
            3'b100: data_out <= {data_out[N-1], data_out[N-1:1]};
            3'b101: data_out <= {instream, data_out[N-1:1]};
            3'b110: data_out <= {data_out[0], data_out[N-1:1]};
            3'b111: data_out <= {data_out[N-2:0], data_out[N-1]};
            default: data_out <= 0;
        endcase
    end
endmodule
