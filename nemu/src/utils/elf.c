#include <common.h>
#include <elf.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

FILE *elf_fp = NULL;
Elf32_Sym *symtab = NULL;
char *strtab = NULL;
int nsyms = 0;

void init_elf(const char *elf_file) {
  FILE *fp = fopen(elf_file, "r");
  Assert(fp, "Can not open '%s'", elf_file);
  elf_fp = fp;

  Log("open elf file %s", elf_file ? elf_file : NULL);

  // read elf-header
  Elf32_Ehdr ehdr;
  size_t num = fread(&ehdr, sizeof(ehdr), 1, fp);
  Assert(num == 1, "Failed to read ELF header\n");

  // read section header table
  Elf32_Shdr *sh_table = malloc(ehdr.e_shentsize * ehdr.e_shnum);
  Assert(sh_table, "Memory allocation error\n");

  fseek(fp, ehdr.e_shoff, SEEK_SET);
  num = fread(sh_table, ehdr.e_shentsize, ehdr.e_shnum, fp);
  Assert(num == ehdr.e_shnum, "Failed to read section headers\n");

  // read section header str table
  Elf32_Shdr sh_strtab = sh_table[ehdr.e_shstrndx];
  char *section_strtab = malloc(sh_strtab.sh_size);
  Assert(section_strtab, "Memory allocation error\n");

  fseek(fp, sh_strtab.sh_offset, SEEK_SET);
  num = fread(section_strtab, sh_strtab.sh_size, 1, fp);
  Assert(num == 1, "Failed to read section header string table\n");

  // find symbol table header and string table header
  Elf32_Shdr *symtab_sh = NULL;
  Elf32_Shdr *strtab_sh = NULL;
  for (int i = 0; i < ehdr.e_shnum; i++) {
    const char *sec_name = section_strtab + sh_table[i].sh_name;
    if (strcmp(sec_name, ".symtab") == 0) {
      symtab_sh = &sh_table[i];
    } else if (strcmp(sec_name, ".strtab") == 0) {
      strtab_sh = &sh_table[i];
    }
  }
  Assert(symtab_sh && strtab_sh, "Can't find symbol table or string table\n");

  // read symbol table
  nsyms = symtab_sh->sh_size / sizeof(Elf32_Sym);
  symtab = malloc(symtab_sh->sh_size);
  Assert(symtab, "Memory allocation error\n");

  fseek(fp, symtab_sh->sh_offset, SEEK_SET);
  num = fread(symtab, sizeof(Elf32_Sym), nsyms, fp);
  Assert(num == nsyms, "Failed to read symbol table");

  // read string table
  strtab = malloc(strtab_sh->sh_size);
  Assert(strtab, "Memory allocation error\n");

  fseek(fp, strtab_sh->sh_offset, SEEK_SET);
  num = fread(strtab, strtab_sh->sh_size, 1, fp);
  Assert(num == 1, "Failed to read string table\n");

  Log("read elf file %s into memory", elf_file ? elf_file : NULL);
  free(sh_table);
  free(section_strtab);

}

const char *func_name(vaddr_t addr){
  const char *name = "???";

  for(int i=0; i<nsyms; i++){
    if(ELF32_ST_TYPE(symtab[i].st_info) != STT_FUNC){
      continue;
    }

    uint32_t start = symtab[i].st_value;
    uint32_t size = symtab[i].st_size;
    if(addr >= start && addr < start + size){
      name = strtab + symtab[i].st_name;
      break;
    }
  }

  return name;
}
