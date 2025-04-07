#include <am.h>

extern uint32_t _sidata, _data, _edata, _bstart, _bend, _sirodata, _rodata, _erodata, _sitext, _text, _etext, _sissbl, _ssbl, _essbl;

//extern uint32_t _siexdata, _exdata, _eexdata;

void bootload()__attribute__((section(".bootloader"))); 
void sbootload()__attribute__((section(".sbootloader")));

void sbootload(){
  uint32_t *src = &_sidata;
  uint32_t *dst = &_data;
  /* ROM has data at end of text; copy it.  */
  while (dst < &_edata)
  { *dst++ = *src++; }

  /* Copy the read-only data.  */
  src = &_sirodata;
  dst = &_rodata;
  while (dst < &_erodata)
  { *dst++ = *src++; }

  /* Copy the test data.  */
  src = &_sitext;
  dst = &_text;
  while (dst < &_etext)
  { *dst++ = *src++; }

  /* Copy the exception data.  */
  //src = &_siexdata;
  //dst = &_exdata;
  //while (dst < &_eexdata)
  //{ *dst++ = *src++; }

  /* Zero bss.  */
  for (dst = &_bstart; dst < &_bend; dst++)
  { *dst = 0; }
}

void bootload() {
  uint32_t *src = &_sissbl;
  uint32_t *dst = &_ssbl;
  while (dst < &_essbl)
  { *dst++ = *src++; }
}
