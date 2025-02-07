#ifndef IRINGBUF
#define IRINGBUF
#include <string.h>
#include <stdio.h>

#define BUFFER_SIZE 15

typedef struct {
  char buffer[BUFFER_SIZE][128];  
  int head;                 // next position to be write
  int tail;                 // oldest element
  int size;         
} CircularBuffer;

void initBuffer(CircularBuffer *cb);
void writeBuffer(CircularBuffer *cb, char *data);
void printBuffer(CircularBuffer *cb);
#endif
