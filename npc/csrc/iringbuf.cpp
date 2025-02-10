#include <iringbuf.h>

static CircularBuffer iringbuf; 

void initBuffer() {
  iringbuf.head = 0;
  iringbuf.tail = 0;
  iringbuf.size = 0;
}

void writeBuffer(char *data) {
  strcpy(iringbuf.buffer[iringbuf.head], data);  
  iringbuf.head = (iringbuf.head + 1) % BUFFER_SIZE;  
  if (iringbuf.size < BUFFER_SIZE) {
    iringbuf.size++;  
  } else {
    iringbuf.tail = (iringbuf.tail + 1) % BUFFER_SIZE;
  }
}

void printBuffer() {
  if (iringbuf.size == 0) {
    printf("Buffer is empty.\n");
    return;
  }

  int i = iringbuf.tail;
  printf("%s\n", iringbuf.buffer[i]);
  i = (i + 1) % BUFFER_SIZE;

  while (i != iringbuf.head) {
    printf("%s\n", iringbuf.buffer[i]);
    i = (i + 1) % BUFFER_SIZE;  
  }
}
