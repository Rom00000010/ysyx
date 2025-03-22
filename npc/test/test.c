#define UART_BASE 0x00521000L
#define UART_TX   0x0L
void _start() {
    *(volatile char *)(UART_BASE + UART_TX) = 'A';
        while (1);
}
