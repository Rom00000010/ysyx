module test_add_sub;
    reg [3:0] inputa, inputb;
    reg sel;
    wire [3:0] res;
    wire cout, zero, overflow;

    // 实例化 addsub 模块
    addsub dut(
               .a(inputa),
               .b(inputb),
               .sel(sel),
               .res(res),
               .cf(cout),
               .zero(zero),
               .overflow(overflow)
           );

    integer i, j;
    reg [4:0] expected_res;
    reg expected_cout, expected_zero, expected_overflow;

    // 定义检查任务
    task check;
        input [3:0] results;
        input result_overflow, result_cout, result_zero;
        begin
            if (res !== results || overflow !== result_overflow || cout !== result_cout || zero !== result_zero) begin
                $display("Error: a=%d, b=%d, sel=%b, Expected: res=%d, of=%b, c=%b, z=%b, Got: res=%d, of=%b, c=%b, z=%b",
                         $signed(inputa), $signed(inputb), sel, $signed(results), result_overflow, result_cout, result_zero, $signed(res), overflow, cout, zero);
            end
        end
    endtask

    // 测试逻辑
    initial begin
        for (i = -8; i <= 7; i = i + 1) begin
            for (j = -8; j <= 7; j = j + 1) begin
                /* verilator lint_off WIDTHTRUNC */
                inputa = i;
                inputb = j; 
                /* verilator lint_on WIDTHTRUNC */

                // 测试加法
                sel = 1'b0;  // 加法模式
                #10;
                // 扩展操作数到5位并执行加法
                expected_res = {1'b0, inputa} + {1'b0, inputb};
                expected_cout = expected_res[4];  // 检查第5位以确定是否有进位
                expected_zero = (expected_res[3:0] == 0) ? 1 : 0;
                expected_overflow = ((inputa[3] == inputb[3]) && (expected_res[3] != inputa[3]));
                check(expected_res[3:0], expected_overflow, expected_cout, expected_zero);

                // 测试减法
                sel = 1'b1;  // 减法模式
                #10;
                expected_res = {1'b0, inputa} - {1'b0, inputb};
                expected_cout = (i<j) ? 1 : 0;  // 检查是否有借位
                expected_zero = (expected_res[3:0] == 0) ? 1 : 0;
                expected_overflow = ((inputa[3] != inputb[3]) && (expected_res[3] != inputa[3]));
                check(expected_res[3:0], expected_overflow, expected_cout, expected_zero);
            end
        end
        $finish;
    end
endmodule
