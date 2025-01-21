module test_alu;
    reg [3:0] inputa, inputb;
    reg [2:0] func;
    wire [3:0] y1;
    /* verilator lint_off UNOPTFLAT */
    wire zf1, of1, cf1;
    /* verilator lint_on UNOPTFLAT */

    // 实例化 alu 模块
    alu dut(
            .a(inputa),
            .b(inputb),
            .f(func),
            .y(y1),
            .zf(zf1),
            .of(of1),
            .cf(cf1)
        );

    integer i, j, select;
    reg [4:0] expected_y;
    reg expected_zf, expected_of, expected_cf;

    // 定义检查任务
    task check;
        input [3:0] results;
        input result_zf, result_of, result_cf;
        input [2:0] fun;
        begin
            if(fun == 3'b000 || fun == 3'b001) begin
                if (y1 !== results || zf1 !== result_zf || of1 !== result_of || cf1 !== result_cf) begin
                    $display("Error: a=%d, b=%d, func=%b, Expected: y=%d, zf=%b, of=%b, cf=%b, Got: y=%d, zf=%b, of=%b, cf=%b",
                             $signed(inputa), $signed(inputb), func, $signed(results), result_zf, result_of, result_cf, $signed(y1), zf1, of1, cf1);
                end
            end
            else begin
                if(y1 !== results) begin
                    $display("Error: a=%d, b=%d, func=%b, Expected: y=%d, Got: y=%d",$signed(inputa), $signed(inputb), func, $signed(results), $signed(y1));
                end
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

                // 测试不同的功能
                /* verilator lint_off WIDTHEXPAND */
                for (select = 0; select < 8; select = select + 1) begin
                    case (select)
                        0: begin // 加法 A+B
                            expected_y = {1'b0, inputa} + {1'b0, inputb};
                            expected_cf = expected_y[4];
                            expected_zf = (expected_y[3:0] == 0);
                            expected_of = ((inputa[3] == inputb[3]) && (expected_y[3] != inputa[3]));
                        end
                        1: begin // 减法 A-B
                            expected_y = {1'b0, inputa} - {1'b0, inputb};
                            expected_cf = (i < j);
                            expected_zf = (expected_y[3:0] == 0);
                            expected_of = ((inputa[3] != inputb[3]) && (expected_y[3] != inputa[3]));
                        end
                        2: begin // 取反 Not A
                            expected_y[3:0] = ~inputa;
                            expected_zf = (expected_y == 0);
                            expected_of = 0;
                            expected_cf = 0;
                        end
                        3: begin // 与 A and B
                            expected_y[3:0] = inputa & inputb;
                            expected_zf = (expected_y == 0);
                            expected_of = 0;
                            expected_cf = 0;
                        end
                        4: begin // 或 A or B
                            expected_y[3:0] = inputa | inputb;
                            expected_zf = (expected_y == 0);
                            expected_of = 0;
                            expected_cf = 0;
                        end
                        5: begin // 异或 A xor B
                            expected_y[3:0] = inputa ^ inputb;
                            expected_zf = (expected_y == 0);
                            expected_of = 0;
                            expected_cf = 0;
                        end
                        6: begin // 比较大小 If A<B then out=1; else out=0;
                            expected_y[3:0] = (i<j) ? 4'b0001 : 4'b0000;
                            expected_cf = (i < j);
                            expected_zf = (expected_y[3:0] == 0);
                            expected_of = ((inputa[3] != inputb[3]) && (expected_y[3] != inputa[3]));
                        end
                        7: begin // 判断相等 If A==B then out=1; else out=0;
                            expected_y[3:0] = (inputa == inputb) ? 4'b0001 : 4'b0000;
                            expected_cf = (i < j);
                            expected_zf = (expected_y[3:0] == 0);
                            expected_of = ((inputa[3] != inputb[3]) && (expected_y[3] != inputa[3]));
                        end
                        default: begin // 判断相等 If A==B then out=1; else out=0;
                            expected_y[3:0] = (inputa == inputb) ? 4'b0001 : 4'b0000;
                            expected_cf = (i < j);
                            expected_zf = (expected_y[3:0] == 0);
                            expected_of = ((inputa[3] != inputb[3]) && (expected_y[3] != inputa[3]));
                        end
                    endcase
                    /* verilator lint_off WIDTHTRUNC */
                    func = select;
                    #20;
                    /* verilator lint_on WIDTHTRUNC */
                    check(expected_y[3:0], expected_zf, expected_of, expected_cf, func);
                end
                /* verilator lint_on WIDTHEXPAND */
            end
        end
        $finish;
    end
endmodule
