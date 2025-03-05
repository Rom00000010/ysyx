module WBU(
    input clk,

    input valid,
    input mem_wen,
    input [2:0]mem_width,
    input Branch branch,
    input [1:0]write_src,

    input [31:0]alu_res,
    input [31:0]data_reg2,
    input [31:0]data_reg1,
    input [31:0]pc_val,
    input [31:0]ext_imm,
    input [31:0]mepc,
    input [31:0]mtvec,
    input [31:0]csr_out,

    output [31:0]next_pc,
    output [31:0]wdata_regd,
    output [31:0]csr_in
);

    // Memory write
    wire [31:0] waddr = alu_res;
    wire [31:0] wdata = data_reg2;

    // Generate wmask based on which part of the 4 bytes need to write
    wire [7:0] wmask;
    wire [7:0] sb_mask = (8'b00000001 << waddr[1:0]);
    wire [7:0] sh_mask = (waddr[1:0] == 2'b00) ? 8'b00000011 : 
                    (waddr[1:0] == 2'b10) ? 8'b00001100 : 
                    8'b00000000; 
                    
    wire [7:0] sw_mask = 8'b00001111;

    MuxKey #(3, 3, 8) wmask_mux(
        wmask, mem_width, {
            3'b000, sb_mask,
            3'b001, sh_mask,
            3'b010, sw_mask
        }
    );

    // Asyn read/write for now (need to configure for difftest IO), filter illegal access when mtrace
    always @(*) begin
        if (valid != 1'b0) begin // 有读写请求时
            rdata = pmem_read(raddr);
            if (mem_wen && clk == 1'b0) begin // 有写请求时
            pmem_write(waddr, wdata, wmask);
            end
        end
        else begin
            rdata = 0;
        end
    end

    // Memory read, Extract data from 4 bytes based on address
    reg [31:0] rdata;
    wire [31:0] raddr = alu_res;
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

    // Update pc
    wire [31:0]snpc = pc_val + 32'd4;

    wire [31:0]lt_triggered = (alu_res == 1) ? pc_val+ext_imm : snpc;
    wire [31:0]lt_untriggered = (alu_res != 1) ? pc_val+ext_imm : snpc;
    wire [31:0]triggered = (alu_res == 0) ? pc_val+ext_imm : snpc;
    wire [31:0]untriggered = (alu_res != 0) ? pc_val+ext_imm : snpc;

    MuxKey #(11, 4, 32) next_pc_mux(
        next_pc, branch, {
            NO,    snpc,
            JAL,   pc_val + ext_imm,
            JALR,  (data_reg1 + ext_imm)&~1,
            BEQ,   triggered,
            BNE,   untriggered,
            BLT,   lt_triggered,
            BGE,   lt_untriggered,
            BLTU,  lt_triggered, 
            BGEU,  lt_untriggered,
            ECALL, mtvec,
            MRET,  mepc
        }
    );

    // Reg Write
    wire [31:0] link_alu_csr;
    MuxKey #(3,2,32) write_data_mux(
        link_alu_csr, write_src, {
            2'b00, alu_res,
            2'b01, snpc,   // jal&jalr
            2'b10, csr_out  // csr
        }
    );

    // not optimal encode
    MuxKey #(2, 1, 32) wdata_regd_mux(
        wdata_regd, valid, {
            1'b0, link_alu_csr,
            1'b1, mask_data // lw result
        }
    );

    // mem_width actually is func3, distinguish csrrw/csrrs 
    assign csr_in = (mem_width == 3'b010) ? data_reg1 | csr_out : data_reg1;

endmodule
