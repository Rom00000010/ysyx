/* verilator lint_off UNUSEDSIGNAL */
module WBU(
        input clk,
        input rst,

        input exu_valid,
        input idu_valid,
        output reg wbu_ready,

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
        output [31:0]csr_in,

        // AXI interface
        output reg [31:0] araddr,
        output reg arvalid,
        input arready,
        input [31:0] rdata,
        input [1:0] rresp,
        input rvalid,
        output reg rready,
        output reg [31:0] awaddr,
        output reg awvalid,
        input awready,
        output reg [31:0] wdata_out,
        output reg [7:0] wstrb,
        output reg wvalid,
        input wready,
        input [1:0] bresp,
        input bvalid,
        output reg bready
   );

    wire not_ld = (idu_valid && exu_valid && wbu_ready) && !valid;
    always @(*) begin
        if(rst) begin
            wbu_valid = 1'b0;
            wbu_ready = 1'b0;
        end
        else begin
            wbu_valid = not_ld || mem_valid;
            wbu_ready = 1'b1;
        end
    end

// =======================================State Machine======================================

    localparam IDLE = 0,
               READ_WAIT = 1,
               WRITE_WAIT = 2;

    reg [2:0] state, next_state;

    always @(posedge clk or posedge rst) begin
        if(rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if(arready && arvalid)
                    next_state = READ_WAIT;
                else if(awready && wready && awvalid && wvalid)
                    next_state = WRITE_WAIT;
            end

            READ_WAIT: begin
                if(rready && rvalid)
                    next_state = IDLE;
            end

            WRITE_WAIT: begin
                if(bready && bvalid)
                    next_state = IDLE;
            end

            default: begin
                next_state = state;
            end
        endcase
        
    end

    // Output logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            rready <= 1'b0;
            bready <= 1'b0;
            arvalid <= 1'b0;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            mem_valid <= 1'b0;
            rdata_latch <= 32'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                    end

                    if(awvalid && awready && wvalid && wready) begin
                        awvalid <= 1'b0;
                        wvalid <= 1'b0;
                    end

                    // Actually equal with IFU fetch state logic
                    if(valid && !mem_wen && idu_valid) begin
                        arvalid <= 1'b1;
                        araddr <= raddr;
                        rready <= 1'b1;
                    end
                    
                    if(valid && mem_wen && idu_valid) begin
                        awvalid <= 1'b1;
                        awaddr <= waddr;
                        wvalid <= 1'b1;
                        wdata_out <= wdata;
                        wstrb <= wmask;
                        bready <= 1'b1;
                    end

                    mem_valid <= 1'b0;
                end

                // TODO: Need to latch resp
                READ_WAIT: begin
                    if(rready && rvalid)
                        begin
                            mem_valid <= 1'b1;
                            rready <= 1'b0;
                            arvalid <= 1'b0;
                            rdata_latch <= rdata;
                        end
                end

                WRITE_WAIT: begin
                    if(bready && bvalid)
                        begin
                            mem_valid <= 1'b1;
                            bready <= 1'b0;
                            awvalid <= 1'b0;
                            wvalid <= 1'b0;
                        end
                end

                default: begin
                end
            endcase
        end
    end

    reg mem_valid;

// =======================================Memory Read======================================

    reg [31:0] rdata_latch;

    // Memory read, Extract data from 4 bytes based on address
    wire [31:0] mask_data;

    wire [7:0] lb_data = (raddr[1:0] == 2'b00) ? rdata_latch[7:0]  :
         (raddr[1:0] == 2'b01) ? rdata_latch[15:8] :
         (raddr[1:0] == 2'b10) ? rdata_latch[23:16] :
         rdata_latch[31:24];

    wire [15:0] lh_data = (raddr[1:0] == 2'b00) ? rdata_latch[15:0] :
         (raddr[1:0] == 2'b10) ? rdata_latch[31:16] :
         16'b0;

    MuxKey #(5, 3, 32) mask_data_mux(
               mask_data, mem_width, {
                   3'b000, {{24{lb_data[7]}}, lb_data},
                   3'b001, {{16{lh_data[15]}}, lh_data},
                   3'b010, rdata_latch,
                   3'b100, {{24{1'b0}}, lb_data},
                   3'b101, {{16{1'b0}}, lh_data}
               }
           );

    // ==================================================================================

    MuxKey #(4, 2, 32) wdata_regd_mux(
               wdata_regd, wb_sel, {
                   2'b00, alu_res,
                   2'b01, pc+4,
                   2'b10, csr_out,
                   2'b11, mask_data
               }
           );

    assign csr_in = csr_write_set ? data_reg1 | csr_out : data_reg1;

    // ==================================================================================

    function automatic int wbu_skip();
        wbu_skip = {31'b0, !(state == IDLE && wbu_valid == 1'b1)};
    endfunction

    export "DPI-C" function wbu_skip;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
