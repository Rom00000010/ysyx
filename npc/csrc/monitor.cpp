#include <common.h>
#include <iringbuf.h>
#include <capstone/capstone.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
using namespace std;

extern bool stop;
extern VerilatedFstC *tfp;

void init_sdb();
void init_elf(const char *elf_file);
uint32_t scan_watchpoints(bool *success);
uint32_t watchpoint_val();
int watchpoint_no();
char *watchpoint_exp();
const char *func_name(uint32_t addr);

void init_mem(int argc, char **argv, vector<uint8_t> &mem)
{
    string filename = argv[1];

    ifstream file(filename, ios::binary);

    // use istreambuf_iterator read complete content
    vector<unsigned char> buffer((istreambuf_iterator<char>(file)),
                                 istreambuf_iterator<char>());
    file.close();


    memcpy(mem.data(), buffer.data(), buffer.size());

    // for(int i=0; i<buffer.size(); i++){
    //     printf("mem[%04x]: %02x\n", i, mem[i]);
    // }
}

void init_monitor(int argc, char **argv, vector<uint8_t> &mem)
{
    init_mem(argc, argv, mem);

    init_sdb();

    initBuffer();

    init_elf(argv[2]);
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
