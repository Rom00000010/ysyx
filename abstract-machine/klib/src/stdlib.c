#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)
static unsigned long int next = 1;
extern char _heap_start;
static char *hbrk = &_heap_start;

int rand(void) {
  // RAND_MAX assumed to be 32767
  next = next * 1103515245 + 12345;
  return (unsigned int)(next/65536) % 32768;
}

void srand(unsigned int seed) {
  next = seed;
}

int abs(int x) {
  return (x < 0 ? -x : x);
}

int atoi(const char* nptr) {
  int x = 0;
  while (*nptr == ' ') { nptr ++; }
  while (*nptr >= '0' && *nptr <= '9') {
    x = x * 10 + *nptr - '0';
    nptr ++;
  }
  return x;
}

char *to_string(int val, char *str) {
    
    // value equals to zero
    if (val == 0) {
        str[0] = '0';
        str[1] = '\0';
        return str;
    }

    // handle non-negative part
    int sign = (val < 0) ? -1 : 1;
    if (sign == -1) {
        val = -val;
    }

    int i = 0;
    while (val > 0) {
        int digit = val % 10;
        val /= 10;
        str[i++] = (char)('0' + digit);
    }

    // add sign and terminate
    if (sign == -1) {
        str[i++] = '-';
    }

    str[i] = '\0';

    // reverse
    for (int j = 0, k = i - 1; j < k; j++, k--) {
        char tmp = str[j];
        str[j] = str[k];
        str[k] = tmp;
    }

    return str;
}

void to_hex_string(unsigned int n, char *buf, int upper_case) {
        // Converting LUT
        char hex_digits[] = "0123456789abcdef";
        if (upper_case){
          hex_digits[10] = 'A';
          hex_digits[11] = 'B';
          hex_digits[12] = 'C';
          hex_digits[13] = 'D';
          hex_digits[14] = 'E';
          hex_digits[15] = 'F';
        }

        // Manually convert decimal int to hex string
        int l = 0;
        if(n==0){
          buf[l++] = '0';
        } else {
          unsigned int tmp = n;
          while(tmp > 0){
            buf[l++] = hex_digits[tmp % 16];
            tmp /= 16;
          }

          // Reverse
          for(int m = 0; m <l/2; m++){
            char tmp = buf[m];
            buf[m] = buf[l - m - 1];
            buf[l - m - 1] = tmp;
          }
          buf[l] = '\0';
        }
}

void *malloc(size_t size) {
  // On native, malloc() will be called during initializaion of C runtime.
  // Therefore do not call panic() here, else it will yield a dead recursion:
  //   panic() -> putchar() -> (glibc) -> malloc() -> panic()
#if !(defined(__ISA_NATIVE__) && defined(__NATIVE_USE_KLIB__))
    size  = (size_t)ROUNDUP(size, 8);
    char *old = hbrk;
    hbrk += size;
    assert((uintptr_t)heap.start <= (uintptr_t)hbrk && (uintptr_t)hbrk < (uintptr_t)heap.end);
    for (uint64_t *p = (uint64_t *)old; p != (uint64_t *)hbrk; p ++) {
       *p = 0;
    }
    return old;
#endif
  return NULL;
}

void free(void *ptr) {
}

#endif
