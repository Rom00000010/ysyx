#include <klib.h>
#include <klib-macros.h>
#include <stdint.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

size_t strlen(const char *s) {
  // amount of non-null bytes
  // panic_on(s == NULL, "nullptr");

  size_t len = 0;
  while (s[len] != '\0') { len++; }
  return len;
}

char *strcpy(char *dst, const char *src) {
  // programmer needs to ensure dst's length enough to hold strlen(src)+1
  // panic_on(src == NULL || dst == NULL, "nullptr");

  size_t len = strlen(src);
  int i;

  for (i = 0; i <= len; i++) {
    dst[i] = src[i];
  }

  return dst;
}

char *strncpy(char *dst, const char *src, size_t n) {
  panic("Not implemented");
}

char *strcat(char *dst, const char *src) {
  // panic_on(src==NULL || dst==NULL, "nullptr");

  strcpy(dst+strlen(dst), src);
  return dst;
}

int strcmp(const char *s1, const char *s2) {
  // compare two null-terminate string
  // panic_on(s1 == NULL || s2 == NULL, "nullptr");

  int i;
  size_t len1 = strlen(s1);
  size_t len2 = strlen(s2);
  size_t len = MIN(len1, len2);

  // compare each char in range[0, len)
  for (i = 0; i < len; i++) {
    if (s1[i] == s2[i]) {
      continue;
    } else {
      return s1[i] - s2[i];
    }
  }

  // can't get result through for loop, need more compare
  if (len1 == len2) {
    return 0;
  } else {
    return s1[len] - s2[len];
  }
}

int strncmp(const char *s1, const char *s2, size_t n) {
  panic("Not implemented");
}

void *memset(void *s, int c, size_t n) {
  // set first n bytes of s to char(var c)
  // panic_on(s==NULL, "nullptr");

  int i;
  char *ptr = s;

  for(i=0;i<n;i++) {
    ptr[i] = (char)c;
  }

  return s;
}

void *memmove(void *dst, const void *src, size_t n) {
  if (dst < src || (char*)dst >= (char*)src + n) {
    return memcpy(dst, src, n);
  } else {
    // overlap and src is before dst
    char *d = dst;
    const char *s = src;

    for(size_t i = n; i != 0; i--) {
      d[i-1] = s[i-1];
    }

    return dst;
  }
}



void *memcpy(void *out, const void *in, size_t n) {
  // assume two range is not overlaped
  size_t i;
  char *ptr1=out;
  const char *ptr2 = in;
  
  for(i=0;i<n;i++){
    ptr1[i] = ptr2[i];
  }

  return out;
}

int memcmp(const void *s1, const void *s2, size_t n) {
  // compare first n bytes, each as unsigned char
  // panic_on(s1==NULL || s2==NULL, "nullptr");

  size_t i;
  const char *ptr1=s1;
  const char *ptr2=s2;

  for(i=0;i<n;i++) {
    if(ptr1[i] == ptr2[i]) {
      continue;
    } else {
      return ptr1[i] - ptr2[i]; 
    }
  }

  return 0;
}

#endif
