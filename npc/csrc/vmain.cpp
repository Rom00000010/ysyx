#include <common.h>
#include <macro.h>
#include <iringbuf.h>
#include <capstone/capstone.h>
#include <sys/time.h>
#include <iostream>
#include <iomanip>
#include <vector>
#include <signal.h>
#include <chrono>

using namespace std;

VerilatedContext *contextp = NULL;
VerilatedFstC *tfp = NULL;
VysyxSoCFull *top;
svScope scope;

vluint64_t sim_time = 0;
int depth = 0;
bool stop = false;

long start_time;
long long total_cycles = 0;
double total_instrs = 0;

vector<uint8_t> mem(16 * 1024 * 1024);
vector<uint8_t> psram(4 * 1024 * 1024);

void sdb_mainloop();
void init_monitor(int argc, char **argv, vector<uint8_t> &mem);
void init_difftest(char *ref_so_file, long img_size, void *mem, int port);
void difftest_step(uint32_t pc);
void disassembleAndPrint(uint32_t inst, char *buf, bool flag);
void watchpoint_inspect();
void ftrace(uint32_t pc, uint32_t instr);

extern "C" void flash_read(int32_t addr, int32_t *data)
{   
    // Align address to 4-byte boundary
    int32_t aligned_addr = addr & ~0x3;
    int32_t d = 0;
    for(int i=0; i<4; i++)
    {
        d |= ((uint32_t)mem[aligned_addr+i]) << (8*i);
    }
    *data = d;
}
extern "C" void mrom_read(int32_t addr, int32_t *data)
{
    addr -= 0x20000000;
    if (addr / 4 < mem.size())
    {
        *data = mem[addr / 4];
    }
}   
extern "C" void psram_read(int32_t addr, int32_t *data)
{   
    int32_t d = 0;
    for(int i=0; i<4; i++)
    {
        d |= ((uint32_t)psram[addr+i]) << (8*i);
    }
    *data = d;
}
extern "C" void psram_write(int32_t addr, int32_t data, int32_t wcount)
{   
    for(int i=0; i<wcount; i++)
    {
        psram[addr + wcount - i - 1] = (data >> (8*i)) & 0x000000ff;
    }
}

long get_elapsed_microseconds()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000 + tv.tv_usec;
}

void set_finish()
{
    SET_REG
    stop = true;
    if (get_reg_val_by_abi("a0") == 0)
    {
        cout << "\033[1;32m" << "HIT GOOD TRAP" << "\033[0m" << endl;
#ifndef CONFIG_PERF_MODE
        tfp->close();
#endif
    }

    else
    {
        cout << "\033[1;31m" << "HIT BAD TRAP" << "\033[0m" << endl;
#ifndef CONFIG_PERF_MODE
        tfp->close();
#endif
        exit(1);
    }
}

void step_and_dump_wave(unsigned int n)
{   
    total_cycles += 1;
    while (n-- && !stop)
    {
        // Verilator simulation
        top->clock ^= 1;
        top->eval();

        // Wave dump && Ftrace && Frequency count
        if (top->clock == 0)
        {
            SET_WBU
            if (!wbu_skip())
            {
                SET_TOP
                ftrace(get_pc_val(), get_instr());
                total_instrs += 1;
            }
        }
#ifndef CONFIG_PERF_MODE

        sim_time++;
        tfp->dump(sim_time);
#endif
    }
}

void cpu_exec(unsigned int n)
{   
#ifdef CONFIG_PERF_MODE
    while (!stop)
        step_and_dump_wave(2);
#else
    unsigned int cnt = n;
    char log_buf[100];
    while (cnt-- && !stop)
    {
        // Skip internal cycle(don't cause state change)
        SET_WBU
        uint32_t wbu = wbu_skip();
        SET_TOP
        uint32_t instr = get_instr();

        if (wbu)
        {
            cnt++;
            step_and_dump_wave(2);
            continue;
        }

        // Print instruction,exec ITRACE
        if (n <= 10)
        {
            cout << "0x" << setw(8) << setfill('0') << hex << get_pc_val() << ": ";
            cout << setw(8) << setfill('0') << hex << instr << " ";
            disassembleAndPrint(instr, log_buf, 1);
        }
        sprintf(log_buf, "0x%08x: %08x\t", get_pc_val(), instr);
        disassembleAndPrint(instr, log_buf, 0);
        writeBuffer(log_buf);

        step_and_dump_wave(2);
        difftest_step(get_pc_val());

        watchpoint_inspect();
    }
#endif
}

void sim_init()
{
    contextp = new VerilatedContext;
#ifndef CONFIG_PERF_MODE
    contextp->traceEverOn(true);
    tfp = new VerilatedFstC;
    top = new VysyxSoCFull;
    top->trace(tfp, 99);
    tfp->open("dump.fst");
#else
    top = new VysyxSoCFull;
#endif
}

void single_cycle()
{
    top->clock = 0;
    top->eval();
#ifndef CONFIG_PERF_MODE
    sim_time++;
    tfp->dump(sim_time);
#endif

    top->clock = 1;
    top->eval();
#ifndef CONFIG_PERF_MODE
    sim_time++;
    tfp->dump(sim_time);
#endif
}

void reset(int n)
{
    top->reset = 1;
    while (n-- > 0)
        single_cycle();
    top->reset = 0;
}

void signal_handler(int signum)
{
    cout << "Ctrl-c Accepted" << endl;
    stop = true;
}

int main(int argc, char **argv)
{
    // Capture Ctrl-c, stop simulation in time
    signal(SIGINT, signal_handler);
    Verilated::commandArgs(argc, argv);

    sim_init();
    init_monitor(argc, argv, mem);
    reset(10);

    uint8_t *byteArray = reinterpret_cast<uint8_t *>(mem.data());
    init_difftest(argv[3], mem.size(), (void *)byteArray, 1234);

    start_time = get_elapsed_microseconds();
    auto start = std::chrono::high_resolution_clock::now();
    sdb_mainloop();
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed = end - start;

    double sim_rate = total_cycles / elapsed.count();
    //std::cout << "仿真速率: " << sim_rate / 1e6 << " MHz" << std::endl;

    double IPC = total_instrs / total_cycles;
    std::cout << "total_instrs: " << total_instrs << std::endl;
    std::cout << "total_cycles: " << total_cycles << std::endl;
    std::cout << "IPC: " << IPC << std::endl;

#ifndef CONFIG_PERF_MODE
    tfp->close();
#endif
    top->final();
    delete top;
    delete contextp;
    return 0;
}