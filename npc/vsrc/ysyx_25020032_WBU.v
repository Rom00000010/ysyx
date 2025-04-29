/* verilator lint_off UNUSEDSIGNAL */
`include "axi_interface.vh"
`include "common.vh"

module ysyx_25020032_WBU(
        input clk,
        input rst,

        // EXU->WBU synchronization 
        input exu_valid,
        output reg wbu_ready,

        input [2:0]mem_width,
        input mem_wen,
        input valid,
        input [1:0]wb_sel,
        input csr_write_set,
        input csr_wen,
        input reg_write,

        input [31:0]ext_imm,
        input [31:0]data_reg1,
        input [31:0]csr_out,
        input [31:0]pc,
        input [3:0]rd,
        input [31:0]instr,

        input [31:0]alu_res,
        input [31:0]raddr,
        input [31:0]wrdata,
        input [3:0]wmask,

        // WBU->IDU synchronization
        output reg wbu_valid,
        input idu_ready,

        output [31:0]wdata_regd,
        output [3:0] ex_wb_rd,
        output [31:0]csr_in,
        output reg ex_wb_csr_wen,
        output reg ex_wb_reg_write,
        output reg [31:0] ex_wb_ext_imm,

        output access_fault,

        output reg proc_instr,

        // Difftest
        input branch_taken,
        input [31:0]branch_target,

        // AXI interface
        `AXI_MASTER_READ_ADDR_PORTS,
        `AXI_MASTER_WRITE_ADDR_PORTS
    );

`ifdef MEMORY_EVENT
    // extra cycle caused by memory access
    reg [31:0] extra_cnt;

    reg [31:0] finish_cnt;

    initial begin
        extra_cnt = 0;
        finish_cnt = 0;
    end

    always @(posedge clk) begin
        if(rready && rvalid || bready && bvalid) begin
            extra_cnt <= extra_cnt + 1;
            finish_cnt <= finish_cnt + 1;
        end
        else if(state != IDLE)
            extra_cnt <= extra_cnt + 1;
    end

    // For Difftest
    wire sram_access = ex_wb_raddr >= 32'h0f000000 && ex_wb_raddr < 32'h0f000000 + 32'h00002000;
    wire sdram_access = ex_wb_raddr >= 32'ha0000000 && ex_wb_raddr < 32'hbfffffff;
`endif

    reg [2:0] ex_wb_mem_width;
    reg [1:0] ex_wb_wb_sel;
    reg ex_wb_csr_write_set;
    
    reg [31:0] ex_wb_data_reg1;
    reg [31:0] ex_wb_csr_out;
    reg [31:0] ex_wb_pc;
    reg [31:0] ex_wb_raddr;

    reg [31:0] ex_wb_alu_res;

    reg [31:0] ex_wb_instr;

    reg ex_wb_branch_taken;
    reg [31:0] ex_wb_branch_target;

    always @(posedge clk) begin
        if(rst) begin
            wbu_valid <= 1'b0;
        end
        else begin
            if(exu_valid && wbu_ready) begin
                wbu_valid <= !valid;

                ex_wb_mem_width <= mem_width;
                ex_wb_wb_sel <= wb_sel;
                ex_wb_csr_write_set <= csr_write_set;
                ex_wb_csr_wen <= csr_wen;
                ex_wb_reg_write <= reg_write;

                ex_wb_ext_imm <= ext_imm;
                ex_wb_data_reg1 <= data_reg1;
                ex_wb_rd <= rd;
                ex_wb_csr_out <= csr_out;
                ex_wb_pc <= pc;

                ex_wb_alu_res <= alu_res;

                ex_wb_raddr <= raddr;

                ex_wb_instr <= instr;

                ex_wb_branch_taken <= branch_taken;
                ex_wb_branch_target <= branch_target;

            end else if (rready && rvalid || bready && bvalid) begin
                wbu_valid <= 1'b1;
            end else if(wbu_valid)begin
                wbu_valid <= 1'b0;
            end     
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

    reg [1:0]rresp_latch;
    reg [1:0]bresp_latch;

    always @* begin
        arid = `AXI_DEFAULT_ID;
        arlen = `AXI_DEFAULT_LEN;
        arburst = `AXI_DEFAULT_BURST;
        awid = `AXI_DEFAULT_ID;
        awlen = `AXI_DEFAULT_LEN;
        awburst = `AXI_DEFAULT_BURST;
        wlast = 1'b1;  // Single transfer
    end

    // Output logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            wbu_ready <= 1'b1;
            proc_instr <= 1'b0;
            rready <= 1'b0;
            bready <= 1'b0;
            arvalid <= 1'b0;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            // Set default values for AXI signals
            arsize <= `AXI_DEFAULT_SIZE;
            awsize <= `AXI_DEFAULT_SIZE;
        end
        else begin
            case (state)
                IDLE: begin
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                    end 
                    else if(awvalid && awready && wvalid && wready) begin
                        awvalid <= 1'b0;
                        wvalid <= 1'b0;
                    end
                    // Actually equal with IFU fetch state logic
                    else if(exu_valid && valid && !mem_wen) begin
                        arvalid <= 1'b1;
                        araddr <= raddr;
                        rready <= 1'b1;
                        arsize <= size;
                        wbu_ready <= 1'b0;
                        proc_instr <= 1'b1;
                    end
                    else if(exu_valid && valid && mem_wen) begin
                        awvalid <= 1'b1;
                        awaddr <= raddr;
                        wvalid <= 1'b1;
                        wdata <= wrdata;
                        wstrb <= wmask[3:0];  // Convert 8-bit to 4-bit
                        bready <= 1'b1;
                        awsize <= size;
                        wbu_ready <= 1'b0;
                        proc_instr <= 1'b1;
                    end 
                    else if(exu_valid && !valid) begin
                        proc_instr <= 1'b1;
                    end

                    if(wbu_valid && !exu_valid) proc_instr <= 1'b0;
                end

                // TODO: Need to latch resp
                READ_WAIT: begin
                    if(rready && rvalid) begin
                        rready <= 1'b0;
                        arvalid <= 1'b0;
                        rdata_latch <= rdata;
                        rresp_latch <= rresp;
                        wbu_ready <= 1'b1;
                        `ifndef SYNTHESIS
                            if(!sram_access && !sdram_access)
                                difftest_skip_ref();
                        `endif
                    end
                end

                WRITE_WAIT: begin
                    if(bready && bvalid) begin
                        bready <= 1'b0;
                        awvalid <= 1'b0;
                        wvalid <= 1'b0;
                        bresp_latch <= bresp;
                        wbu_ready <= 1'b1;
                        `ifndef SYNTHESIS
                            if(!sram_access && !sdram_access)
                                difftest_skip_ref();
                        `endif
                    end
                end

                default: begin
                end
            endcase
        end
    end

    assign access_fault = (rresp_latch != 2'b00 || bresp_latch != 2'b00);

    // =======================================Memory Read======================================

    reg [31:0] rdata_latch;

    // Memory read, Extract data from 4 bytes based on address
    wire [31:0] mask_data;

    wire [7:0] lb_data = {8{(ex_wb_raddr[1:0] == 2'b00)}} & rdata_latch[7:0] |
         {8{(ex_wb_raddr[1:0] == 2'b01)}} & rdata_latch[15:8] |
         {8{(ex_wb_raddr[1:0] == 2'b10)}} & rdata_latch[23:16] |
         {8{(ex_wb_raddr[1:0] == 2'b11)}} & rdata_latch[31:24];

    wire [15:0] lh_data = {16{(ex_wb_raddr[1:0] == 2'b00)}} & rdata_latch[15:0] |
         {16{(ex_wb_raddr[1:0] == 2'b10)}} & rdata_latch[31:16] |
         16'b0;

    // ysyx_25020032_MuxKey #(5, 3, 32) mask_data_mux(
    //                          mask_data, ex_wb_mem_width, {
    //                              3'b000, {{24{lb_data[7]}}, lb_data},
    //                              3'b001, {{16{lh_data[15]}}, lh_data},
    //                              3'b010, rdata_latch,
    //                              3'b100, {{24{1'b0}}, lb_data},
    //                              3'b101, {{16{1'b0}}, lh_data}
    //                          }
    //                      );

    assign mask_data = {32{ex_wb_mem_width == 3'b000}} & {{24{lb_data[7]}}, lb_data} |
                       {32{ex_wb_mem_width == 3'b001}} & {{16{lh_data[15]}}, lh_data} |
                       {32{ex_wb_mem_width == 3'b010}} & rdata_latch |
                       {32{ex_wb_mem_width == 3'b100}} & {{24{1'b0}}, lb_data} |
                       {32{ex_wb_mem_width == 3'b101}} & {{16{1'b0}}, lh_data};

    wire [2:0] size;
    // ysyx_25020032_MuxKey #(5, 3, 3) size_mux(
    //                          size, ex_wb_mem_width, {
    //                              3'b000, 3'b000,
    //                              3'b001, 3'b001,
    //                              3'b010, 3'b010,
    //                              3'b100, 3'b000,
    //                              3'b101, 3'b001
    //                          }
    //                      );

    assign size = {3{ex_wb_mem_width == 3'b000}} & 3'b000 |
                  {3{ex_wb_mem_width == 3'b001}} & 3'b001 |
                  {3{ex_wb_mem_width == 3'b010}} & 3'b010 |
                  {3{ex_wb_mem_width == 3'b100}} & 3'b000 |
                  {3{ex_wb_mem_width == 3'b101}} & 3'b001;

    // ==================================================================================

    // ysyx_25020032_MuxKey #(4, 2, 32) wdata_regd_mux(
    //                          wdata_regd, ex_wb_wb_sel, {
    //                              2'b00, ex_wb_alu_res,
    //                              2'b01, ex_wb_pc+4,
    //                              2'b10, ex_wb_csr_out,
    //                              2'b11, mask_data
    //                          }
    //                      );

    assign wdata_regd = {32{ex_wb_wb_sel == 2'b00}} & ex_wb_alu_res |
                        {32{ex_wb_wb_sel == 2'b01}} & ex_wb_pc+4 |
                        {32{ex_wb_wb_sel == 2'b10}} & ex_wb_csr_out |
                        {32{ex_wb_wb_sel == 2'b11}} & mask_data;

    assign csr_in = ex_wb_csr_write_set ? ex_wb_data_reg1 | ex_wb_csr_out : ex_wb_data_reg1;

`ifndef SYNTHESIS   
    function automatic int wbu_skip();
        wbu_skip = {31'b0, !(state == IDLE && wbu_valid == 1'b1)};
    endfunction

    export "DPI-C" function wbu_skip;
`endif
endmodule
/* verilator lint_on UNUSEDSIGNAL */
