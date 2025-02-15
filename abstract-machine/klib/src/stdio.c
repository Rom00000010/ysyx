#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int sprintf(char *out, const char *fmt, ...);

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

  // first part
  if (fmt[i] == '%') {
    j = i + 1;
    if (fmt[j] == 'd') {
      int n = va_arg(ap, int);
      char buf[20];
      to_string(n, buf);
      strcpy(out, buf);
      bytes += strlen(buf);
    } else if (fmt[j] == 's') {
      char *s = va_arg(ap, char*);
      strcpy(out, s);
      bytes += strlen(s);
    } else {
      panic("Not implemented");
    }
    i = j + 1;
    j = i;
  } else {
    while (fmt[j] != '\0' && fmt[j] != '%') {j++;}
    memcpy(out, fmt+i, j - i);
    out[j - i] = '\0';
    bytes += j - i;
    i = j;
  }

  // rest character or conversion specification
  while (i < len) {
    if (fmt[i] == '%') {
      j = i + 1;
      if (fmt[j] == 'd') {
        int n = va_arg(ap, int);
        char buf[20];
        to_string(n, buf);
        strcat(out, buf);
        bytes += strlen(buf);
      } else if (fmt[j] == 's') {
        char *s = va_arg(ap, char*);
        strcat(out, s);
        bytes += strlen(s);
      } else {
        panic("Not implemented");
      }
      i = j + 1;
      j = i;
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
  size_t len = strlen(fmt);
  int i = 0, j = 0;
  size_t bytes = 0;

  va_list args;
  va_start(args, fmt);

  // first part
  if (fmt[i] == '%') {
    j = i + 1;
    if (fmt[j] == 'd') {
      int n = va_arg(args, int);
      char buf[20];
      to_string(n, buf);
      strcpy(out, buf);
      bytes += strlen(buf);
    } else if (fmt[j] == 's') {
      char *s = va_arg(args, char*);
      strcpy(out, s);
      bytes += strlen(s);
    } else {
      panic("Not implemented");
    }
    i = j + 1;
    j = i;
  } else {
    while (fmt[j] != '\0' && fmt[j] != '%') {j++;}
    memcpy(out, fmt+i, j - i);
    out[j - i] = '\0';
    bytes += j - i;
    i = j;
  }

  // rest character or conversion specification
  while (i < len) {
    if (fmt[i] == '%') {
      j = i + 1;
      if (fmt[j] == 'd') {
        int n = va_arg(args, int);
        char buf[20];
        to_string(n, buf);
        strcat(out, buf);
        bytes += strlen(buf);
      } else if (fmt[j] == 's') {
        char *s = va_arg(args, char*);
        strcat(out, s);
        bytes += strlen(s);
      } else {
        panic("Not implemented");
      }
      i = j + 1;
      j = i;
    } else {
      while (fmt[j] != '\0' && fmt[j] != '%') {j++;}
      int str_len = strlen(out);
      memcpy(out + str_len, fmt + i, j - i);
      out[str_len + j - i] = '\0';
      bytes += j - i;
      i = j;
    }
  }

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
