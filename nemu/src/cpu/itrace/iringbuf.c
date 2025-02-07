#include <cpu/iringbuf.h>
void initBuffer(CircularBuffer *cb) {
  cb->head = 0;
  cb->tail = 0;
  cb->size = 0;
}

void writeBuffer(CircularBuffer *cb, char *data) {
  strcpy(cb->buffer[cb->head], data);  
  cb->head = (cb->head + 1) % BUFFER_SIZE;  
  if (cb->size < BUFFER_SIZE) {
    cb->size++;  
  } else {
    cb->tail = (cb->tail + 1) % BUFFER_SIZE;
  }
}

void printBuffer(CircularBuffer *cb) {
  if (cb->size == 0) {
    printf("Buffer is empty.\n");
    return;
  }

  int i = cb->tail;
  printf("%s\n", cb->buffer[i]);
  i = (i + 1) % BUFFER_SIZE;

  while (i != cb->head) {
    printf("%s\n", cb->buffer[i]);
    i = (i + 1) % BUFFER_SIZE;  
  }
}
