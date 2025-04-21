`include "axi_interface.vh"
module ysyx_25020032_Icache(
    input clk,
    input rst,

    // Icache->IFU synchronization
    input icache_valid,
    output icache_ready,
    input [31:0] pc,
    output [31:0] instr,

    // Icache->AXI synchronization
    `AXI_MASTER_READ_ADDR_PORTS
);

`ifdef CACHE_EVENT
    reg [31:0] miss_cnt;
    reg [31:0] wait_cnt;

    initial begin
        miss_cnt = 32'h0;
        wait_cnt = 32'h0;
    end
`endif

    // Cache definition
    reg [31:0] cache[0:15];
    reg [25:0] tag[0:15];
    reg valid[0:15];

    // If request, extract cache index/tag and check whether hit
    wire [3:0] cache_index = pc[5:2];
    wire [25:0] cache_tag = pc[31:6];
    wire hit = valid[cache_index] && (tag[cache_index] == cache_tag);

    // Assign cache data to output, addr from input
    assign instr = hit ? cache[cache_index] : 32'h0;
    always@(*) begin araddr = pc; end

    // Handshake signal
    assign icache_ready = icache_valid && hit ? 1'b1 : 1'b0;

// ======================State Machine======================
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
            // Stay at IDLE if no request or hit
            IDLE: begin
                if(icache_valid && !hit) begin
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

// ======================Output Logic=======================
    
    always @(posedge clk) begin
        // Reset to known state, initialize handshake signals
        if(rst) begin
            arvalid <= 1'b0;
            rready <= 1'b0;
            arid <= `AXI_DEFAULT_ID;
            arlen <= `AXI_DEFAULT_LEN;
            arsize <= `AXI_DEFAULT_SIZE;
            arburst <= `AXI_DEFAULT_BURST;

            for(integer i = 0; i < 16; i = i + 1) begin
                valid[i] <= 1'b0;
            end
        end
        else begin
            case (state)
                IDLE: begin
                    if(icache_valid && !hit) begin
                        arvalid <= 1'b1;
                        rready <= 1'b1;

                        `ifdef CACHE_EVENT
                            miss_cnt <= miss_cnt + 1;
                            wait_cnt <= wait_cnt + 1;
                        `endif
                    end
                end
                FETCH: begin
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                    end

                    `ifdef CACHE_EVENT
                        wait_cnt <= wait_cnt + 1;
                    `endif
                end
                WAIT: begin
                    if(rvalid && rready) begin
                        cache[cache_index] <= rdata;
                        tag[cache_index] <= cache_tag;
                        valid[cache_index] <= 1'b1;

                        rready <= 1'b0;
                    end

                    `ifdef CACHE_EVENT
                        wait_cnt <= wait_cnt + 1;
                    `endif
                end
                default: begin
                end
            endcase
        end
    end
endmodule
