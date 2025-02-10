#include "Vtop.h"
#include "verilated_vcd_c.h"
#include "verilated.h"
#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <cstring>
#include "svdpi.h"
#include "Vtop__Dpi.h"

using namespace std;

VerilatedContext *contextp = NULL;
VerilatedVcdC *tfp = NULL;
static Vtop *top;

vluint64_t sim_time = 0;
bool finish = false;

vector<uint32_t> mem(1024 * 1024);

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

void img_init(int argc, char **argv)
{
    // get image path
    if (argc < 2)
    {
        cerr << "Usage: " << argv[0] << " <image_file>" << endl;
        exit(1);
    }
    string filename = argv[1];

    // open in binary mode
    ifstream file(filename, ios::binary);
    if (!file)
    {
        cerr << "Error opening file: " << filename << endl;
        exit(1);
    }

    // use istreambuf_iterator read complete content
    vector<unsigned char> buffer((istreambuf_iterator<char>(file)),
                                 istreambuf_iterator<char>());
    file.close();

    if (buffer.size() % 4 != 0)
    {
        cerr << "Error: Image size is not a multiple of 4 bytes." << endl;
        exit(1);
    }

    memcpy(mem.data(), buffer.data(), buffer.size());
}

int main(int argc, char **argv)
{
    sim_init();

    img_init(argc, argv);

    reset(5);

    while (!finish)
        step_and_dump_wave();

    tfp->close();
    return 0;
}