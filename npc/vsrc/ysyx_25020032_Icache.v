`include "axi_interface.vh"
module ysyx_25020032_Icache(
    input clk,
    input rst,

    input addr_valid,
    output reg addr_ready,
    output cache_valid,
    input cache_ready,

    input wbu_valid,
    input ifu_ready,

    input [31:0] pc,
    output [31:0] instr,

    `AXI_MASTER_READ_ADDR_PORTS
);
    // Cache definition
    reg [31:0] cache[0:15];
    reg [25:0] tag[0:15];
    reg valid[0:15];

`ifdef CACHE_EVENT
    reg [31:0] hit_cnt;
    reg [31:0] miss_cnt;
    reg [31:0] wait_cnt;

    initial begin
        hit_cnt = 32'h0;
        miss_cnt = 32'h0;
        wait_cnt = 32'h0;
    end
`endif

    // Extract cache index and tag, and check hit
    wire [3:0] cache_index = pc[5:2];
    wire [25:0] cache_tag = pc[31:6];
    wire hit = addr_valid && valid[cache_index] && (tag[cache_index] == cache_tag);

    // Assign cache data to output(if hit), or fetch from memory
    assign instr = hit ? cache[cache_index] : rresp_latch == 2'b00 ? instr_latch : 32'h0;

    // Handshake signal
    assign cache_valid = hit ? 1'b1 : cache_valid_latch;

    localparam IDLE = 2'd0,
               FETCH = 2'd1,
               WAIT = 2'd2;

    reg [1:0] state, next_state;

    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if(addr_valid && addr_ready && !hit) begin
                    next_state = FETCH;
                end
            end
            FETCH: begin
                if(arvalid && arready) begin
                    next_state = WAIT;
                end
            end
            WAIT: begin
                if(rvalid && rready) begin
                    next_state = IDLE;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Instr lifetime is over
    always @(posedge clk) begin
        if(wbu_valid && ifu_ready) begin
            instr_latch <= 32'h0;
        end
    end

    reg cache_valid_latch;
    reg [31:0] instr_latch;
    reg [1:0] rresp_latch;
    always @(posedge clk) begin
        if(rst) begin
            cache_valid_latch <= 1'b0;
            arvalid <= 1'b0;
            rready <= 1'b0;
            arid <= `AXI_DEFAULT_ID;
            arlen <= `AXI_DEFAULT_LEN;
            arsize <= `AXI_DEFAULT_SIZE;
            arburst <= `AXI_DEFAULT_BURST;
            instr_latch <= 32'h0;
            addr_ready <= 1'b0;
        end
        else begin
            addr_ready <= 1'b1;
            case (state)
                IDLE: begin
                    cache_valid_latch <= 1'b0;
                    arvalid <= 1'b0;
                    rready <= 1'b0;
                    if(addr_valid && addr_ready && !hit) begin
                        arvalid <= 1'b1;
                        araddr <= pc;
                        rready <= 1'b1;
                        `ifdef CACHE_EVENT
                            miss_cnt <= miss_cnt + 1;
                            wait_cnt <= wait_cnt + 1;
                        `endif
                    end else if(hit) begin
                        instr_latch <= cache[cache_index];
                        `ifdef CACHE_EVENT
                            hit_cnt <= hit_cnt + 1;
                        `endif
                    end
                end
                FETCH: begin
                    `ifdef CACHE_EVENT
                        wait_cnt <= wait_cnt + 1;
                    `endif
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                        rready <= 1'b1;
                    end
                end
                WAIT: begin
                    `ifdef CACHE_EVENT
                        wait_cnt <= wait_cnt + 1;
                    `endif
                    if(rvalid && rready) begin
                        instr_latch <= rdata;
                        rresp_latch <= rresp;
                        cache[cache_index] <= rdata;
                        tag[cache_index] <= cache_tag;
                        valid[cache_index] <= 1'b1;

                        cache_valid_latch <= 1'b1;
                        rready <= 1'b0;
                    end
                end
                default: begin
                end
            endcase
        end
    end
endmodule
