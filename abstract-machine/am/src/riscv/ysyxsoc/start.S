.section entry, "ax"
.globl _start
.type _start, @function

_start:
  mv s0, zero
  la sp, _stack_pointer
  call bootload
  mv s0, a0
  call sbootload
  mv s0, a0
  call _trm_init
