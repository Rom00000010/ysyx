#include "Vtop.h"
#include "verilated_vcd_c.h"
#include "verilated.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

VerilatedContext *contextp = NULL;
VerilatedVcdC *tfp = NULL;

static Vtop *top;

void step_and_dump_wave()
{
    top->eval();
    contextp->timeInc(1);
    tfp->dump(contextp->time());
}
void sim_init()
{
    contextp = new VerilatedContext;
    tfp = new VerilatedVcdC;
    top = new Vtop;
    contextp->traceEverOn(true);
    top->trace(tfp, 0);
    tfp->open("dump.vcd");
}

void sim_exit()
{

    tfp->close();
}

int main(int argc, char **argv)
{
    sim_init();

    while (!contextp->gotFinish())
        step_and_dump_wave();

    sim_exit();
    return 0;
}