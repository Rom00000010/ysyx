module Simple_Arbiter(
    // ... existing code ...

    // State encoding - we don't need complex arbitration since accesses are not simultaneous
    localparam IDLE = 3'd0;
    localparam IFU_READ = 3'd1;
    localparam WBU_READ = 3'd2;
    localparam WBU_WRITE = 3'd3;

    reg [2:0] state, next_state;

    // Sequential state logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            // Reset all output registers
            ifu_arready <= 0;
            ifu_rvalid <= 0;
            ifu_rdata <= 0;
            ifu_rresp <= 0;
            
            wbu_arready <= 0;
            wbu_awready <= 0;
            wbu_wready <= 0;
            wbu_bvalid <= 0;
            wbu_bresp <= 0;
            wbu_rvalid <= 0;
            wbu_rdata <= 0;
            wbu_rresp <= 0;

            mem_arvalid <= 0;
            mem_araddr <= 0;
            mem_rready <= 0;
            mem_awvalid <= 0;
            mem_awaddr <= 0;
            mem_wvalid <= 0;
            mem_wdata <= 0;
            mem_wstrb <= 0;
            mem_bready <= 0;
        end else begin
            state <= next_state;
            
            // Default: clear all ready/valid signals unless explicitly set
            ifu_arready <= 0;
            ifu_rvalid <= 0;
            wbu_arready <= 0;
            wbu_awready <= 0;
            wbu_wready <= 0;
            wbu_bvalid <= 0;
            wbu_rvalid <= 0;
            mem_arvalid <= 0;
            mem_awvalid <= 0;
            mem_wvalid <= 0;
            mem_rready <= 0;
            mem_bready <= 0;

            case (state)
                IDLE: begin
                    // In IDLE, we're ready to accept any request
                    ifu_arready <= 1;
                    wbu_arready <= 1;
                    wbu_awready <= 1;
                end

                IFU_READ: begin
                    // Handle instruction fetch read
                    mem_arvalid <= 1;
                    mem_araddr <= ifu_araddr;
                    mem_rready <= ifu_rready;
                    ifu_rvalid <= mem_rvalid;
                    ifu_rdata <= mem_rdata;
                    ifu_rresp <= mem_rresp;
                end

                WBU_READ: begin
                    // Handle data read
                    mem_arvalid <= 1;
                    mem_araddr <= wbu_araddr;
                    mem_rready <= wbu_rready;
                    wbu_rvalid <= mem_rvalid;
                    wbu_rdata <= mem_rdata;
                    wbu_rresp <= mem_rresp;
                end

                WBU_WRITE: begin
                    // Handle data write
                    mem_awvalid <= 1;
                    mem_awaddr <= wbu_awaddr;
                    mem_wvalid <= wbu_wvalid;
                    mem_wdata <= wbu_wdata;
                    mem_wstrb <= wbu_wstrb;
                    wbu_wready <= mem_wready;
                    mem_bready <= wbu_bready;
                    wbu_bvalid <= mem_bvalid;
                    wbu_bresp <= mem_bresp;
                end
            endcase
        end
    end

    // Next state combinational logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                // Priority: WBU write > WBU read > IFU read
                if (wbu_awvalid)
                    next_state = WBU_WRITE;
                else if (wbu_arvalid)
                    next_state = WBU_READ;
                else if (ifu_arvalid)
                    next_state = IFU_READ;
            end
            
            IFU_READ: begin
                if (mem_rvalid && ifu_rready)
                    next_state = IDLE;
            end
            
            WBU_READ: begin
                if (mem_rvalid && wbu_rready)
                    next_state = IDLE;
            end
            
            WBU_WRITE: begin
                if (mem_bvalid && wbu_bready)
                    next_state = IDLE;
            end
        endcase
    end

endmodule 