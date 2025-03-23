ENTRY(_start)
PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
    mrom : ORIGIN = 0x20000000, LENGTH = 4K
    sram : ORIGIN = 0x0f000000, LENGTH = 8k
}

SECTIONS {
  . = ORIGIN(mrom);
  .text : {
    *(entry)
    *(.text*)
  } > mrom AT> mrom : text
  etext = .;
  _etext = .;

  .rodata : {
    *(.rodata*)
    _erodata = .;
  } > mrom AT> mrom

  _sidata = LOADADDR(.data);
  .data : {
    _data = .;
    *(.data*)
    _edata = .;
  } > sram AT> mrom : data

  .bss (NOLOAD): {
	_bstart = .;
    *(.bss*)
    *(.sbss*)
    *(.scommon)
    _bend = .;
  } > sram

  . = ALIGN(4);
  _heap_start = .;
  . = ORIGIN(sram) + LENGTH(sram);
  _stack_pointer = .;
}
