`timescale 1ns / 1ns

module keycode_lut(
    input  [7:0] scan_code,
    output reg [7:0] ascii_code
);

    // 定义一个 256 x 8 位的 ROM，用于存储扫描码到 ASCII 码的映射
    reg [7:0] rom [0:255];

    // 初始化 ROM，在初始块中指定每个扫描码对应的 ASCII 码
    initial begin
        integer i;
        // 默认将所有地址的值初始化为 8'b0
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 8'b0;
        end

        // 数字 0-9 的映射
        rom[8'h45] = 8'h30; // '0'
        rom[8'h16] = 8'h31; // '1'
        rom[8'h1E] = 8'h32; // '2'
        rom[8'h26] = 8'h33; // '3'
        rom[8'h25] = 8'h34; // '4'
        rom[8'h2E] = 8'h35; // '5'
        rom[8'h36] = 8'h36; // '6'
        rom[8'h3D] = 8'h37; // '7'
        rom[8'h3E] = 8'h38; // '8'
        rom[8'h46] = 8'h39; // '9'

        // 小写字母 a-z 的映射（需要 Shift 键配合）
        // 在标准 PS/2 键盘中，小写字母和大写字母使用相同的扫描码，键盘本身不区分大小写
        // 实际上，大小写取决于 Shift 键状态和上层软件处理
        // 如果需要在硬件中区分大小写，需要检测 Shift 键的状态
        // 这里暂时将扫描码映射为小写字母，以供参考
        rom[8'h1C] = 8'h61; // 'a'
        rom[8'h32] = 8'h62; // 'b'
        rom[8'h21] = 8'h63; // 'c'
        rom[8'h23] = 8'h64; // 'd'
        rom[8'h24] = 8'h65; // 'e'
        rom[8'h2B] = 8'h66; // 'f'
        rom[8'h34] = 8'h67; // 'g'
        rom[8'h33] = 8'h68; // 'h'
        rom[8'h43] = 8'h69; // 'i'
        rom[8'h3B] = 8'h6A; // 'j'
        rom[8'h42] = 8'h6B; // 'k'
        rom[8'h4B] = 8'h6C; // 'l'
        rom[8'h3A] = 8'h6D; // 'm'
        rom[8'h31] = 8'h6E; // 'n'
        rom[8'h44] = 8'h6F; // 'o'
        rom[8'h4D] = 8'h70; // 'p'
        rom[8'h15] = 8'h71; // 'q'
        rom[8'h2D] = 8'h72; // 'r'
        rom[8'h1B] = 8'h73; // 's'
        rom[8'h2C] = 8'h74; // 't'
        rom[8'h3C] = 8'h75; // 'u'
        rom[8'h2A] = 8'h76; // 'v'
        rom[8'h1D] = 8'h77; // 'w'
        rom[8'h22] = 8'h78; // 'x'
        rom[8'h35] = 8'h79; // 'y'
        rom[8'h1A] = 8'h7A; // 'z'

    end

    // 在组合逻辑中，根据输入的扫描码输出对应的 ASCII 码
    always @(*) begin
        ascii_code = rom[scan_code];
    end

endmodule
