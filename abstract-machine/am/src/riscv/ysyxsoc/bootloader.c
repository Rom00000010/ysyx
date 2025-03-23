extern char _sidata, _data, _edata, _bstart, _bend;

void bootload() {
  char *src = &_sidata;
  char *dst = &_data;
  /* ROM has data at end of text; copy it.  */
  while (dst < &_edata)
  { *dst++ = *src++; }

  /* Zero bss.  */
  for (dst = &_bstart; dst < &_bend; dst++)
  { *dst = 0; }
}
