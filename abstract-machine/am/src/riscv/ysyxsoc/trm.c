#include <am.h>
#include <klib-macros.h>
#include <klib.h> 

#define UART_BASE 0x10000000
#define UART_REG(offset) (*(volatile uint8_t *)(UART_BASE + (offset)))

#define REG_THR 0
#define REG_RBR 0
#define REG_IER 1
#define REG_IIR 2
#define REG_FCR 2
#define REG_LCR 3
#define REG_MCR 4
#define REG_LSR 5
#define REG_MSR 6

#define REG_DLL 0
#define REG_DLM 1

static inline void outb(uintptr_t addr, uint8_t  data) { *(volatile uint8_t  *)addr = data; }

extern char _heap_start;
int main(const char *args);
void bootload();

extern char _pmem_start;
#define PMEM_SIZE (32 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)

Area heap = RANGE(&_heap_start, PMEM_END);
static const char mainargs[MAINARGS_MAX_LEN] = MAINARGS_PLACEHOLDER; // defined in CFLAGS

void uart_init_1152008n1() {
  uint16_t divisor = 1;

  // Enable DLB access
  UART_REG(REG_LCR) = 0x80;

  // Set divisor, high byte first(order is important!)
  UART_REG(REG_DLM) = divisor >> 8;
  UART_REG(REG_DLL) = divisor & 0xff;

  // Set to 8N1, disable DLB access
  UART_REG(REG_LCR) = 0x03;

  // Enable and clear FIFO, set trigger level at 1 byte
  UART_REG(REG_FCR) = 0x07;
}

void putch(char ch) {
  while((UART_REG(REG_LSR) & 0x20) == 0);
  UART_REG(REG_THR) = ch;
}

void halt(int code) {
  asm volatile("mv a0, %0; ebreak" : :"r"(code));
  
  // should not reach here
  while(1);
}

void _trm_init() {
  uart_init_1152008n1();
  
  uint32_t mvendorid, marchid;
  asm volatile("csrr %0, 0xf11" : "=r"(mvendorid));
  asm volatile("csrr %0, 0xf12" : "=r"(marchid));

  for(int i = 0; i < 4; i++) {
    putch(mvendorid>>(24-i*8));
  }
  putch('_');
  printf("%d\n", marchid);

  int ret = main(mainargs);
  halt(ret);
}
