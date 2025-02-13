`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
import "DPI-C" function void set_finish ();
import "DPI-C" function int pmem_read(input int raddr);
import "DPI-C" function void pmem_write(input int waddr, input int wdata, input byte wmask);

module top (
        input clk,
        input rst);

    // PC signal
    wire [31:0]snpc;
    wire [31:0]next_pc;
    wire [31:0]pc_val;
    reg [31:0]instr;

    // Control signal
    InstrType imm_src;
    AluCtrl alu_ctrl;
    wire [1:0]alu_srca;
    wire alu_srcb;
    Branch branch;
    wire reg_write;
    wire write_src;
    wire mem_wen;

    // Operand
    wire [31:0]data_reg1, data_reg2, wdata_regd;
    wire [31:0]ext_imm;

    // PC register
    Reg #( .WIDTH(32), .RESET_VAL(32'h80000000) ) pc (
            .clk(clk), .rst(rst),
            .din(next_pc), .dout(pc_val), .wen(1'b1)
        );

    // fetch instruction
    always @(*) begin
        instr = pmem_read(pc_val);
    end

    // ebreak: stop similation
    always begin
        if(instr == 32'h00100073)
            set_finish();
    end

    // extract operand & opcode/func
    wire [3:0] rs1 = instr[18:15];
    wire [3:0] rs2 = instr[23:20];
    wire [3:0] rd = instr[10:7];
    wire [2:0] func3 = instr[14:12];
    wire func7 = instr[30];
    wire [6:0] opcode = instr[6:0];

    CtrlUnit ctrl (.opcode(opcode), .func3(func3), .func7(func7), .imm_src(imm_src), .reg_write(reg_write), .branch(branch), .alu_ctrl(alu_ctrl), .alu_srca(alu_srca), .alu_srcb(alu_srcb), .write_src(write_src), .mem_wen(mem_wen));

    Ext extender (.imm_src(imm_src), .instr(instr), .imm(ext_imm));

    RegisterFile #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) regfile (
                    .clk(clk), .wdata(wdata_regd), .rst(rst),
                    .waddr(rd), .raddr1(rs1), .rdata1(data_reg1),
                    .raddr2(rs2), .rdata2(data_reg2), .wen(reg_write)
                );

    wire [31:0]opl;
    MuxKey #(3, 2, 32) op1 (
                opl, alu_srca,{
                    2'b00, data_reg1,
                    2'b01, 32'b0,
                    2'b10, pc_val                                   
                }
            );

    wire [31:0]opr;
    MuxKey #(2, 1, 32) op2 (
                opr, alu_srcb, {
                    1'b0, data_reg2,
                    1'b1, ext_imm
                }
            );

    wire [31:0]alu_res;
    Alu alu(.alu_ctrl(alu_ctrl), .a(opl), .b(opr), .result(alu_res));

    // Memory access 
    reg [31:0] rdata;

    wire valid = ((opcode == 7'b0000011) || (opcode == 7'b0100011));
    wire [31:0] raddr = alu_res;
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
        wmask, func3, {
            3'b000, sb_mask,
            3'b001, sh_mask,
            3'b010, sw_mask
        }
    );

    // Asyn read/write for now, filter illegal access when mtrace
    always @(*) begin
        if (valid != 1'b0) begin // 有读写请求时
            rdata = pmem_read(raddr);
            if (mem_wen) begin // 有写请求时
            pmem_write(waddr, wdata, wmask);
            end
        end
        else begin
            rdata = 0;
        end
    end

        // Extract data from 4 bytes based on address
    wire [31:0] mask_data;

    wire [7:0] lb_data = (raddr[1:0] == 2'b00) ? rdata[7:0]  :
                    (raddr[1:0] == 2'b01) ? rdata[15:8] :
                    (raddr[1:0] == 2'b10) ? rdata[23:16] :
                                            rdata[31:24];

    wire [15:0] lh_data = (raddr[1:0] == 2'b00) ? rdata[15:0] :
                    (raddr[1:0] == 2'b10) ? rdata[31:16] :
                                            16'b0;

    MuxKey #(5, 3, 32) mask_data_mux(
        mask_data, func3, {
            3'b000, {{24{lb_data[7]}}, lb_data}, 
            3'b001, {{16{lh_data[15]}}, lh_data},
            3'b010, rdata,                    
            3'b100, {{24{1'b0}}, lb_data}, 
            3'b101, {{16{1'b0}}, lh_data}  
        }
    );

    // Update pc
    assign snpc = pc_val + 32'd4;

    wire [31:0]lt_triggered = (alu_res == 1) ? pc_val+ext_imm : snpc;
    wire [31:0]lt_untriggered = (alu_res != 1) ? pc_val+ext_imm : snpc;
    wire [31:0]triggered = (alu_res == 0) ? pc_val+ext_imm : snpc;
    wire [31:0]untriggered = (alu_res != 0) ? pc_val+ext_imm : snpc;

    MuxKey #(9, 4, 32) next_pc_mux(
        next_pc, branch, {
            NO, snpc,
            JAL, pc_val + ext_imm,
            JALR, (data_reg1 + ext_imm)&~1,
            BEQ, triggered,
            BNE, untriggered,
            BLT, lt_triggered,
            BGE, lt_untriggered,
            BLTU, lt_triggered, 
            BGEU, lt_untriggered
        }
    );

    // Reg Write
    wire [31:0] link_or_alu;
    MuxKey #(2,1,32) write_data_mux(
        link_or_alu, write_src, {
            1'b0, alu_res,
            1'b1, snpc   // jal&jalr
        }
    );

    // not optimal encode
    MuxKey #(2, 1, 32) wdata_regd_mux(
        wdata_regd, valid, {
            1'b0, link_or_alu,
            1'b1, mask_data // lw result
        }
    );

    function automatic int get_dnpc();
        get_dnpc = next_pc;
    endfunction

    function automatic int get_instr();
        get_instr = instr;
    endfunction

    function automatic int get_pc_val();
        get_pc_val = pc_val;
    endfunction

    export "DPI-C" function get_dnpc;
    export "DPI-C" function get_instr;
    export "DPI-C" function get_pc_val;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
