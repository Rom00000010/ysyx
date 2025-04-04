ENTRY(_start)
PHDRS { text PT_LOAD; data PT_LOAD; boot PT_LOAD; sboot PT_LOAD; }

MEMORY {
    flash : ORIGIN = 0x30000000, LENGTH = 16M
    sram : ORIGIN = 0x0f000000, LENGTH = 8K
    psram : ORIGIN = 0x80000000, LENGTH = 4M
}

SECTIONS {
  .entry : {
    *(entry)
    *(.bootloader)
  } > flash AT> flash : boot

  _sissbl = LOADADDR(.ssbl);
  .ssbl : {
    _ssbl = .;
    *(.sbootloader*)
    _essbl = .;
  } > sram AT> flash : sboot

  _sitext = LOADADDR(.text);
  .text : {
    _text = .;
    *(.text*)
    _etext = .;
  } > psram AT> flash : text

  _sirodata = LOADADDR(.rodata);
  .rodata : {
    _rodata = .;
    *(.rodata*)
    *(.srodata*)
    _erodata = .;
  } > psram AT> flash : data

  _sidata = LOADADDR(.data);
  .data : {
    _data = .;
    *(.data*)
    *(.sdata*)
    _edata = .;
  } > psram AT> flash

  .bss (NOLOAD): {
	_bstart = .;
    *(.bss.*)
    *(.sbss*)
    *(.scommon)
    _bend = .;
  } > psram

  . = ALIGN(4);
  _heap_start = .;
  . = ORIGIN(sram) + LENGTH(sram);
  _stack_pointer = .;
}
