/* verilator lint_off UNUSEDSIGNAL */
`include "axi_interface.vh"
`include "common.vh"

module ysyx_25020032_WBU(
        input clk,
        input rst,

        // EXU->WBU synchronization 
        input exu_valid,
        output reg wbu_ready,

        input [3:0] branch_type,
        input [2:0]mem_width,
        input mem_wen,
        input valid,
        input [1:0]wb_sel,
        input csr_write_set,

        input [31:0]ext_imm,
        input [31:0]data_reg1,
        input [31:0]csr_out,
        input [31:0]mepc,
        input [31:0]mtvec,
        input [31:0]pc,

        input [31:0]alu_res,
        input [31:0]raddr,
        input [31:0]wrdata,
        input [3:0]wmask,

        // WBU->IDU synchronization
        output reg wbu_valid,
        input idu_ready,

        output [31:0]wdata_regd,
        output [31:0]csr_in,

        output access_fault,
        output [31:0]branch_target,
        output branch_taken,

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
`endif

    reg [3:0] ex_wb_branch_type;
    reg [2:0] ex_wb_mem_width;
    reg ex_wb_mem_wen;
    reg ex_wb_valid;
    reg [1:0] ex_wb_wb_sel;
    reg ex_wb_csr_write_set;

    reg [31:0] ex_wb_ext_imm;
    reg [31:0] ex_wb_data_reg1;
    reg [31:0] ex_wb_csr_out;
    reg [31:0] ex_wb_mepc;
    reg [31:0] ex_wb_mtvec;
    reg [31:0] ex_wb_pc;

    reg [31:0] ex_wb_alu_res;
    reg [31:0] ex_wb_raddr;
    reg [3:0] ex_wb_wmask;
    reg [31:0] ex_wb_wrdata;

    always @(posedge clk) begin
        if(rst) begin
            wbu_valid <= 1'b0;
            wbu_ready <= 1'b0;
        end
        else begin
            wbu_ready <= 1'b1;
            if(exu_valid && wbu_ready) begin
                wbu_valid <= !valid;

                ex_wb_branch_type <= branch_type;
                ex_wb_mem_width <= mem_width;
                ex_wb_mem_wen <= mem_wen;
                ex_wb_valid <= valid;
                ex_wb_wb_sel <= wb_sel;
                ex_wb_csr_write_set <= csr_write_set;

                ex_wb_ext_imm <= ext_imm;
                ex_wb_data_reg1 <= data_reg1;
                ex_wb_csr_out <= csr_out;
                ex_wb_mepc <= mepc;
                ex_wb_mtvec <= mtvec;
                ex_wb_pc <= pc;

                ex_wb_alu_res <= alu_res;
                ex_wb_raddr <= raddr;
                ex_wb_wmask <= wmask;
                ex_wb_wrdata <= wrdata;

            end else if (rready && rvalid || bready && bvalid) begin
                wbu_valid <= 1'b1;
                ex_wb_valid <= 1'b0;
            end else begin
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

    // For Difftest
    wire sram_access = ex_wb_raddr >= 32'h0f000000 && ex_wb_raddr < 32'h0f000000 + 32'h00002000;
    wire sdram_access = ex_wb_raddr >= 32'ha0000000 && ex_wb_raddr < 32'hbfffffff;
    // Output logic
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            rready <= 1'b0;
            bready <= 1'b0;
            arvalid <= 1'b0;
            awvalid <= 1'b0;
            wvalid <= 1'b0;
            // Set default values for AXI signals
            arid <= `AXI_DEFAULT_ID;
            arlen <= `AXI_DEFAULT_LEN;
            arsize <= `AXI_DEFAULT_SIZE;
            arburst <= `AXI_DEFAULT_BURST;
            awid <= `AXI_DEFAULT_ID;
            awlen <= `AXI_DEFAULT_LEN;
            awsize <= `AXI_DEFAULT_SIZE;
            awburst <= `AXI_DEFAULT_BURST;
            wlast <= 1'b1;  // Single transfer
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
                    else if(ex_wb_valid && !ex_wb_mem_wen) begin
                        arvalid <= 1'b1;
                        araddr <= ex_wb_raddr;
                        rready <= 1'b1;
                        arsize <= size;
                    end
                    else if(ex_wb_valid && ex_wb_mem_wen) begin
                        awvalid <= 1'b1;
                        awaddr <= ex_wb_raddr;
                        wvalid <= 1'b1;
                        wdata <= ex_wb_wrdata;
                        wstrb <= ex_wb_wmask[3:0];  // Convert 8-bit to 4-bit
                        bready <= 1'b1;
                        awsize <= size;
                    end
                end

                // TODO: Need to latch resp
                READ_WAIT: begin
                    if(rready && rvalid) begin
                        rready <= 1'b0;
                        arvalid <= 1'b0;
                        rdata_latch <= rdata;
                        rresp_latch <= rresp;
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

    wire [7:0] lb_data = (ex_wb_raddr[1:0] == 2'b00) ? rdata_latch[7:0]  :
         (ex_wb_raddr[1:0] == 2'b01) ? rdata_latch[15:8] :
         (ex_wb_raddr[1:0] == 2'b10) ? rdata_latch[23:16] :
         rdata_latch[31:24];

    wire [15:0] lh_data = (ex_wb_raddr[1:0] == 2'b00) ? rdata_latch[15:0] :
         (ex_wb_raddr[1:0] == 2'b10) ? rdata_latch[31:16] :
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

    // ==================================================================================

    // Calculate whether branch taken and target address

    // ysyx_25020032_MuxKey #(10, 4, 32) next_pc_mux(
    //            branch_target, ex_wb_branch_type, {
    //                JAL,   ex_wb_pc+ex_wb_ext_imm,
    //                JALR,  (ex_wb_data_reg1 + ex_wb_ext_imm)&~1,
    //                BEQ,   ex_wb_pc+ex_wb_ext_imm,
    //                BNE,   ex_wb_pc+ex_wb_ext_imm,
    //                BLT,   ex_wb_pc+ex_wb_ext_imm,
    //                BGE,   ex_wb_pc+ex_wb_ext_imm,
    //                BLTU,  ex_wb_pc+ex_wb_ext_imm,
    //                BGEU,  ex_wb_pc+ex_wb_ext_imm,
    //                ECALL, ex_wb_mtvec,
    //                MRET,  ex_wb_mepc
    //            }
    //        );

    assign branch_target = {32{ex_wb_branch_type == JAL}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == JALR}} & (ex_wb_data_reg1 + ex_wb_ext_imm)&~1 |
                           {32{ex_wb_branch_type == BEQ}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == BNE}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == BLT}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == BGE}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == BLTU}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == BGEU}} & ex_wb_pc+ex_wb_ext_imm |
                           {32{ex_wb_branch_type == ECALL}} & ex_wb_mtvec |
                           {32{ex_wb_branch_type == MRET}} & ex_wb_mepc;

    // ysyx_25020032_MuxKeyWithDefault #(10, 4, 1) branch_taken_mux(
    //                       branch_taken, ex_wb_branch_type, 0, {
    //                           BEQ,   ex_wb_alu_res == 0,
    //                           BNE,   ex_wb_alu_res!= 0,
    //                           BLT,   ex_wb_alu_res == 1,
    //                           BGE,   ex_wb_alu_res!= 1,
    //                           BLTU,  ex_wb_alu_res == 1,
    //                           BGEU,  ex_wb_alu_res!= 1,
    //                           JAL,   1'b1,
    //                           JALR,  1'b1,
    //                           ECALL, 1'b1,
    //                           MRET,  1'b1
    //                       }
    //                   );

    assign branch_taken = {1{ex_wb_branch_type == BEQ}} & (ex_wb_alu_res == 0) |
                         {1{ex_wb_branch_type == BNE}} & (ex_wb_alu_res != 0) |
                         {1{ex_wb_branch_type == BLT}} & (ex_wb_alu_res == 1) |
                         {1{ex_wb_branch_type == BGE}} & (ex_wb_alu_res != 1) |
                         {1{ex_wb_branch_type == BLTU}} & (ex_wb_alu_res == 1) |
                         {1{ex_wb_branch_type == BGEU}} & (ex_wb_alu_res != 1) |
                         {1{ex_wb_branch_type == JAL}} & 1'b1 |
                         {1{ex_wb_branch_type == JALR}} & 1'b1 |
                         {1{ex_wb_branch_type == ECALL}} & 1'b1 |
                         {1{ex_wb_branch_type == MRET}} & 1'b1;

`ifndef SYNTHESIS   
    function automatic int wbu_skip();
        wbu_skip = {31'b0, !(state == IDLE && wbu_valid == 1'b1)};
    endfunction

    export "DPI-C" function wbu_skip;
`endif
endmodule
/* verilator lint_on UNUSEDSIGNAL */
