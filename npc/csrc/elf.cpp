#include <elf.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <cassert>

FILE *elf_fp = NULL;
Elf32_Sym *symtab = NULL;
char *strtab = NULL;
int nsyms = 0;

void init_elf(const char *elf_file) {
  FILE *fp = fopen(elf_file, "r");
  assert(fp);
  elf_fp = fp;

  // read elf-header
  Elf32_Ehdr ehdr;
  size_t num = fread(&ehdr, sizeof(ehdr), 1, fp);
  assert(num == 1);

  // read section header table
  Elf32_Shdr *sh_table = (Elf32_Shdr *)malloc(ehdr.e_shentsize * ehdr.e_shnum);
  assert(sh_table);

  fseek(fp, ehdr.e_shoff, SEEK_SET);
  num = fread(sh_table, ehdr.e_shentsize, ehdr.e_shnum, fp);
  assert(num == ehdr.e_shnum);

  // read section header str table
  Elf32_Shdr sh_strtab = sh_table[ehdr.e_shstrndx];
  char *section_strtab = (char *)malloc(sh_strtab.sh_size);
  assert(section_strtab);

  fseek(fp, sh_strtab.sh_offset, SEEK_SET);
  num = fread(section_strtab, sh_strtab.sh_size, 1, fp);
  assert(num == 1);

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
  assert(symtab_sh && strtab_sh);

  // read symbol table
  nsyms = symtab_sh->sh_size / sizeof(Elf32_Sym);
  symtab = (Elf32_Sym *)malloc(symtab_sh->sh_size);
  assert(symtab);

  fseek(fp, symtab_sh->sh_offset, SEEK_SET);
  num = fread(symtab, sizeof(Elf32_Sym), nsyms, fp);
  assert(num == nsyms);

  // read string table
  strtab = (char *)malloc(strtab_sh->sh_size);
  assert(strtab);

  fseek(fp, strtab_sh->sh_offset, SEEK_SET);
  num = fread(strtab, strtab_sh->sh_size, 1, fp);
  assert(num == 1);

  free(sh_table);
  free(section_strtab);

}

const char *func_name(uint32_t addr){
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
