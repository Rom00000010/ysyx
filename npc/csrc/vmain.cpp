#include "Vtop.h"
#include "verilated_vcd_c.h"
#include "verilated.h"
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <iomanip>
#include <fstream>
#include <macro.h>
#include <vector>
#include <cstdint>
#include <cstring>
#include <capstone/capstone.h>
#include <iringbuf.h>
#include "svdpi.h"
#include "Vtop__Dpi.h"

#define CONFIG_WATCHPOINT
#define CONFIG_FTRACE

using namespace std;

VerilatedContext *contextp = NULL;
VerilatedVcdC *tfp = NULL;
Vtop *top;

vluint64_t sim_time = 0;
int depth = 0;
bool finish = false;
bool stop = false;

vector<uint32_t> mem(1024 * 1024);
extern "C" void print_rf();
extern "C" int get_dnpc();
void sdb_mainloop();
void calculator_test();
void init_monitor(int argc, char **argv, vector<uint32_t> &mem);
uint32_t scan_watchpoints(bool *success);
uint32_t watchpoint_val();
int watchpoint_no();
char *watchpoint_exp();
const char *func_name(uint32_t addr);
void ftrace(uint32_t pc, uint32_t instr);

void set_finish()
{
    finish = true;
    if (top->ret_val == 0)
    {
        cout << "\033[1;32m" << "HIT GOOD TRAP" << "\033[0m" << endl;
    }
    else
    {
        cout << "\033[1;31m" << "HIT BAD TRAP" << "\033[0m" << endl;
        printBuffer();
        exit(1);
    }
}

uint32_t pmem_read(uint32_t addr)
{
    addr -= 0x80000000;
    if (addr < mem.size())
    {
        return mem[addr / 4];
    }
    return 0;
}

void step_and_dump_wave(unsigned int n)
{
    while (n--)
    {
        if (finish)
            break;
        top->clk ^= 1;
        top->eval();

        if (top->clk == 1)
        {
            top->instr = pmem_read(top->pc_val);
        }
        else 
        {
            ftrace(top->pc_val, top->instr);
        }
        sim_time++;
        tfp->dump(sim_time);
    }
}

void sim_init()
{
    // create simulate context, dut and dump wave
    contextp = new VerilatedContext;
    contextp->traceEverOn(true);
    tfp = new VerilatedVcdC;
    top = new Vtop;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");
}

void single_cycle()
{
    top->clk = 0;
    top->eval();
    sim_time++;
    tfp->dump(sim_time);

    top->clk = 1;
    top->eval();
    sim_time++;
    tfp->dump(sim_time);
}

void reset(int n)
{
    top->instr = 0;
    top->rst = 1;
    while (n-- > 0)
        single_cycle();
    top->rst = 0;
    top->instr = pmem_read(top->pc_val);
}

void disassembleAndPrint(uint32_t inst, char *buf, bool flag)
{
    // 初始化 Capstone 反汇编器（以 RISC-V 32 位为例）
    csh handle;
    if (cs_open(CS_ARCH_RISCV, CS_MODE_RISCV32, &handle) != CS_ERR_OK)
    {
        std::cerr << "ERROR: Failed to initialize Capstone disassembler" << std::endl;
        return;
    }

    // 将 uint32_t 指令转换为字节数组（注意字节序，通常为小端）
    uint8_t code[4];
    std::memcpy(code, &inst, sizeof(inst));

    // 反汇编此 4 字节的代码，从地址 0 开始（地址仅用于显示）
    cs_insn *insn = nullptr;
    size_t count = cs_disasm(handle, code, sizeof(code), 0x0, 0, &insn);
    if (count > 0)
    {
        // 打印反汇编结果（理论上 count 应为 1）
        for (size_t i = 0; i < count; i++)
        {
            if (flag)
                std::cout << insn[i].mnemonic << "\t" << insn[i].op_str << std::endl;
            else
            {
                strcat(buf, insn[i].mnemonic);
                strcat(buf, "\t");
                strcat(buf, insn[i].op_str);
            }
        }
        cs_free(insn, count);
    }
    else
    {
        std::cerr << "ERROR: Failed to disassemble the given instruction" << std::endl;
    }

    cs_close(&handle);
}

void watchpoint_inspect()
{
#ifdef CONFIG_WATCHPOINT
    bool triggered = false;
    uint32_t old_val = scan_watchpoints(&triggered);
    if (triggered)
    {
        // indirect read value from static variable
        uint32_t new_val = watchpoint_val();
        int no = watchpoint_no();
        char *exp = watchpoint_exp();
        printf("watchpoint %d: %s\n\n", no, exp);
        printf("old value: %u/0x%x\nnew value: %u/0x%x\n", old_val, old_val, new_val, new_val);
        stop = true;
    }
#endif
}

void ftrace(uint32_t pc, uint32_t instr)
{
    const svScope scope = svGetScopeFromName("TOP.top");
    if (!scope)
    {
        std::cerr << "Failed to get scope for top" << std::endl;
    }
    else
    {
        svSetScope(scope);
    }
#ifdef CONFIG_FTRACE
    const char *name = func_name(pc);
    const char *target_name = func_name(get_dnpc());
    int rs1 = BITS(instr, 19, 15);
    int rs2 = BITS(instr, 24, 20);
    int rd = BITS(instr, 11, 7);
    int imm = BITS(instr, 31, 20);
    if (BITS(instr, 6, 0) == 0b1100111)
    {
        if (rd == 0 && imm == 0 && (rs1 == 1 || rs1 == 5))
        {
            // ret
            depth--;
            assert(depth >= 0);
            printf("0x%x: ", pc);
            for (int i = 0; i < depth; i++)
            {
                printf("  ");
            }
            printf("ret  [%s]\n", name);
        }
        else if (rd == 1 || rd == 5)
        {
            // call
            printf("0x%x: ", pc);
            for (int i = 0; i < depth; i++)
            {
                printf("  ");
            }
            printf("call [%s@0x%x]\n", target_name, get_dnpc());
            depth++;
        }
    }
    else if (BITS(instr, 6, 0) == 0b1101111)
    {
        if (rd == 1 || rd == 5)
        {
            // call
            printf("0x%x: ", pc);
            for (int i = 0; i < depth; i++)
            {
                printf("  ");
            }
            printf("call [%s@0x%x]\n", target_name, get_dnpc());
            depth++;
        }
    }

#endif
}

void cpu_exec(unsigned int n)
{
    unsigned int cnt = n;
    char log_buf[100];
    while (!finish && cnt-- && !stop)
    {
        if (n <= 10)
        {
            cout << "0x"
                 << setw(8)
                 << setfill('0')
                 << hex
                 << top->pc_val << ": ";
            cout << setw(8)
                 << setfill('0')
                 << hex
                 << top->instr << " ";
            disassembleAndPrint(top->instr, log_buf, 1);
        }
        sprintf(log_buf, "0x%08x: %08x\t", top->pc_val, top->instr);
        disassembleAndPrint(top->instr, log_buf, 0);
        writeBuffer(log_buf);
        step_and_dump_wave(2);
        watchpoint_inspect();
    }
}

int main(int argc, char **argv)
{
    sim_init();

    init_monitor(argc, argv, mem);

    reset(5);

    sdb_mainloop();

    tfp->close();
    return 0;
}