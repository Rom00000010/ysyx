#include <common.h>
#include <iringbuf.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
using namespace std;

extern vector<uint8_t> flash_mem;

void init_sdb();
void init_elf(const char *elf_file);

void img_init(int argc, char **argv, vector<uint32_t> &mem)
{
    // get image path
    if (argc < 2)
    {
        cerr << "Usage: " << argv[0] << " <image_file>" << endl;
        exit(1);
    }
    string filename = argv[1];

    // open in binary mode
    ifstream file(filename, ios::binary);
    if (!file)
    {
        cerr << "Error opening file: " << filename << endl;
        exit(1);
    }

    // use istreambuf_iterator read complete content
    vector<unsigned char> buffer((istreambuf_iterator<char>(file)),
                                 istreambuf_iterator<char>());
    file.close();

    // if (buffer.size() % 4 != 0)
    // {
    //     cerr << "Error: Image size is not a multiple of 4 bytes." << endl;
    //     exit(1);
    // }

    memcpy(mem.data(), buffer.data(), buffer.size());
}

void init_flash(char **argv)
{
    string filename = argv[4];

    // open in binary mode
    ifstream file(filename, ios::binary);
    if (!file)
    {
        cerr << "Error opening file: " << filename << endl;
        exit(1);
    }

    // use istreambuf_iterator read complete content
    vector<unsigned char> buffer((istreambuf_iterator<char>(file)),
                                 istreambuf_iterator<char>());
    file.close();

    // if (buffer.size() % 4 != 0)
    // {
    //     cerr << "Error: Image size is not a multiple of 4 bytes." << endl;
    //     exit(1);
    // }

    memcpy(flash_mem.data(), buffer.data(), buffer.size());
    for(int i=0; i< 0x32 ; i++)
    {
        printf("flash_mem[%d]: %x\n", i, flash_mem[i]);
    }
}

void init_monitor(int argc, char **argv, vector<uint32_t> &mem)
{
    img_init(argc, argv, mem);

    init_flash(argv);

    init_sdb();

    initBuffer();

    init_elf(argv[2]);
}