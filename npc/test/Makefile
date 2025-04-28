all:
	riscv64-linux-gnu-gcc   -nostdlib -nostartfiles -ffreestanding \
                        -march=rv32e_zicsr -mabi=ilp32e \
                        -T linker.ld -Wl,-e,_start \
                        test.s -o test.elf
	riscv64-linux-gnu-objcopy -O binary -j .text test.elf test.bin
	riscv64-linux-gnu-objdump -d test.elf > test.txt

run:
	../obj_dir/VysyxSoCFull ./test.bin
