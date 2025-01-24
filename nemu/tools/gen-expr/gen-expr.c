/***************************************************************************************
* Copyright (c) 2014-2024 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <string.h>
#include <stdbool.h>

// this should be enough
static char buf[65536] = {};
static char code_buf[65536 + 128] = {}; // a little larger than `buf`
static char *code_format =
  "#include <stdio.h>\n"
  "int main() { "
  "  unsigned result = %s; "
  "  printf(\"%%u\", result); "
  "  return 0; "
  "}";

static uint32_t buf_ptr = 0;

void gen(char c);

uint32_t choose(uint32_t n) {
  return rand() % n;
}

void randomly_insert_space() {
  if (choose(100) == 5)
  { gen(' '); }
}

void gen_num(bool flag) {
  int num = rand() ;
  if (flag) {
    while (num == 0) {
      num = rand() ;
    }
  }

  // generate number str
  char num_str[14];
  int len = sprintf(num_str, "%d", num);
  num_str[len++] = 'U';
  num_str[len] = '\0';
  assert(num_str[len] == '\0');

  if (buf_ptr + len <= sizeof(buf) -1) {
    strcpy(&buf[buf_ptr], num_str);
    buf_ptr += len;
  } else {
    // buffer overflow
    return;
  }
  randomly_insert_space();
}

void gen(char c) {
  if (buf_ptr + 1 <= sizeof(buf) -1) {
    buf[buf_ptr++] = c;
    buf[buf_ptr] = '\0';
  } else {
    // buffer overflow
    return;
  }
  randomly_insert_space();
}

void gen_rand_op() {
  char op[4] = "+-*/";
  int random = rand() % 4;
  gen(op[random]);
}

static void gen_rand_expr() {
  switch (choose(3)) {
    case 0: gen_num(false); break;
    case 1: gen('('); gen_rand_expr(); gen(')'); break;
    default: {
      gen_rand_expr();
      gen_rand_op();
      if (buf[buf_ptr - 1] == '/') {
        gen_num(true);
      } else {
        gen_rand_expr();
      }
      break;
    }
  }
}

int main(int argc, char *argv[]) {
  int seed = time(0);
  srand(seed);
  int loop = 1;
  if (argc > 1) {
    sscanf(argv[1], "%d", &loop);
  }
  int i;
  for (i = 0; i < loop; i ++) {
    gen_rand_expr();

    // ugly but maybe work
    if (buf_ptr >= 60000) {
      buf_ptr = 0;
      continue;
    }

    sprintf(code_buf, code_format, buf);

    FILE *fp = fopen("/tmp/.code.c", "w");
    assert(fp != NULL);
    fputs(code_buf, fp);
    fclose(fp);

    int ret = system("gcc /tmp/.code.c -o /tmp/.expr");
    if (ret != 0) { continue; }

    fp = popen("/tmp/.expr", "r");
    assert(fp != NULL);

    int result;
    ret = fscanf(fp, "%d", &result);
    pclose(fp);

    printf("%u %s\n", result, buf);

    buf_ptr = 0;
  }
  return 0;
}
