#include <common.h>
#include <macro.h>
#include <readline/history.h>
#include <readline/readline.h>

bool is_batch_mode = false;
extern bool stop;
extern svScope scope;
void cpu_exec(unsigned int n);
void init_regex();
void init_wp_pool();
uint32_t expr(char *e, bool *success);
int pmem_read(int addr);
void new_wp(char *exp, uint32_t val);
void watchpoint_display();
int delete_watchpoint(int no);

static char *rl_gets()
{
  static char *line_read = NULL;

  if (line_read)
  {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read)
  {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_info(char *args)
{
  // extract argument
  char *arg = strtok(NULL, " ");

  if (strcmp(arg, "r") == 0)
  {
    SET_REG
    print_rf();
  }
  else
  {
    assert(strcmp(arg, "w") == 0);
    watchpoint_display();
  }
  return 0;
}

static int cmd_c(char *args)
{
  cpu_exec(-1);
  return 0;
}

static int cmd_q(char *args)
{
  return -1;
}

static int cmd_si(char *args)
{
  /* extract the first argument */
  char *arg = strtok(NULL, " ");

  if (arg == NULL)
  {
    /* no argument given */
    cpu_exec(1);
  }
  else
  {
    uint64_t steps = 0;
    // convert char* to unsigned long long int
    steps = strtoull(arg, NULL, 0);
    assert(steps != 0);
    cpu_exec(steps);
  }
  return 0;
}

static int cmd_help(char *args);

static int cmd_p(char *args)
{
  bool success = true;
  uint32_t val = expr(args, &success);
  if (!success)
  {
    printf("illegal expression\n");
  }
  else
  {
    printf("%s = %d/0x%x\n", args, val, val);
  }
  return 0;
}

static int cmd_x(char *args)
{
  int i, j;
  bool success = true;
  // extract number and Expr
  char *num_str = strtok(NULL, " ");
  char *exp = &args[strlen(num_str) + 1];
  uint64_t num = strtoull(num_str, NULL, 0);

  // expression evaluation(decimal or hex direct addr)
  uint32_t vaddr = expr(exp, &success);

  if (success)
  {
    for (i = 0; i < num; i += 4)
    {
      // start address
      printf("\033[34m0x%x\033[0m: ", vaddr + 4 * i);
      for (j = 0; j < 4; j++)
      {
        uint32_t value = pmem_read(vaddr + 4 * i + 4 * j);
        printf("0x%08x    ", value);
      }
      printf("\n");
    }
  }

  return 0;
}

static int cmd_w(char *args)
{
#ifndef CONFIG_WATCHPOINT
  printf("Watchpoint is not enabled\n");
  return 0;
#endif

  bool success = true;
  uint32_t init_val = expr(args, &success);
  if (success)
  {
    printf("add watchpoint\n");
    new_wp(args, init_val);
  }
  return 0;
}

static int cmd_d(char *arg)
{
  int no = strtoul(arg, NULL, 0);
  if (delete_watchpoint(no))
  {
    printf("delete watchpoint %d\n", no);
  }
  return 0;
}

static struct
{
  const char *name;
  const char *description;
  int (*handler)(char *);
} cmd_table[] = {
    {"help", "Display information about all supported commands", cmd_help},
    {"c", "Continue the execution of the program", cmd_c},
    {"q", "Exit NEMU", cmd_q},
    {"si", "Exec N(1) Step instructions", cmd_si},
    {"info", "Register/watchpoint Info", cmd_info},
    {"x", "Scan memory at [exp, exp+N*4]", cmd_x},
    {"p", "Print value of Expression", cmd_p},
    {"w", "Add atchpoint", cmd_w},
    {"d", "Delete watchpoint", cmd_d},
    /* TODO: Add more commands */

};

#define NR_CMD ARRLEN(cmd_table)
static int cmd_help(char *args)
{
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL)
  {
    /* no argument given */
    for (i = 0; i < NR_CMD; i++)
    {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else
  {
    for (i = 0; i < NR_CMD; i++)
    {
      if (strcmp(arg, cmd_table[i].name) == 0)
      {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_mainloop()
{
  if (is_batch_mode)
  {
    cmd_c(NULL);
    return;
  }
  for (char *str; (str = rl_gets()) != NULL;)
  {
    stop = false;
    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL)
    {
      continue;
    }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end)
    {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    extern void sdl_clear_event_queue();
    sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i++)
    {
      if (strcmp(cmd, cmd_table[i].name) == 0)
      {
        if (cmd_table[i].handler(args) < 0)
        {
          return;
        }
        break;
      }
    }

    if (i == NR_CMD)
    {
      printf("Unknown command '%s'\n", cmd);
    }
  }
}

void init_sdb()
{
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
