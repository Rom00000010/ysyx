#ifndef IRINGBUF
#define IRINGBUF

#define BUFFER_SIZE 15

typedef struct {
  char buffer[BUFFER_SIZE][128];  
  int head;                 // next position to be write
  int tail;                 // oldest element
  int size;         
} CircularBuffer;

void initBuffer();
void writeBuffer(char *data);
void printBuffer();
#endif
