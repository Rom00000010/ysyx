AM_SRCS := riscv/ysyxsoc/start.S \
           riscv/ysyxsoc/trm.c \
           riscv/ysyxsoc/ioe.c \
           riscv/ysyxsoc/timer.c \
           riscv/ysyxsoc/input.c \
           riscv/ysyxsoc/cte.c \
           riscv/ysyxsoc/trap.S \
		   riscv/ysyxsoc/bootloader.c \
           platform/dummy/vme.c \
           platform/dummy/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDSCRIPTS += $(AM_HOME)/scripts/ysyxsoc-linker.ld
LDFLAGS   += --defsym=_pmem_start=0x80000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start #--print-map

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = The insert-arg rule in Makefile will insert mainargs here.
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=\""$(MAINARGS_PLACEHOLDER)"\"

insert-arg: image
	@python $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) "$(MAINARGS_PLACEHOLDER)" "$(mainargs)"

image: image-dep
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) -S -j .entry -O binary $(IMAGE).elf entry.bin
	@$(OBJCOPY) -S -j .text -j .rodata -j .data.extra -j .data -j .bss.extra -j .bss -O binary $(IMAGE).elf psram.bin
	@$(OBJCOPY) -S -j .ssbl -O binary $(IMAGE).elf ssbl.bin
	@cat entry.bin ssbl.bin psram.bin > $(IMAGE).bin

run: insert-arg
	@echo "simulate" $(IMAGE).bin
	@$(NPC_HOME)/obj_dir/VysyxSoCFull $(IMAGE).bin $(IMAGE).elf $(NEMU_HOME)/build/riscv32-nemu-interpreter-so

gdb: insert-arg
	@gdb --args $(NPC_HOME)/obj_dir/VysyxSoCFull $(IMAGE).bin $(IMAGE).elf $(NEMU_HOME)/build/riscv32-nemu-interpreter-so
.PHONY: insert-arg
