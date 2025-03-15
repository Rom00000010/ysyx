module Arbiter(
    input clk,
    input rst,

    // ================ IFU (Instruction Fetch Unit) Channel - Master 0 ================
    // Read Address Channel
    input [31:0] ifu_araddr,       // Read address from IFU
    input ifu_arvalid,             // Read address valid signal from IFU
    output reg ifu_arready,        // Ready to accept read address from IFU
    // Read Data Channel
    output reg [31:0] ifu_rdata,   // Read data to IFU
    output reg [1:0] ifu_rresp,    // Read response to IFU
    output reg ifu_rvalid,         // Read data valid signal to IFU
    input ifu_rready,              // IFU ready to accept read data

    // ================ WBU (Write Back Unit) Channel - Master 1 ================
    // Read Address Channel
    input [31:0] wbu_araddr,      // Read address from WBU
    input wbu_arvalid,            // Read address valid signal from WBU
    output reg wbu_arready,       // Ready to accept read address from WBU
    // Write Address Channel
    input [31:0] wbu_awaddr,      // Write address from WBU
    input wbu_awvalid,            // Write address valid signal from WBU
    output reg wbu_awready,       // Ready to accept write address from WBU
    // Write Data Channel
    input [31:0] wbu_wdata,       // Write data from WBU
    input [7:0] wbu_wstrb,        // Write strobe from WBU
    input wbu_wvalid,             // Write data valid signal from WBU
    output reg wbu_wready,        // Ready to accept write data from WBU
    // Write Response Channel
    output reg wbu_bvalid,        // Write response valid signal to WBU
    output reg [1:0] wbu_bresp,   // Write response to WBU
    input wbu_bready,             // WBU ready to accept write response
    // Read Data Channel
    output reg [31:0] wbu_rdata,  // Read data to WBU
    output reg [1:0] wbu_rresp,   // Read response to WBU
    output reg wbu_rvalid,        // Read data valid signal to WBU
    input wbu_rready,             // WBU ready to accept read data

    // ================ Memory Interface (SRAM) - Slave ================
    // Read Address Channel
    output reg [31:0] mem_araddr,          // Read address to memory
    output reg mem_arvalid,                // Read address valid signal to memory
    input mem_arready,                     // Memory ready to accept read address
    // Read Data Channel
    input [31:0] mem_rdata,                // Read data from memory
    input [1:0] mem_rresp,                 // Read response from memory
    input mem_rvalid,                      // Read data valid signal from memory
    output reg mem_rready,                 // Ready to accept read data from memory
    // Write Address Channel
    output reg [31:0] mem_awaddr,          // Write address to memory
    output reg mem_awvalid,                // Write address valid signal to memory
    input mem_awready,                     // Memory ready to accept write address
    // Write Data Channel
    output reg [31:0] mem_wdata,           // Write data to memory
    output reg [7:0] mem_wstrb,            // Write strobe to memory
    output reg mem_wvalid,                 // Write data valid signal to memory
    input mem_wready,                      // Memory ready to accept write data
    // Write Response Channel
    input [1:0] mem_bresp,                 // Write response from memory
    input mem_bvalid,                      // Write response valid signal from memory
    output reg mem_bready                  // Ready to accept write response from memor
);

    // State encoding
    // TODO: MAYBE NEED MORE STATES(SUCH AS WAITING FOR ADDR HANDSHAKE)
    localparam IDLE = 2'd0;
    localparam IFU_READ = 2'd1;
    localparam WBU_READ = 2'd2;
    localparam WBU_WRITE = 2'd3;

    reg [1:0] state, next_state;
    reg last_grant_ifu; // For round-robin arbitration

    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            last_grant_ifu <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE) begin
                if (next_state == IFU_READ)
                    last_grant_ifu <= 1;
                else if (next_state == WBU_READ || next_state == WBU_WRITE)
                    last_grant_ifu <= 0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (ifu_arvalid && mem_arready && wbu_awvalid && wbu_wvalid && mem_awready && mem_wready) begin
                    // Both requesting - use round robin
                    next_state = last_grant_ifu ? WBU_WRITE : IFU_READ;
                end
                else if (ifu_arvalid && mem_arready && wbu_arvalid && mem_arready) begin
                    // Both want to read - use round robin
                    next_state = last_grant_ifu ? WBU_READ : IFU_READ;
                end
                else if (ifu_arvalid && mem_arready)
                    next_state = IFU_READ;
                else if (wbu_awvalid && wbu_wvalid && mem_awready && mem_wready)
                    next_state = WBU_WRITE;
                else if (wbu_arvalid && mem_arready)
                    next_state = WBU_READ;
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
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(*) begin
        // Default values
        ifu_arready = 0;
        ifu_rvalid = 0;
        ifu_rdata = 0;
        ifu_rresp = 0;
        
        wbu_arready = 0;
        wbu_awready = 0;
        wbu_wready = 0;
        wbu_bvalid = 0;
        wbu_bresp = 0;
        wbu_rvalid = 0;
        wbu_rdata = 0;
        wbu_rresp = 0;

        mem_arvalid = 0;
        mem_araddr = 0;
        mem_rready = 0;
        mem_awvalid = 0;
        mem_awaddr = 0;
        mem_wvalid = 0;
        mem_wdata = 0;
        mem_wstrb = 0;
        mem_bready = 0;

        case (state)
            IDLE: begin
                ifu_arready = mem_arready;
                wbu_arready = mem_arready;
                wbu_awready = mem_awready;
                wbu_wready = mem_wready;

                // TODO: HANDLE SIMULTANEOUSLY ACCESS CASE
                if(ifu_arvalid && mem_arready) begin
                    mem_arvalid = 1;
                    mem_araddr = ifu_araddr;
                end
                else if(wbu_awvalid && mem_awready && wbu_wvalid && mem_wready) begin
                    mem_awvalid = 1;
                    mem_awaddr = wbu_awaddr;
                    mem_wvalid = 1;
                    mem_wdata = wbu_wdata;
                    mem_wstrb = wbu_wstrb;
                end
                else if(wbu_arvalid && mem_arready) begin
                    mem_arvalid = 1;
                    mem_araddr = wbu_araddr;
                end
            end
            IFU_READ: begin
                mem_rready = ifu_rready;
                ifu_rvalid = mem_rvalid;
                ifu_rdata = mem_rdata;
                ifu_rresp = mem_rresp;
            end
            WBU_READ: begin
                mem_rready = wbu_rready;
                wbu_rvalid = mem_rvalid;
                wbu_rdata = mem_rdata;
                wbu_rresp = mem_rresp;
            end
            WBU_WRITE: begin
                mem_bready = wbu_bready;
                wbu_bvalid = mem_bvalid;
                wbu_bresp = mem_bresp;
            end

            default: begin
            end
        endcase
    end

endmodule 
