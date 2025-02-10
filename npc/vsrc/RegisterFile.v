module RegisterFile #(ADDR_WIDTH = 1, DATA_WIDTH = 1) (
        input clk,
        input rst,
        input [DATA_WIDTH-1:0] wdata,
        input [ADDR_WIDTH-1:0] waddr,
        input [ADDR_WIDTH-1:0] raddr1,
        output[DATA_WIDTH-1:0] rdata1,
        input [ADDR_WIDTH-1:0] raddr2,
        output[DATA_WIDTH-1:0] rdata2,
        output[DATA_WIDTH-1:0] ret_val,
        input wen
    );
    reg [DATA_WIDTH-1:0] rf [2**ADDR_WIDTH-1:0];
    wire write_enable;
    wire [31:0]zero_reg=32'h00000000;

    assign write_enable = wen & (waddr != 0);

    always @(posedge clk) begin
        if (write_enable && ~rst)
            rf[waddr] <= wdata;
    end

    assign rdata1 = raddr1 == 0 ? zero_reg : rf[raddr1];
    assign rdata2 = raddr2 == 0 ? zero_reg : rf[raddr2];
    assign ret_val = rf[10];

    function automatic [79:0] get_abi_name;
        input [3:0] reg_index;
        begin
            case (reg_index)
                4'd0:
                    get_abi_name = "$0";
                4'd1:
                    get_abi_name = "ra";
                4'd2:
                    get_abi_name = "sp";
                4'd3:
                    get_abi_name = "gp";
                4'd4:
                    get_abi_name = "tp";
                4'd5:
                    get_abi_name = "t0";
                4'd6:
                    get_abi_name = "t1";
                4'd7:
                    get_abi_name = "t2";
                4'd8:
                    get_abi_name = "s0";
                4'd9:
                    get_abi_name = "s1";
                4'd10:
                    get_abi_name = "a0";
                4'd11:
                    get_abi_name = "a1";
                4'd12:
                    get_abi_name = "a2";
                4'd13:
                    get_abi_name = "a3";
                4'd14:
                    get_abi_name = "a4";
                4'd15:
                    get_abi_name = "a5";
                default:
                    get_abi_name = "??";
            endcase
        end
    endfunction

    export "DPI-C" task print_rf;

    task print_rf;
        integer i;
        begin
            $display("=== Register (RV32E) Contents ===");
            for (i = 0; i < (2**ADDR_WIDTH); i = i + 1) begin
                $display("%s = 0x%08h %d", get_abi_name(i[3:0]), rf[i], rf[i]);
            end
            $display("=====================================");
        end
    endtask

    function automatic int abi_to_index(input string abi_name);
        begin
            if      (abi_name == "$0") abi_to_index = 0;
            else if (abi_name == "ra")   abi_to_index = 1;
            else if (abi_name == "sp")   abi_to_index = 2;
            else if (abi_name == "gp")   abi_to_index = 3;
            else if (abi_name == "tp")   abi_to_index = 4;
            else if (abi_name == "t0")   abi_to_index = 5;
            else if (abi_name == "t1")   abi_to_index = 6;
            else if (abi_name == "t2")   abi_to_index = 7;
            else if (abi_name == "s0")   abi_to_index = 8;
            else if (abi_name == "s1")   abi_to_index = 9;
            else if (abi_name == "a0")   abi_to_index = 10;
            else if (abi_name == "a1")   abi_to_index = 11;
            else if (abi_name == "a2")   abi_to_index = 12;
            else if (abi_name == "a3")   abi_to_index = 13;
            else if (abi_name == "a4")   abi_to_index = 14;
            else if (abi_name == "a5")   abi_to_index = 15;
            else                         abi_to_index = -1; // 无效
        end
    endfunction

    function automatic int get_reg_val_by_abi(input string abi_name);
        int idx;
        begin
            idx = abi_to_index(abi_name);
            if (idx < 0) begin
                // 无效 ABI 名时，返回 0 或者其他错误标识
                get_reg_val_by_abi = 0; 
            end
            else begin
                // x0 恒为 0，也可直接返回 rf[idx]，因为我们从不写入 rf[0]
                get_reg_val_by_abi = rf[idx];
            end
        end
    endfunction

    // 将此函数导出给 C++ 调用
    export "DPI-C" function get_reg_val_by_abi;

endmodule
