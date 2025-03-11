`include "common.vh"
/* verilator lint_off UNUSEDSIGNAL */
module IDU(
        input clk,
        input rst,

        input ifu_valid,
        output reg idu_ready,

        output reg idu_valid,
        input exu_ready,
        input wbu_valid,

        input [31:0]instr,
        input [31:0]pc,
        input [31:0]wdata_regd,
        input [31:0]csr_in,

        output AluCtrl alu_ctrl,
        output [1:0]alu_srca,
        output [1:0]alu_srcb,
        output [1:0]wb_sel,
        output [2:0]mem_width,
        output Branch branch_type,
        output mem_wen,
        output valid,
        output csr_write_set,

        output [31:0]ext_imm,
        output [31:0]data_reg1,
        output [31:0]data_reg2,
        output [31:0]csr_out,
        output [31:0]mepc,
        output [31:0]mtvec,
        output [31:0]pc_handshake
    );

    always @(*) begin
        if(rst) begin
            idu_ready = 1'b0;
            idu_valid = 1'b0;
        end

        else begin
            idu_ready = 1'b1;
            idu_valid = idu_ready && ifu_valid;
        end
    end

    assign pc_handshake = pc;
    wire [31:0]instr_handshake = instr;

    wire [2:0] func3 = instr_handshake[14:12];
    wire [11:0] func12 = instr_handshake[31:20];
    wire func7 = instr_handshake[30];
    wire [6:0] opcode = instr_handshake[6:0];

    // load, store, ecall or mret
    assign valid = ((opcode == 7'b0000011) || (opcode == 7'b0100011));
    assign mem_width = func3;
    wire ecall = opcode == 7'b1110011 && func3 == 3'b0 && func12 == 12'h000;
    wire mret  = opcode == 7'b1110011 && func3 == 3'b0 && func12 == 12'h302;

    // Extend immediate
    wire shamt = (opcode == 7'b0010011) && (func3 == 3'b101 || func3 == 3'b001);

    Ext extender (.imm_src(imm_src), .instr(instr_handshake), .shamt(shamt), .imm(ext_imm));

    // Fetch Operand
    wire [3:0] rs1 = instr_handshake[18:15];
    wire [3:0] rs2 = instr_handshake[23:20];
    wire [3:0] rd = instr_handshake[10:7];

    RegisterFile #(
                     .ADDR_WIDTH(4), .DATA_WIDTH(32)) regfile (
                     .clk(clk), .rst(rst),
                     .wdata(wdata_regd), .waddr(rd),
                     .raddr1(rs1), .rdata1(data_reg1),
                     .raddr2(rs2), .rdata2(data_reg2),
                     .wen(reg_write && wbu_valid && idu_ready)
                 );

    // Exception handling
    wire [31:0]mcause = ecall ? 32'd11 : 32'd0;
    assign csr_write_set = (func3 == 3'b010);

    Csr csr (
            .clk(clk), .rst(rst),
            .addr(ext_imm), .csr_in(csr_in),
            .csr_out(csr_out), .csr_wen(csr_wen && wbu_valid && idu_ready),
            .exception(ecall), .exception_pc(pc_handshake), .exception_cause(mcause),
            .mtvec(mtvec), .mepc(mepc)
        );

    // Decode control signal

    InstrType instr_type;
    MuxKey #(10,7,3) instr_type_mux(
               instr_type, opcode, {
                   7'b0110111, U_TYPE, // U-type lui
                   7'b0110011, R_TYPE, // R-type arithmetic
                   7'b0100011, S_TYPE, // S-type sw
                   7'b0010011, I_TYPE, // I-type arithmetic
                   7'b0010111, U_TYPE, // U-type auipc
                   7'b1101111, J_TYPE, // J-type jal
                   7'b1100111, I_TYPE, // I-type jalr
                   7'b1100011, B_TYPE,
                   7'b0000011, I_TYPE, // I-type lw
                   7'b1110011, I_TYPE  // I-type system instr
               }
           );

    // Extend imm based on instruction type
    InstrType imm_src = instr_type;

    // Itype: lw(add for address), I/R type arithmetic, jalr/csrrw(don't use alu to calculate)
    wire [3:0]srial = (func3==3'b101)? {func7, func3} : {1'b0, func3};
    wire [3:0]itype_ctrl = (opcode==7'b0000011) ? 4'b0000 : srial;

    // Btype: reuse alu to calculate signal
    wire [3:0]btype_ctrl;
    MuxKey #(6, 4, 4) btype_ctrl_mux(
               btype_ctrl, btype_branch, {
                   BEQ,  SUB,
                   BNE,  SUB,
                   BLT,  LESS,
                   BGE,  LESS,
                   BLTU, LESSU,
                   BGEU, LESSU
               }
           );

    MuxKey #(5,3,4) alu_ctrl_mux(
               alu_ctrl, instr_type, {
                   U_TYPE, ADD,
                   I_TYPE, itype_ctrl,
                   R_TYPE, {func7,func3},// arithmetic
                   B_TYPE, btype_ctrl,   // branch condition
                   S_TYPE, ADD           // address
               }
           );

    // lui & auipc special case
    wire [1:0] utype_srca = (opcode == 7'b0110111) ? 2'b01 : 2'b10;

    // J-type don't use alu
    MuxKey #(5,3,2) alu_srca_mux(
               alu_srca, instr_type, {
                   I_TYPE, 2'b00,   // rs1
                   R_TYPE, 2'b00,   // rs1
                   B_TYPE, 2'b00,   // rs1
                   U_TYPE, utype_srca,  // zero / pc
                   S_TYPE, 2'b00    // rs1
               }
           );

    wire shamtr_srcb = (opcode == 7'b0110011 && (func3 == 3'b101 || func3 == 3'b001));
    MuxKey #(5,3,2) alu_srcb_mux(
               alu_srcb, instr_type, {
                   R_TYPE, shamtr_srcb ? 2'b10 : 2'b00,
                   B_TYPE, 2'b0, // rs2
                   I_TYPE, 2'b1, // imm
                   U_TYPE, 2'b1, // imm
                   S_TYPE, 2'b1  // imm
               }
           );

    // ecall/mret instr don't write register
    wire reg_write;
    wire itype_reg_write = (ecall || mret) ? 1'b0 : 1'b1;

    MuxKey #(6,3,1) reg_write_mux(
               reg_write, instr_type, {
                   I_TYPE, itype_reg_write,
                   R_TYPE, 1'b1,
                   S_TYPE, 1'b0,
                   U_TYPE, 1'b1,
                   J_TYPE, 1'b1,
                   B_TYPE, 1'b0
               }
           );

    Branch btype_branch;
    MuxKey #(6, 3, 4) btype_mux(
               btype_branch, func3, {
                   3'b000, BEQ,
                   3'b001, BNE,
                   3'b100, BLT,
                   3'b101, BGE,
                   3'b110, BLTU,
                   3'b111, BGEU
               }
           );

    wire [3:0]system_branch = (ecall || mret) ? (ecall ? ECALL : MRET) : NO;

    MuxKey #(4, 7, 4) branch_mux(
               branch_type, opcode, {
                   7'b1101111, JAL,
                   7'b1100111, JALR,
                   7'b1100011, btype_branch,
                   7'b1110011, system_branch
               }
           );

    MuxKeyWithDefault #(4, 7, 2) wb_sel_mux(
                          wb_sel, opcode, 2'b00, {
                              7'b1110011, 2'b10,   // csr
                              7'b1101111, 2'b01,   // pc+4 for link
                              7'b1100111, 2'b01,
                              7'b0000011, 2'b11    // load memory
                          }
                      );

    MuxKey #(1, 7, 1) mem_wen_mux(
               mem_wen, opcode, {
                   7'b0100011, 1'b1
               }
           );

    wire csr_wen;
    MuxKey #(1, 7, 1) csr_wen_mux(
               csr_wen, opcode, {
                   7'b1110011, mret? 1'b0 : 1'b1
               }
           );

    function automatic int is_mem_read();
        is_mem_read = {31'b0, valid && !mem_wen};
    endfunction

    export "DPI-C" function is_mem_read;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
