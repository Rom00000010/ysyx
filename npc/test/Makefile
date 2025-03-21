all: test.bin

test.o: test.c
	riscv64-linux-gnu-gcc -std=gnu11 -g -O2 -MMD -Wall -Werror \
        -fno-asynchronous-unwind-tables \
        -fno-builtin \
        -fno-stack-protector \
        -Wno-main \
        -U_FORTIFY_SOURCE \
        -fvisibility=hidden \
        -fno-pic \
        -march=rv64g -mcmodel=medany -mstrict-align \
        -march=rv32e_zicsr -mabi=ilp32e \
        -static \
        -fdata-sections -ffunction-sections \
        -c -o test.o \
        test.c

test.elf: test.o linker.ld
	riscv64-linux-gnu-ld -z noexecstack \
        -Tlinker.ld \
        --defsym=_pmem_start=0x20000000 \
        --defsym=_entry_offset=0x0 \
        --gc-sections \
        -e _start \
        -melf32lriscv \
        -o test.elf test.o

test.bin: test.elf
	riscv64-linux-gnu-objcopy -S --set-section-flags .bss=alloc,contents \
        -O binary test.elf test.bin

clean:
	rm -f test.o test.elf test.bin *.d test.txt

