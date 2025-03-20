#define ARRLEN(arr) (int)(sizeof(arr) / sizeof(arr[0]))
#define BITMASK(bits) ((1ull << (bits)) - 1)
#define BITS(x, hi, lo) (((x) >> (lo)) & BITMASK((hi) - (lo) + 1)) // similar to x[hi:lo] in verilog
#define SET_TOP {scope = svGetScopeFromName("TOP.ysyxSoCFull.asic.cpu.cpu"); svSetScope(scope);}
#define SET_REG {scope = svGetScopeFromName("TOP.ysyxSoCFull.asic.cpu.cpu.idu.regfile"); svSetScope(scope);}
#define SET_IFU {scope = svGetScopeFromName("TOP.ysyxSoCFull.asic.cpu.cpu.ifu"); svSetScope(scope);}
#define SET_WBU {scope = svGetScopeFromName("TOP.ysyxSoCFull.asic.cpu.cpu.wbu"); svSetScope(scope);}
#define SET_IDU {scope = svGetScopeFromName("TOP.ysyxSoCFull.asic.cpu.cpu.idu"); svSetScope(scope);}