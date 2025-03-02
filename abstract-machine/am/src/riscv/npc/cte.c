#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>

static Context* (*user_handler)(Event, Context*) = NULL;

Context* __am_irq_handle(Context *c) {
  /*printf("%08x %x %x\n", c->mepc, c->mstatus, c->mcause);
  for(int i=0; i<NR_REGS; i++) {
    printf("%08x ", c->gpr[i]);
  }*/
 if (user_handler) {
    Event ev = {0};
    switch (c->mcause) {
      case 0xb: ev.event = EVENT_YIELD; break;
      default: ev.event = EVENT_ERROR; break;
    }

    c = user_handler(ev, c);
    assert(c != NULL);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(Context*(*handler)(Event, Context*)) {
  // initialize exception entry
  asm volatile("csrw mtvec, %0" : : "r"(__am_asm_trap));

  // register event handler
  user_handler = handler;

  return true;
}

Context *kcontext(Area kstack, void (*entry)(void *), void *arg) {
  Context *c = (Context *)(kstack.end - sizeof(Context));
  // Yield add sp by 4
  c->mepc = (uintptr_t)entry-4;
  c->mstatus = 0x1800;
  c->gpr[2] = (uintptr_t)kstack.end;
  c->gpr[10] = (uintptr_t)arg;
  return c;
}

void yield() {
#ifdef __riscv_e
  asm volatile("li a5, 11; ecall");
#else
  asm volatile("li a7, 11; ecall");
#endif
}

bool ienabled() {
  return false;
}

void iset(bool enable) {
}
