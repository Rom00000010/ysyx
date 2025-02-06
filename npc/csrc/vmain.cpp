#include "Vtop.h"
#include "verilated_vcd_c.h"
#include "verilated.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "svdpi.h"
#include "Vtop__Dpi.h"

#define MAX_SIM_TIME 25

VerilatedContext *contextp = NULL;
VerilatedVcdC *tfp = NULL;

vluint64_t sim_time = 0;
bool finish = false;

static Vtop *top;

uint32_t mem[1024] = {0xff000113, 0xff000213, 0xff000313, 0x11111437, 0x00100073};

void set_finish()
{
    finish = true;
}

uint32_t pmem_read(uint32_t addr)
{
    addr -= 0x80000000;
    if (addr < sizeof(mem))
        return mem[addr / 4];
    return 0;
}

void step_and_dump_wave()
{
    top->clk ^= 1;
    top->eval();

    if (top->clk == 1)
        top->instr = pmem_read(top->pc_val);
    sim_time++;
    tfp->dump(sim_time);
}

void sim_init()
{
    contextp = new VerilatedContext;
    contextp->traceEverOn(true);
    tfp = new VerilatedVcdC;
    top = new Vtop;
    top->trace(tfp, 99);
    tfp->open("dump.vcd");
}

void sim_exit()
{

    tfp->close();
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

int main(int argc, char **argv)
{
    sim_init();

    reset(5);

    while (!finish)
        step_and_dump_wave();

    sim_exit();
    return 0;
}