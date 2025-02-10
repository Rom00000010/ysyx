#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cassert>
#include <regex.h>
#include <cstdio>

uint32_t pmem_read(uint32_t addr);
uint32_t expr(char *e, bool *success);

#define NR_WP 32

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;
  char exp[100];
  uint32_t val;
  /* TODO: Add more members if necessary */

} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;
static int no = -1;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

/* TODO: Implement the functionality of watchpoint */

void new_wp(char *exp, uint32_t val) {
  // watchpoints is run out
  if (free_ == NULL) {
    assert(0);
  }

  // tail insert into using
  if (head == NULL) {
    head = free_;
  } else {
    WP *cur = head;
    while (cur->next != NULL) {
      cur = cur->next;
    }
    cur->next = free_;
  }

  // head delete from free
  WP *allocated = free_;
  free_ = free_->next;

  allocated->next = NULL;
  allocated->val = val;
  strcpy(allocated->exp, exp);
}

void free_wp(WP *wp) {
  assert(wp != NULL);

  // find the wp before to be deleted
  WP *cur = head, *prev = NULL;
  while (cur->NO != wp->NO) {
    prev = cur;
    cur = cur->next;
  }

  WP *freed;
  if (prev == NULL) {
    // first element
    freed = cur;
    head = freed->next;
  } else {
    freed = cur;
    prev->next = freed->next;
    freed->next = NULL;
  }


  // head insert place back to free
  freed->next = free_;
  free_ = freed;
}

uint32_t scan_watchpoints(bool *success) {
  WP *cur = head;
  // different from changed flag
  bool calculate_flag=true;
  uint32_t new_val = 0, old_val = 0;

  // find first watchpoint triggered
  while (cur != NULL) {
    new_val = expr(cur->exp, &calculate_flag);
    if (cur->val != new_val) {
      no = cur->NO;
      old_val = cur->val;
      cur->val = new_val;
      *success = true;
      break;
    }
    cur = cur->next;
  }

  return old_val;
}

uint32_t watchpoint_val() {
  return wp_pool[no].val;
}

int watchpoint_no() {
  return no;
}

char *watchpoint_exp() {
  return wp_pool[no].exp;
}

void watchpoint_display() {
  WP *cur = head;
  printf("NO  expression\n");
  while (cur != NULL) {
    printf("%d      %s\n", cur->NO, cur->exp);
    cur = cur->next;
  }
}

int delete_watchpoint(int no) {
  if(head == NULL){
    return 0;
  }

  WP *cur = head;
  while (cur->NO != no) {
    cur = cur->next;
  }
  free_wp(cur);
  return 1;
}
