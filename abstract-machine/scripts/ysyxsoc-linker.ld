ENTRY(_start)
PHDRS { text PT_LOAD; data PT_LOAD; }

MEMORY {
    flash : ORIGIN = 0x30000000, LENGTH = 16M
    sram : ORIGIN = 0x0f000000, LENGTH = 8K
}

SECTIONS {
  . = ORIGIN(flash);
  .text : {
    *(entry)
    *(.text*)
  } > flash AT> flash : text
  etext = .;
  _etext = .;

  .rodata : {
    *(.rodata*)
    _erodata = .;
  } > flash AT> flash

  _sidata = LOADADDR(.data);
  .data : {
    _data = .;
    *(.data*)
    *(.sdata*)
    _edata = .;
  } > sram AT> flash : data

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
