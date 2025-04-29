`include "common.vh"
module ysyx_25020032_IDU(
        input clk,
        input rst,

        // IFU->IDU synchronization
        input ifu_valid,
        output reg idu_ready,
        input [31:0]instr,
        input [31:0]pc,

        // if-id pipeline register, store pc for later exu/wbu
        output reg [31:0]if_id_pc,
        // for monitors
        output reg [31:0]if_id_instr,


        // IDU->EXU synchronization
        output reg idu_valid,
        input exu_ready,

        // Control logic
        output AluCtrl alu_ctrl,
        output [1:0]alu_srca,
        output [1:0]alu_srcb,
        output Branch branch_type,
        output [2:0]mem_width,
        output mem_wen,
        output valid,
        output [1:0]wb_sel,
        output csr_write_set,
        output csr_wen,
        output ecall,
        output [31:0] mcause,
        output reg_write,

        // Datapath
        output [31:0]ext_imm,
        output [31:0]data_reg1,
        output [31:0]data_reg2,
        output [3:0]rd,

        // WBU->IDU synchronization
        input wbu_valid,
        input [31:0]wdata_regd,
        input ex_wb_reg_write,
        input [3:0]ex_wb_rd,

        // RAW detection
        input exu_valid,
        input wbu_proc_instr,
        input id_ex_reg_write,
        input [3:0]id_ex_rd,

        // Pipeline flush
        input flush
    );

`ifdef DECODE_EVENT
    reg [31:0] compute_instr_cnt;
    reg [31:0] memory_instr_cnt;
    reg [31:0] csr_instr_cnt;
    reg [31:0] branch_instr_cnt;
    reg [31:0] load_instr_cnt;
    reg [31:0] store_instr_cnt;
    initial begin
        compute_instr_cnt = 0;
        memory_instr_cnt = 0;
        csr_instr_cnt = 0;
        branch_instr_cnt = 0;
        load_instr_cnt = 0;
        store_instr_cnt = 0;
    end

    always @(posedge clk) begin
        if(idu_valid && exu_ready) begin
            if(opcode == 7'b0010011 || opcode == 7'b0110011 || opcode == 7'b0110111 || opcode == 7'b0010111) begin  
                compute_instr_cnt <= compute_instr_cnt + 1;
            end
            if(opcode == 7'b0100011 || opcode == 7'b0000011) begin
                memory_instr_cnt <= memory_instr_cnt + 1;
            end
            if(opcode == 7'b1110011) begin
                csr_instr_cnt <= csr_instr_cnt + 1;
            end
            if(opcode == 7'b1100011 || opcode == 7'b1101111 || opcode == 7'b1100111) begin
                branch_instr_cnt <= branch_instr_cnt + 1;
            end
            if(opcode == 7'b0000011) begin
                load_instr_cnt <= load_instr_cnt + 1;
            end
            if(opcode == 7'b0100011) begin
                store_instr_cnt <= store_instr_cnt + 1;
            end
        end
    end
`endif
    
    reg idu_valid_noraw;
    always @(posedge clk) begin
        if(rst) begin
            idu_valid_noraw <= 1'b0;
        end
        else begin
            if(flush) begin
                idu_valid_noraw <= 1'b0;
            end
            else if(ifu_valid && idu_ready) begin
                idu_valid_noraw <= 1'b1;
                if_id_pc <= pc;
                if_id_instr <= instr;
            end
            else if(idu_valid && exu_ready) begin
                idu_valid_noraw <= 1'b0;
            end
        end
    end

    assign idu_valid = idu_valid_noraw && !isRAW && !flush;

    reg isRAW;
    reg raw_with_exu;
    reg raw_with_wbu;

    always @* begin
        isRAW = 1'b0;
        raw_with_exu = 1'b0;
        raw_with_wbu = 1'b0;
        unique case (instr_type)
            I_TYPE:begin 
                if(ecall || rs1 == 0)begin
                    isRAW = 1'b0;
                end
                else begin
                    raw_with_exu = exu_valid && id_ex_reg_write && id_ex_rd == rs1;
                    raw_with_wbu = wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs1;
                    isRAW = raw_with_exu || raw_with_wbu;
                end
            end 
            R_TYPE:begin
                if(rs1 == 0 && rs2 == 0)begin
                    isRAW = 1'b0;
                end
                else begin
                    raw_with_exu = exu_valid && id_ex_reg_write && id_ex_rd == rs1 || exu_valid && id_ex_reg_write && id_ex_rd == rs2;
                    raw_with_wbu = wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs1 || wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs2;
                    isRAW = raw_with_exu || raw_with_wbu;
                end
            end
            S_TYPE:begin                 
                if(rs1 == 0 && rs2 == 0)begin
                    isRAW = 1'b0;
                end
                else begin
                    raw_with_exu = exu_valid && id_ex_reg_write && id_ex_rd == rs1 || exu_valid && id_ex_reg_write && id_ex_rd == rs2;
                    raw_with_wbu = wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs1 || wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs2;
                    isRAW = raw_with_exu || raw_with_wbu;
                end end
            B_TYPE:begin 
                if(rs1 == 0 && rs2 == 0)begin
                    isRAW = 1'b0;
                end
                else begin
                    raw_with_exu = exu_valid && id_ex_reg_write && id_ex_rd == rs1 || exu_valid && id_ex_reg_write && id_ex_rd == rs2;
                    raw_with_wbu = wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs1 || wbu_proc_instr && ex_wb_reg_write && ex_wb_rd == rs2;
                    isRAW = raw_with_exu || raw_with_wbu;
                end
            end
            U_TYPE:begin isRAW = 1'b0; end
            J_TYPE:begin isRAW = 1'b0; end
        endcase
    end

    assign idu_ready = exu_ready && idu_valid_noraw && !isRAW || !idu_valid_noraw;

    // Extract instruction fields
    wire [2:0] func3 = if_id_instr[14:12];
    wire [11:0] func12 = if_id_instr[31:20];
    wire func7 = if_id_instr[30];
    wire [6:0] opcode = if_id_instr[6:0];

    // Special signal for load, store, ecall or mret
    assign valid = ((opcode == 7'b0000011) || (opcode == 7'b0100011));
    assign mem_width = func3;
    assign ecall = opcode == 7'b1110011 && func3 == 3'b0 && func12 == 12'h000;
    wire mret  = opcode == 7'b1110011 && func3 == 3'b0 && func12 == 12'h302;

    // Extend immediate
    wire shamt = (opcode == 7'b0010011) && (func3 == 3'b101 || func3 == 3'b001);

    ysyx_25020032_Ext extender (.imm_src(imm_src), .instr(if_id_instr), .shamt(shamt), .imm(ext_imm));

    // Fetch Operand
    wire [3:0] rs1 = if_id_instr[18:15];
    wire [3:0] rs2 = if_id_instr[23:20];
    assign rd = if_id_instr[10:7];

    ysyx_25020032_RegisterFile #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) regfile (
                     .clk(clk), .rst(rst),
                     .wdata(wdata_regd), .waddr(ex_wb_rd),
                     .raddr1(rs1), .rdata1(data_reg1),
                     .raddr2(rs2), .rdata2(data_reg2),
                     .wen(ex_wb_reg_write && wbu_valid)
                 );

    // Exception handling
    assign mcause = ecall ? 32'd11 : 32'd0;
    assign csr_write_set = (func3 == 3'b010);

    // Decode control signal

    InstrType instr_type;
    // ysyx_25020032_MuxKey #(10,7,3) instr_type_mux(
    //            instr_type, opcode, {
    //                7'b0110111, U_TYPE, // U-type lui
    //                7'b0110011, R_TYPE, // R-type arithmetic
    //                7'b0100011, S_TYPE, // S-type sw
    //                7'b0010011, I_TYPE, // I-type arithmetic
    //                7'b0010111, U_TYPE, // U-type auipc
    //                7'b1101111, J_TYPE, // J-type jal
    //                7'b1100111, I_TYPE, // I-type jalr
    //                7'b1100011, B_TYPE,
    //                7'b0000011, I_TYPE, // I-type lw
    //                7'b1110011, I_TYPE  // I-type system instr
    //            }
    //        );

    assign instr_type = InstrType'({3{opcode == 7'b0110111}} & U_TYPE |
                        {3{opcode == 7'b0110011}} & R_TYPE |
                        {3{opcode == 7'b0100011}} & S_TYPE |
                        {3{opcode == 7'b0010011}} & I_TYPE |
                        {3{opcode == 7'b0010111}} & U_TYPE |
                        {3{opcode == 7'b1101111}} & J_TYPE |
                        {3{opcode == 7'b1100111}} & I_TYPE |
                        {3{opcode == 7'b1100011}} & B_TYPE |
                        {3{opcode == 7'b0000011}} & I_TYPE |
                        {3{opcode == 7'b1110011}} & I_TYPE);

    // Extend imm based on instruction type
    InstrType imm_src = instr_type;

    // Itype: lw(add for address), I/R type arithmetic, jalr/csrrw(don't use alu to calculate)
    wire [3:0]srial = (func3==3'b101)? {func7, func3} : {1'b0, func3};
    wire [3:0]itype_ctrl = (opcode==7'b0000011) ? 4'b0000 : srial;

    // Btype: reuse alu to calculate signal
    wire [3:0]btype_ctrl;
    // ysyx_25020032_MuxKey #(6, 4, 4) btype_ctrl_mux(
    //            btype_ctrl, btype_branch, {
    //                BEQ,  SUB,
    //                BNE,  SUB,
    //                BLT,  LESS,
    //                BGE,  LESS,
    //                BLTU, LESSU,
    //                BGEU, LESSU
    //            }
    //        );

    assign btype_ctrl = AluCtrl'({4{btype_branch == BEQ}} & SUB |
                        {4{btype_branch == BNE}} & SUB |
                        {4{btype_branch == BLT}} & LESS |
                        {4{btype_branch == BGE}} & LESS |
                        {4{btype_branch == BLTU}} & LESSU |
                        {4{btype_branch == BGEU}} & LESSU);


    // ysyx_25020032_MuxKey #(5,3,4) alu_ctrl_mux(
    //            alu_ctrl, instr_type, {
    //                U_TYPE, ADD,
    //                I_TYPE, itype_ctrl,
    //                R_TYPE, {func7,func3},// arithmetic
    //                B_TYPE, btype_ctrl,   // branch condition
    //                S_TYPE, ADD           // address
    //            }
    //        );

    assign alu_ctrl = AluCtrl'({4{instr_type == U_TYPE}} & ADD |
                      {4{instr_type == I_TYPE}} & itype_ctrl |
                      {4{instr_type == R_TYPE}} & {func7,func3} |
                      {4{instr_type == B_TYPE}} & btype_ctrl |
                      {4{instr_type == S_TYPE}} & ADD);

    // lui & auipc special case
    wire [1:0] utype_srca = (opcode == 7'b0110111) ? 2'b01 : 2'b10;

    // J-type don't use alu
    // ysyx_25020032_MuxKey #(5,3,2) alu_srca_mux(
    //            alu_srca, instr_type, {
    //                I_TYPE, 2'b00,   // rs1
    //                R_TYPE, 2'b00,   // rs1
    //                B_TYPE, 2'b00,   // rs1
    //                U_TYPE, utype_srca,  // zero / pc
    //                S_TYPE, 2'b00    // rs1
    //            }
    //        );

    assign alu_srca = {2{instr_type == I_TYPE}} & 2'b00 |
                      {2{instr_type == R_TYPE}} & 2'b00 |
                      {2{instr_type == B_TYPE}} & 2'b00 |
                      {2{instr_type == U_TYPE}} & utype_srca |
                      {2{instr_type == S_TYPE}} & 2'b00;

    wire shamtr_srcb = (opcode == 7'b0110011 && (func3 == 3'b101 || func3 == 3'b001));
    // ysyx_25020032_MuxKey #(5,3,2) alu_srcb_mux(
    //            alu_srcb, instr_type, {
    //                R_TYPE, shamtr_srcb ? 2'b10 : 2'b00,
    //                B_TYPE, 2'b0, // rs2
    //                I_TYPE, 2'b1, // imm
    //                U_TYPE, 2'b1, // imm
    //                S_TYPE, 2'b1  // imm
    //            }
    //        );

    assign alu_srcb = {2{instr_type == R_TYPE}} & (shamtr_srcb ? 2'b10 : 2'b00) |
                      {2{instr_type == B_TYPE}} & 2'b0 |
                      {2{instr_type == I_TYPE}} & 2'b1 |
                      {2{instr_type == U_TYPE}} & 2'b1 |
                      {2{instr_type == S_TYPE}} & 2'b1;

    // ecall/mret instr don't write register
    wire itype_reg_write = (ecall || mret) ? 1'b0 : 1'b1;

    // ysyx_25020032_MuxKey #(6,3,1) reg_write_mux(
    //            reg_write, instr_type, {
    //                I_TYPE, itype_reg_write,
    //                R_TYPE, 1'b1,
    //                S_TYPE, 1'b0,
    //                U_TYPE, 1'b1,
    //                J_TYPE, 1'b1,
    //                B_TYPE, 1'b0
    //            }
    //        );

    assign reg_write = {1{instr_type == I_TYPE}} & itype_reg_write |
                       {1{instr_type == R_TYPE}} & 1'b1 |
                       {1{instr_type == S_TYPE}} & 1'b0 |
                       {1{instr_type == U_TYPE}} & 1'b1 |
                       {1{instr_type == J_TYPE}} & 1'b1 |
                       {1{instr_type == B_TYPE}} & 1'b0;

    Branch btype_branch;
    // ysyx_25020032_MuxKey #(6, 3, 4) btype_mux(
    //            btype_branch, func3, {
    //                3'b000, BEQ,
    //                3'b001, BNE,
    //                3'b100, BLT,
    //                3'b101, BGE,
    //                3'b110, BLTU,
    //                3'b111, BGEU
    //            }
    //        );

    assign btype_branch = Branch'({4{func3 == 3'b000}} & BEQ |
                          {4{func3 == 3'b001}} & BNE |
                          {4{func3 == 3'b100}} & BLT |
                          {4{func3 == 3'b101}} & BGE |
                          {4{func3 == 3'b110}} & BLTU |
                          {4{func3 == 3'b111}} & BGEU);

    wire [3:0]system_branch = (ecall || mret) ? (ecall ? ECALL : MRET) : NO;

    // ysyx_25020032_MuxKey #(4, 7, 4) branch_mux(
    //            branch_type, opcode, {
    //                7'b1101111, JAL,
    //                7'b1100111, JALR,
    //                7'b1100011, btype_branch,
    //                7'b1110011, system_branch
    //            }
    //        );

    assign branch_type = Branch'({4{opcode == 7'b1101111}} & JAL |
                         {4{opcode == 7'b1100111}} & JALR |
                         {4{opcode == 7'b1100011}} & btype_branch |
                         {4{opcode == 7'b1110011}} & system_branch);

    // ysyx_25020032_MuxKeyWithDefault #(4, 7, 2) wb_sel_mux(
    //                       wb_sel, opcode, 2'b00, {
    //                           7'b1110011, 2'b10,   // csr
    //                           7'b1101111, 2'b01,   // pc+4 for link
    //                           7'b1100111, 2'b01,
    //                           7'b0000011, 2'b11    // load memory
    //                       }
    //                   );

    assign wb_sel = {2{opcode == 7'b1110011}} & 2'b10 |
                    {2{opcode == 7'b1101111}} & 2'b01 |
                    {2{opcode == 7'b1100111}} & 2'b01 |
                    {2{opcode == 7'b0000011}} & 2'b11;

    // ysyx_25020032_MuxKey #(1, 7, 1) mem_wen_mux(
    //            mem_wen, opcode, {
    //                7'b0100011, 1'b1
    //            }
    //        );

    assign mem_wen = {1{opcode == 7'b0100011}} & 1'b1;

    // ysyx_25020032_MuxKey #(1, 7, 1) csr_wen_mux(
    //            csr_wen, opcode, {
    //                7'b1110011, mret? 1'b0 : 1'b1
    //            }
    //        );

    assign csr_wen = {1{opcode == 7'b1110011}} & (mret ? 1'b0 : 1'b1);

endmodule
