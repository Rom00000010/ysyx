#define RESET_VECTOR 0x80000000
#define MROM_BASE 0x20000000
enum { DIFFTEST_TO_DUT, DIFFTEST_TO_REF };

static inline bool difftest_check_reg(const char *name, uint32_t pc, uint32_t ref, uint32_t dut) {
  if (ref != dut) {
    printf("%s is different after executing instruction at pc = 0x%08x, right =0x%08x, wrong =0x%08x, diff =0x%08x\n", name, pc-4, ref, dut, ref ^ dut);
    return false;
  }
  return true;
}