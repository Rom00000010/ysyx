#include <macro.h>
#include <common.h>
#include <difftest-def.h>
#include <iringbuf.h>
#include <isa-def.h>
#include <dlfcn.h>

void (*ref_difftest_memcpy)(uint32_t addr, void *buf, size_t n, bool direction) = NULL;
void (*ref_difftest_regcpy)(void *dut, bool direction) = NULL;
void (*ref_difftest_exec)(uint64_t n) = NULL;
void (*ref_difftest_raise_intr)(uint64_t NO) = NULL;
extern VerilatedFstC *tfp;

const char *regs[] = {
    "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"};

// Get state from digital circuit to compare with nemu
CPU_state cpu;

static bool is_skip_ref = false;

// this is used to let ref skip instructions which
// can not produce consistent behavior with NEMU
void difftest_skip_ref()
{
    is_skip_ref = true;
    // If such an instruction is one of the instruction packing in QEMU
    // (see below), we end the process of catching up with QEMU's pc to
    // keep the consistent behavior in our best.
    // Note that this is still not perfect: if the packed instructions
    // already write some memory, and the incoming instruction in NEMU
    // will load that memory, we will encounter false negative. But such
    // situation is infrequent.
}

void get_cpu_state(CPU_state *s)
{
    for (int i = 0; i < 16; i++)
    {
        SET_REG
        cpu.gpr[i] = get_reg_val_by_abi(regs[i]);
    }
    SET_TOP
    cpu.pc = get_pc_val();
}

void init_difftest(char *ref_so_file, long img_size, void *mem, int port)
{
    assert(ref_so_file != NULL);

    void *handle;
    handle = dlopen(ref_so_file, RTLD_LAZY);
    assert(handle);

    // 将 dlsym 返回的 void* 强制转换为对应的函数指针类型
    ref_difftest_memcpy = (void (*)(uint32_t, void *, size_t, bool))dlsym(handle, "difftest_memcpy");
    assert(ref_difftest_memcpy);

    ref_difftest_regcpy = (void (*)(void *, bool))dlsym(handle, "difftest_regcpy");
    assert(ref_difftest_regcpy);

    ref_difftest_exec = (void (*)(uint64_t))dlsym(handle, "difftest_exec");
    assert(ref_difftest_exec);

    ref_difftest_raise_intr = (void (*)(uint64_t))dlsym(handle, "difftest_raise_intr");
    assert(ref_difftest_raise_intr);

    void (*ref_difftest_init)(int) = (void (*)(int))dlsym(handle, "difftest_init");
    assert(ref_difftest_init);

    get_cpu_state(&cpu);

    ref_difftest_init(port);
    ref_difftest_memcpy(RESET_VECTOR, mem, img_size, DIFFTEST_TO_REF);
    ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
}

static void checkregs(CPU_state *ref, uint32_t pc)
{
    get_cpu_state(&cpu);

    for (int i = 0; i < 16; i++)
    {
        if (!difftest_check_reg(regs[i], pc, ref->gpr[i], cpu.gpr[i]))
        {
            goto error;
        }
    }

    if (!difftest_check_reg("$pc", pc, ref->pc, cpu.pc))
    {
        goto error;
    }

    return;

error:
    SET_REG
    printBuffer();
    print_rf();
    tfp->close();
    exit(1);
}

void difftest_step(uint32_t pc)
{
    CPU_state ref_r;

    if (is_skip_ref)
    {
        // to skip the checking of an instruction, just copy the reg state to reference design
        get_cpu_state(&cpu);
        ref_difftest_regcpy(&cpu, DIFFTEST_TO_REF);
        is_skip_ref = false;
        return;
    }

    ref_difftest_exec(1);
    ref_difftest_regcpy(&ref_r, DIFFTEST_TO_DUT);

    checkregs(&ref_r, pc);
}
