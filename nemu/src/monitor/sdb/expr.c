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

#include <isa.h>
#include "memory/vaddr.h"

/* We use the POSIX regex functions to process regular expressions.
 * Type 'man regex' for more information about POSIX regex functions.
 */
#include <regex.h>

enum {
  TK_NOTYPE = 256, TK_EQ, TK_NEQ, TK_AND, TK_DIGIT, TK_HEX, TK_IDENTIFIER, TK_DEREF,

  /* TODO: Add more token types */

};

int precedence[] = {
  [TK_DEREF] = 3,
  ['+'] = 1, ['-'] = 1,
  ['*'] = 2, ['/'] = 2,
  [TK_EQ] = 0, [TK_NEQ] = 0,
  [TK_AND] = -1,
};

static struct rule {
  const char *regex;
  int token_type;
} rules[] = {

  /* TODO: Add more rules.
   * Pay attention to the precedence level of different rules.
   */

  {"[ ]+", TK_NOTYPE},  // spaces
  {"0x[0-9a-fA-F]+", TK_HEX}, // hex
  {"[0-9]+", TK_DIGIT}, // digits
  {"[0-9cstrfpa$]{3}", TK_IDENTIFIER}, // identifier
  {"\\+", '+'},         // plus
  {"-", '-'},           // minus
  {"\\*", '*'},         // mul or deref
  {"/",   '/'},         // div
  {"\\(", '('},         // left parentheses
  {"\\)", ')'},         // right parentheses
  {"!=", TK_NEQ},       // not equal
  {"&&", TK_AND},       // logical and
  {"==", TK_EQ},        // equal
};

#define NR_REGEX ARRLEN(rules)

static regex_t re[NR_REGEX] = {};

/* Rules are used for many times.
 * Therefore we compile them only once before any usage.
 */
void init_regex() {
  int i;
  char error_msg[128];
  int ret;

  for (i = 0; i < NR_REGEX; i ++) {
    ret = regcomp(&re[i], rules[i].regex, REG_EXTENDED);
    if (ret != 0) {
      regerror(ret, &re[i], error_msg, 128);
      panic("regex compilation failed: %s\n%s", error_msg, rules[i].regex);
    }
  }
}

typedef struct token {
  int type;
  char str[32];
} Token;

static Token tokens[65536] __attribute__((used)) = {};
static int nr_token __attribute__((used))  = 0;

static bool make_token(char *e) {
  int position = 0;
  int i;
  regmatch_t pmatch;

  nr_token = 0;

  while (e[position] != '\0') {
    /* Try all rules one by one. */
    for (i = 0; i < NR_REGEX; i ++) {
      if (regexec(&re[i], e + position, 1, &pmatch, 0) == 0 && pmatch.rm_so == 0) {
        char *substr_start = e + position;
        int substr_len = pmatch.rm_eo;

        // Log("match rules[%d] = \"%s\" at position %d with len %d: %.*s", i, rules[i].regex, position, substr_len, substr_len, substr_start);

        position += substr_len;

        /* TODO: Now a new token is recognized with rules[i]. Add codes
         * to record the token in the array `tokens'. For certain types
         * of tokens, some extra actions should be performed.
         */

        switch (rules[i].token_type) {
          case TK_EQ:
          case TK_NEQ:
          case TK_AND:
          case '+':
          case '-':
          case '*':
          case '/':
          case '(':
          case ')': tokens[nr_token++].type = rules[i].token_type; break;
          case TK_IDENTIFIER:
          case TK_HEX:
          case TK_DIGIT: tokens[nr_token].type = rules[i].token_type;
            // in case buffer overflow
            if (substr_len >= 32) {
              assert(0);
            }
            strncpy(tokens[nr_token].str, substr_start, substr_len);
            // strncpy don't fill the end null
            tokens[nr_token++].str[substr_len] = '\0';
            break;
          default: break;
        }

        assert(nr_token <= 65536);
        break;
      }
    }

    if (i == NR_REGEX) {
      printf("no match at position %d\n%s\n%*.s^\n", position, e, position, "");
      return false;
    }
  }

  return true;
}

// whether parentheses is matched 
bool matched(uint32_t p, uint32_t q) {
  uint32_t cnt = 0;

  // use counter as stack to match
  for (int i = p; i <= q; i++) {
    if (tokens[i].type == '(') {
      cnt++;
    } else if (tokens[i].type == ')' && cnt) {
      cnt--;
    } else if (tokens[i].type == ')' && !cnt) {
      cnt = 1;
      break;
    } else {
      continue;
    }
  }

  // traverse through all char and stack is empty
  if (cnt == 0){
    return true; 
  }else{ 
    return false; 
  }
}

// expression like (exp), use alg from manual
bool check_parentheses(uint32_t p, uint32_t q, bool *success) {
  uint32_t cnt = 0;

  // dont begin and end with parentheses
  bool not_surround = (tokens[p].type != '(' || tokens[q].type != ')');

  // use counter as stack to match
  for (int i = p; i <= q; i++) {
    if (tokens[i].type == '(') {
      cnt++;
    } else if (tokens[i].type == ')' && cnt) {
      cnt--;
    } else if (tokens[i].type == ')' && !cnt) {
      cnt = 1;
      break;
    } else {
      continue;
    }
  }

  // parentheses matched first(legal expression), then the left/right most parentheses matched
  if (cnt == 0 && !not_surround && matched(p + 1, q - 1)) {
    return true;
  } else if (cnt != 0) {
    *success = false;
    return false;
  } else {
    return false;
  }
}

bool is_operator(int ptr) {
  int type = tokens[ptr].type;
  return type == '+' || type == '-' || type == '*' || type == '/'\
  || type == TK_EQ || type == TK_NEQ || type == TK_AND || type == TK_DEREF;
}

bool is_precedence(int op1, int op2) {
  return precedence[op1] > precedence[op2];
}

int find_main_op(int p, int q) {
  uint32_t in_parentheses = 0;
  int ptr = 0;
  int op = 0;

  // scan from right to left(last calculate)
  for (int i = q; i >= p; i--) {
    int type = tokens[i].type;

    // operator in nested parentheses can't be main op
    if (type == ')') {
      in_parentheses += 1;
    } else if (type == '(') {
      in_parentheses -= 1;
    }

    // lowest precedence
    if (!is_operator(i) || in_parentheses) {
      continue;
    } else if (op == 0) {
      op = type; ptr = i;
    } else if (is_precedence(op, type)) {
      op = type; ptr = i;
    } else {
      continue;
    }
  }

  return ptr;
}

uint32_t eval(int p, int q, bool *success) {
  if (p > q) {
    assert(0);
  } else if (p == q) {
    // should be a decimal/ hex digit, or a register
    int type = tokens[p].type;
    assert(type==TK_IDENTIFIER || type == TK_DIGIT || type == TK_HEX);
    if (type == TK_IDENTIFIER) {
      return isa_reg_str2val(&tokens[p].str[1], success);
    } else {
      return strtoul(tokens[p].str, NULL, 0);
    }
  } else if (check_parentheses(p, q, success) == true) {
    return eval(p + 1, q - 1, success);
  } else {
    // invalid expression
    if (*success == false) {
      return -1;
    }
    // calculate recursively according to unary/binary op 
    int op_pos = find_main_op(p, q);
    uint32_t value1 = 0;
    if (tokens[op_pos].type != TK_DEREF) {
      value1 = eval(p, op_pos - 1, success);
    }
    uint32_t value2 = eval(op_pos + 1, q, success);

    switch (tokens[op_pos].type) {
      case '+': return value1 + value2;
      case '-': return value1 - value2;
      case '*': return value1 * value2;
      case '/': return value1 / value2;
      case TK_EQ: return value1 == value2;
      case TK_NEQ: return value1 != value2;
      case TK_AND: return value1 && value2;
      case TK_DEREF:  // read 4 bytes from memory
        vaddr_t vaddr = value2;
        word_t value = vaddr_read(vaddr, 4);
        return value;
      default: assert(0);
    }
  }
}

bool is_deref(int ptr) {
  int type = tokens[ptr].type;
  return type == '+' || type == '-' || type == '*' || type == '/'\
  || type == TK_EQ || type == TK_NEQ || type == TK_AND || type == '(';
}

word_t expr(char *e, bool *success) {
  if (!make_token(e)) {
    *success = false;
    return 0;
  }

  // seperate deref from multiply
  for (int i = 0; i < nr_token; i++) {
    if (tokens[i].type == '*' && (i == 0 || is_deref(i-1))) {
      tokens[i].type = TK_DEREF;
    }
  }

  /* TODO: Insert codes to evaluate the expression. */
  uint32_t value = eval(0, nr_token - 1, success);
  return value;
}

void calculator_test() {
  FILE *fp = fopen("/home/rom/ysyx-workbench/nemu/tools/gen-expr/build/input", "r");
  assert(fp != NULL);

  char line[65536];
  while (fgets(line, sizeof(line), fp) != NULL) {
    // substitute \n with \0
    line[strcspn(line, "\n")] = '\0';

    // extract res and exp, exp may include space
    char *res_str = strtok(line, " ");
    char *exp = &line[strlen(res_str) +1];
    if (res_str == NULL || exp == NULL) {
      continue;
    }

    bool flag = true;
    uint32_t res = strtoul(res_str, NULL, 0);
    uint32_t value = expr(exp, &flag);

    assert(res == value);
  }
  fclose(fp);
}
