/* verilator lint_off UNUSEDSIGNAL */
module WBU(
        input clk,
        input rst,

        input exu_valid,
        output reg wbu_ready,
        input idu_valid,

        output reg wbu_valid,
        input idu_ready,

        input valid, // memory access instr
        input mem_wen,
        input [2:0]mem_width,
        input [1:0]wb_sel,
        input csr_write_set,

        input [31:0]alu_res,
        input [31:0]data_reg1,
        input [31:0]raddr,
        input [31:0]waddr,
        input [7:0]wmask,
        input [31:0]wdata,
        input [31:0]pc,
        input [31:0]csr_out,

        output [31:0]wdata_regd,
        output [31:0]csr_in
   );

    wire not_ld = (idu_valid && exu_valid && wbu_ready) && !(valid && !mem_wen);
    always @(*) begin
        if(rst) begin
            wbu_valid = 1'b0;
            wbu_ready = 1'b0;
        end
        else begin
            wbu_valid = not_ld || ready;
            wbu_ready = 1'b1;
        end
    end

    wire ready;
    LSU lsu(
        .clk(clk),
        .rst(rst),
        .addr(raddr),
        .req(valid && !mem_wen && idu_valid),
        .ready(ready),
        .data(rdata),
        .wdata(wdata),
        .wmask(wmask),
        .waddr(waddr),
        .wen(mem_wen)
    );

    // Memory read, Extract data from 4 bytes based on address
    reg [31:0] rdata;
    wire [31:0] mask_data;

    wire [7:0] lb_data = (raddr[1:0] == 2'b00) ? rdata[7:0]  :
         (raddr[1:0] == 2'b01) ? rdata[15:8] :
         (raddr[1:0] == 2'b10) ? rdata[23:16] :
         rdata[31:24];

    wire [15:0] lh_data = (raddr[1:0] == 2'b00) ? rdata[15:0] :
         (raddr[1:0] == 2'b10) ? rdata[31:16] :
         16'b0;

    MuxKey #(5, 3, 32) mask_data_mux(
               mask_data, mem_width, {
                   3'b000, {{24{lb_data[7]}}, lb_data},
                   3'b001, {{16{lh_data[15]}}, lh_data},
                   3'b010, rdata,
                   3'b100, {{24{1'b0}}, lb_data},
                   3'b101, {{16{1'b0}}, lh_data}
               }
           );

    // ==================================================================================

    // not optimal encode
    MuxKey #(4, 2, 32) wdata_regd_mux(
               wdata_regd, wb_sel, {
                   2'b00, alu_res,
                   2'b01, pc+4,
                   2'b10, csr_out,
                   2'b11, mask_data
               }
           );

    // mem_width actually is func3, distinguish csrrw/csrrs
    assign csr_in = csr_write_set ? data_reg1 | csr_out : data_reg1;

    function automatic int get_mem_ready();
        get_mem_ready = {31'b0, ready};
    endfunction

    export "DPI-C" function get_mem_ready;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
