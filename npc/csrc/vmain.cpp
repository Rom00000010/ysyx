#include <common.h>
#include <macro.h>
#include <iringbuf.h>
#include <capstone/capstone.h>
#include <sys/time.h>
#include <iostream>
#include <iomanip>
#include <vector>
#include <signal.h>

using namespace std;

VerilatedContext *contextp = NULL;
VerilatedFstC *tfp = NULL;
Vtop *top;
svScope scope;

vluint64_t sim_time = 0;
int depth = 0;
bool finish = false;
bool stop = false;

// Signal handler for CTRL+C
void signal_handler(int signum) {
    cout << "Ctrl-c Accepted" << endl;
    stop = true;
}

long start_time;
long long total_cycles = 0;

vector<uint32_t> mem(32 * 1024 * 1024);
void sdb_mainloop();
void calculator_test();
void init_monitor(int argc, char **argv, vector<uint32_t> &mem);
void init_difftest(char *ref_so_file, long img_size, void *mem, int port);
uint32_t scan_watchpoints(bool *success);
uint32_t watchpoint_val();
int watchpoint_no();
char *watchpoint_exp();
const char *func_name(uint32_t addr);
void ftrace(uint32_t pc, uint32_t instr);
void difftest_step(uint32_t pc);
void difftest_skip_ref();

long get_elapsed_microseconds()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000000 + tv.tv_usec;
}

void set_finish()
{
    SET_REG
    finish = true;
    if (get_reg_val_by_abi("a0") == 0)
    {
        cout << "\033[1;32m" << "HIT GOOD TRAP" << "\033[0m" << endl;
#ifndef CONFIG_PERF_MODE
        tfp->close();
#endif
        exit(0);
    }

    else
    {
        cout << "\033[1;31m" << "HIT BAD TRAP" << "\033[0m" << endl;
#ifndef CONFIG_PERF_MODE
        tfp->close();
#endif
        printBuffer();
        exit(1);
    }
}

extern "C" int pmem_read(int raddr)
{
#ifdef CONFIG_MTRACE
    SET_TOP
    if (raddr != get_pc_val() && raddr >= 0x80000000 && BITS(get_instr(), 6, 0) == 0b0000011)
    {
        printf("access 0x%08x at pc = 0x%08x\n", raddr, get_pc_val());
    }
#endif
    // Timer access
    if (raddr == 0xa0000048)
    {
        difftest_skip_ref();
        long end_time = get_elapsed_microseconds();
        return end_time - start_time;
    }

    // 总是读取地址为`raddr & ~0x3u`的4字节返回
    raddr &= ~0x3u;
    raddr -= 0x80000000;
    if (raddr / 4 < mem.size())
    {
        return mem[raddr / 4];
    }
    return 0;
}
extern "C" void pmem_write(int waddr, int wdata, char wmask)
{
    SET_TOP
#ifdef CONFIG_MTRACE
    if (waddr != get_pc_val() && waddr >= 0x80000000)
    {
        printf("write data 0x%08x with mask 0x%02x to addr 0x%08x at pc = 0x%08x\n", wdata, wmask, waddr, get_pc_val());
    }
#endif
    // Serial port access
    if (waddr == 0xa00003f8)
    {
        difftest_skip_ref();
        putchar(wdata);
        fflush(stdout);
        return;
    }

    waddr &= ~0x3u;
    waddr -= 0x80000000;

    if (waddr / 4 < mem.size())
    {
        uint32_t *ptr = &mem[waddr / 4];

        uint32_t byte_mask = 0;
        for (int i = 0; i < 4; i++)
        {
            if (wmask & (1 << i))
            {
                byte_mask |= (0xFFu << (8 * i));
            }
        }

        // calculate bytes wdata need to shift according to mask
        int shift = 0;
        unsigned char mask_temp = wmask;
        while ((mask_temp & 1) == 0 && shift < 4)
        {
            shift++;
            mask_temp >>= 1;
        }
        uint32_t aligned_wdata = wdata << (shift * 8);

        *ptr = (*ptr & ~byte_mask) | (aligned_wdata & byte_mask);
    }
}

void step_and_dump_wave(unsigned int n)
{
    while (n--)
    {
        if (finish)
            break;
        top->clk ^= 1;
        top->eval();

        if (top->clk == 0)
        {
            SET_WBU
            if (!wbu_skip())
                {   
                SET_TOP
                ftrace(get_pc_val(), get_instr());
            }
        }
        sim_time++;
#ifndef CONFIG_PERF_MODE
        tfp->dump(sim_time);
#endif
    }
    total_cycles += 1;
}

void sim_init()
{
    contextp = new VerilatedContext;
#ifndef CONFIG_PERF_MODE
    contextp->traceEverOn(true);
    tfp = new VerilatedFstC;
    top = new Vtop;
    top->trace(tfp, 99);
    tfp->open("dump.fst");
#else
    top = new Vtop;
#endif
}

void single_cycle()
{
    top->clk = 0;
    top->eval();
    sim_time++;
#ifndef CONFIG_PERF_MODE
    tfp->dump(sim_time);
#endif

    top->clk = 1;
    top->eval();
    sim_time++;
#ifndef CONFIG_PERF_MODE
    tfp->dump(sim_time);
#endif
}

void reset(int n)
{
    top->rst = 1;
    while (n-- > 0)
        single_cycle();
    top->rst = 0;
}

void disassembleAndPrint(uint32_t inst, char *buf, bool flag)
{
    // 初始化 Capstone 反汇编器
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
        printf("%08x %08x\n", inst, get_pc_val());
        tfp->close();
        exit(1);
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
#ifdef CONFIG_PERF_MODE
    while(1) step_and_dump_wave(2);
#else
    unsigned int cnt = n;
    char log_buf[100];
    while (!finish && cnt-- && !stop)
    {
        SET_WBU
        uint32_t wbu = wbu_skip();
        SET_TOP
        uint32_t instr = get_instr();

        // Skip internal cycle(don't cause state change)
        if (wbu)
        {
            cnt++;
            step_and_dump_wave(2);
            continue;
        }
        
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

int main(int argc, char **argv)
{   
    // Capture Ctrl-c, stop simulation in time
    signal(SIGINT, signal_handler);

    // Initialize simulation
    sim_init();

    init_monitor(argc, argv, mem);

    reset(5);

    uint8_t *byteArray = reinterpret_cast<uint8_t *>(mem.data());
    size_t byteArraySize = mem.size() * sizeof(uint32_t);

    start_time = get_elapsed_microseconds();

    init_difftest(argv[3], byteArraySize, (void *)byteArray, 1234);

    sdb_mainloop();

    printf("total cycles: %lld\n", total_cycles);

#ifndef CONFIG_PERF_MODE
    tfp->close();
#endif
    top->final();
    delete top;
    delete contextp;
    return 0;
}