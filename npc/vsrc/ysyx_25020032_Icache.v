module ysyx_25020032_Icache(
    input clk,
    input rst,

    input addr_valid,
    output addr_ready,
    output cache_valid,
    input cache_ready,

    input [31:0] pc,
    input [31:0] instr,

    `AXI_MASTER_READ_ADDR_PORTS
);
    // Cache definition
    reg [31:0] cache[0:15];
    reg [25:0] tag[0:15];
    reg valid[0:15];

    // Extract cache index and tag, and check hit
    wire [3:0] cache_index = pc[5:2];
    wire [25:0] cache_tag = pc[31:6];
    wire hit = valid[cache_index] && (tag[cache_index] == cache_tag);

    // Assign cache data to output(if hit), or fetch from memory
    assign instr = hit ? cache[cache_index] : instr_latch;

    // Handshake signal
    assign cache_valid = hit ? 1'b1 : cache_valid_latch;
    assign addr_ready = 1'b1;

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

    reg cache_valid_latch;
    reg [31:0] instr_latch;
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
            cache_valid_latch <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    cache_valid_latch <= 1'b0;
                    if(addr_valid && addr_ready && !hit) begin
                        arvalid <= 1'b1;
                        araddr <= pc;
                        rready <= 1'b1;
                    end
                end
                FETCH: begin
                    if(arvalid && arready) begin
                        arvalid <= 1'b0;
                        rready <= 1'b1;
                    end
                end
                WAIT: begin
                    if(rvalid && rready) begin
                        instr_latch <= rdata;
                        cache[cache_index] <= rdata;
                        tag[cache_index] <= cache_tag;
                        valid[cache_index] <= 1'b1;

                        cache_valid_latch <= 1'b1;
                        rready <= 1'b0;
                    end
                end
                default: begin
                    arvalid <= 1'b0;
                    rready <= 1'b0;
                    cache_valid_latch <= 1'b0;
                end
            endcase
        end
    end
endmodule
