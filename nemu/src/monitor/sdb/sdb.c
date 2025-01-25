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
#include <cpu/cpu.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "sdb.h"
#include "memory/vaddr.h"

static int is_batch_mode = false;

void init_regex();
void init_wp_pool();
void new_wp(char *exp, uint32_t val);
void watchpoint_display();
int delete_watchpoint();

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char *rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}


static int cmd_q(char *args) {
  nemu_state.state = NEMU_QUIT;
  return -1;
}

static int cmd_si(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");

  if (arg == NULL) {
    /* no argument given */
    cpu_exec(1);
  } else {
    uint64_t steps = 0;
    // convert char* to unsigned long long int
    steps = strtoull(arg, NULL, 0);
    assert(steps != 0);
    cpu_exec(steps);
  }
  return 0;
}

static int cmd_info(char *args) {
  // extract argument
  char *arg = strtok(NULL, " ");

  if (strcmp(arg, "r") == 0) {
    isa_reg_display();
  } else {
    assert(strcmp(arg, "w") == 0);
    watchpoint_display();
  }
  return 0;
}

static int cmd_x(char *args) {
  int i, j;
  bool success = true;
  // extract number and Expr
  char *num_str = strtok(NULL, " ");
  char *exp = &args[strlen(num_str) +1];
  uint64_t num = strtoull(num_str, NULL, 0);

  // expression evaluation(decimal or hex direct addr)
  vaddr_t vaddr = expr(exp, &success);

  if (success) {
    for (i = 0; i < num; i += 4) {
      // start address
      printf("%s0x%x%s: ", ANSI_FG_BLUE, vaddr + 4 * i, ANSI_NONE);
      for (j = 0; j < 4; j++) {
        word_t value = vaddr_read(vaddr + 4 * i + 4 * j, 4);
        printf("0x%08x    ", value);
      }
      printf("\n");
    }
  }

  return 0;
}

static int cmd_p(char *args) {
  bool success = true;
  uint32_t val = expr(args, &success);
  if (!success) {
    printf("illegal expression\n");
  } else {
    printf("%s = %d/0x%x\n", args, val, val);
  }
  return 0;
}

static int cmd_w(char *args) {
#ifndef CONFIG_WATCHPOINT
  printf("Watchpoint is not enabled\n");
  return 0;
#endif

  bool success = true;
  uint32_t init_val = expr(args, &success);
  if (success) {
    printf("add watchpoint\n");
    new_wp(args, init_val);
  }
  return 0;
}

static int cmd_d(char *arg) {
  int no = strtoul(arg, NULL, 0);
  if (delete_watchpoint(no)) {
    printf("delete watchpoint %d\n", no);
  }
  return 0;
}

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler)(char *);
} cmd_table [] = {
  { "help", "Display information about all supported commands", cmd_help },
  { "c", "Continue the execution of the program", cmd_c },
  { "q", "Exit NEMU", cmd_q },
  { "si", "Exec N(1) Step instructions", cmd_si},
  { "info", "Register/watchpoint Info", cmd_info},
  { "x", "Scan memory at [exp, exp+N*4]", cmd_x},
  { "p", "Print value of Expression", cmd_p},
  { "w", "Add atchpoint", cmd_w},
  { "d", "Delete watchpoint", cmd_d},
  /* TODO: Add more commands */

};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL) {
    /* no argument given */
    for (i = 0; i < NR_CMD; i ++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  } else {
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode() {
  is_batch_mode = true;
}

void sdb_mainloop() {
  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  for (char *str; (str = rl_gets()) != NULL;) {
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL) { continue; }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end) {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    extern void sdl_clear_event_queue();
    sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(cmd, cmd_table[i].name) == 0) {
        if (cmd_table[i].handler(args) < 0) { return; }
        break;
      }
    }

    if (i == NR_CMD) { printf("Unknown command '%s'\n", cmd); }
  }
}

void init_sdb() {
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
