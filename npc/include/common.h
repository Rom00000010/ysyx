#include "svdpi.h"
#include "Vtop__Dpi.h"
#include "Vtop.h"
#include "verilated_vcd_c.h"
#include "verilated.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>

#define CONFIG_WATCHPOINT
// #define CONFIG_FTRACE
// #define CONFIG_MTRACE

extern "C" int get_reg_val_by_abi(const char *abi_name);
extern "C" void print_rf();
extern "C" int get_dnpc();
extern "C" int get_instr();
extern "C" int get_pc_val();