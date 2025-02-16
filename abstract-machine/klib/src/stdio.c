#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int sprintf(char *out, const char *fmt, ...);

void apply_padding(char *out, size_t *bytes, int padding, int zero_padding) {
  if (zero_padding) {
    memset(out + *bytes, '0', padding);
  } else {
    memset(out + *bytes, ' ', padding);
  }
  *bytes += padding;
}

int printf(const char *fmt, ...) {
  char buf[1024];

  va_list args;
  va_start(args,fmt);

  int size = vsprintf(buf, fmt, args);

  va_end(args);

  for (int i = 0; buf[i] != '\0'; i++) {
    putch(buf[i]);
  }

  return size;
}

int vsprintf(char *out, const char *fmt, va_list ap) {
  size_t len = strlen(fmt);
  int i = 0, j = 0;
  size_t bytes = 0;
  
  // initialize to empty string
  out[0] = '\0';

  while (i < len) {
    if (fmt[i] == '%') {
      // formatted output
      j = i + 1;

      int width = 0;
      int zero_padding = 0;
      // Extract padding element
      if(fmt[j] == '0') {
        zero_padding = 1;
        j++;
      }
      // Extract padding width
      while(fmt[j] >= '0' && fmt[j] <= '9') {
        width = width * 10 + fmt[j] - '0';
        j++;
      }

      if (fmt[j] == 'd') {
        int n = va_arg(ap, int);
        char buf[20];
        to_string(n, buf);
        int buf_len = strlen(buf);
        
        int padding = width > buf_len ? width - buf_len : 0;
        apply_padding(out, &bytes, padding, zero_padding);
        strcpy(out + bytes, buf);
        bytes += buf_len;

      } else if(fmt[j] == 'x' || fmt[j] == 'X'){
        unsigned int n = va_arg(ap, unsigned int);
        char buf[20];
        int upper_case = (fmt[j] == 'X'); 
        to_hex_string(n, buf, upper_case);
        int buf_len = strlen(buf);
        
        int padding = width > buf_len ? width - buf_len : 0;
        apply_padding(out, &bytes, padding, zero_padding);
        strcpy(out + bytes, buf);
        bytes += buf_len;

      } else if (fmt[j] == 's') {
        char *s = va_arg(ap, char*);
        strcat(out, s);
        bytes += strlen(s);

      } else if (fmt[j] == 'c'){
        char c = va_arg(ap, int);
        out[bytes] = c;
        out[bytes + 1] = '\0';
        bytes++;

      } else {
        panic("Not implemented");
      }
      i = j + 1;
    } else {
      while (fmt[j] != '\0' && fmt[j] != '%') {j++;}
      int str_len = strlen(out);
      memcpy(out + str_len, fmt + i, j - i);
      out[str_len + j - i] = '\0';
      bytes += j - i;
      i = j;
    }
  }

  return bytes;
}

int sprintf(char *out, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);

  size_t bytes = vsprintf(out, fmt, args);

  va_end(args);

  return bytes;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  panic("Not implemented");
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  panic("Not implemented");
}

#endif
