/* verilator lint_off UNUSEDSIGNAL */
module Sram(
        input clk,
        input rst,

        // Read Address Channel
        input [31:0] araddr,
        input arvalid,
        output reg arready,

        // Read Data Channel
        output reg [31:0] rdata,
        output reg [1:0] rresp,
        output reg rvalid,
        input rready,

        // Write Address Channel
        input [31:0] awaddr,
        input awvalid,
        output reg awready,

        // Write Data Channel
        input [31:0] wdata,
        input [7:0] wstrb,
        input wvalid,
        output reg wready,

        // Write Response Channel
        output reg [1:0] bresp,
        output reg bvalid,
        input bready
    );

    // State encoding
    localparam IDLE = 3'd0;
    localparam READ_EXECUTE = 3'd1;
    localparam READ_RESP = 3'd2;
    localparam WRITE_EXECUTE = 3'd3;
    localparam WRITE_RESP = 3'd4;

    // State register
    reg [2:0] state, next_state;

    reg [31:0] addr_reg;      // Address register
    reg [31:0] wdata_reg;     // Write data register
    reg [7:0] wstrb_reg;      // Write mask register
    reg [3:0] read_delay;     // Read delay register
    reg [3:0] write_delay;
    reg [3:0] addr_delay;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (arvalid && arready && addr_delay == 4'd0) begin
                    next_state = READ_EXECUTE;
                end
                else if (awvalid && wvalid && awready && wready && addr_delay == 4'd0) begin
                    next_state = WRITE_EXECUTE;
                end
            end

            READ_EXECUTE: begin
                if(read_delay == 4'd0) begin
                    next_state = READ_RESP;
                end
            end

            READ_RESP: begin
                if (rready && rvalid) begin
                    next_state = IDLE;
                end
            end

            WRITE_EXECUTE: begin
                if(write_delay == 4'd0)begin
                    next_state = WRITE_RESP;
                end
            end

            WRITE_RESP: begin
                if (bready && bvalid) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic and memory operations
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            arready <= 1'b0;
            awready <= 1'b0;
            wready <= 1'b0;
            rvalid <= 1'b0;
            bvalid <= 1'b0;

            rresp <= 2'b00;
            bresp <= 2'b00;

            addr_reg <= 32'b0;
            wdata_reg <= 32'b0;
            wstrb_reg <= 8'b0;

            read_delay <= 4'b0;
            write_delay <= 4'b0;
            addr_delay <= 4'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    // Ready to accept new transactions
                    arready <= 1'b1;
                    awready <= 1'b1;
                    wready <= 1'b1;
                    rvalid <= 1'b0;
                    bvalid <= 1'b0;

                    if(addr_delay > 4'd0) begin
                        addr_delay <= addr_delay - 4'd1;
                        arready <= 1'b0;
                        awready <= 1'b0;
                        wready <= 1'b0;
                    end
                    // Latch address if read request
                    else if (arvalid && arready) begin
                        read_delay <= 4'd0;
                        addr_reg <= araddr;
                        arready <= 1'b0;
                    end
                    // Latch address and data if write request (simultaneous)
                    else if (awvalid && wvalid && awready && wready) begin
                        addr_reg <= awaddr;
                        wdata_reg <= wdata;
                        wstrb_reg <= wstrb;
                        write_delay <= 4'b0;
                        awready <= 1'b0;
                        wready <= 1'b0;
                    end
                end

                READ_EXECUTE: begin
                    if(read_delay > 4'd0) begin
                        read_delay <= read_delay - 4'd1;
                    end
                    else begin
                        rresp <= 2'b00;
                        rvalid <= 1'b1;
                    end
                end

                READ_RESP: begin
                    if (rready && rvalid) begin
                        rvalid <= 1'b0;
                        addr_delay <= 4'b0;
                    end
                end

                WRITE_EXECUTE: begin
                    if(write_delay > 4'd0) begin
                        write_delay <= write_delay - 4'd1;
                    end
                    else begin
                        // Perform write
                        bresp <= 2'b00;
                        bvalid <= 1'b1;
                    end
                end

                WRITE_RESP: begin
                    if (bready && bvalid) begin
                        bvalid <= 1'b0;
                        addr_delay <= 4'b0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    wire [31:0]trash;
    RegisterFile #(
                     .ADDR_WIDTH(8), .DATA_WIDTH(32)) regfile (
                     .clk(clk), .rst(rst),
                     .wdata(wdata_reg), .waddr(addr_reg[7:0]),
                     .raddr1(addr_reg[7:0]), .rdata1(rdata),
                     .raddr2(8'b0), .rdata2(trash),
                     .wen(rvalid && rready)
                 );

endmodule
/* verilator lint_on UNUSEDSIGNAL */
