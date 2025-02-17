#include <am.h>
#include <nemu.h>

#define SYNC_ADDR (VGACTL_ADDR + 8)

uint32_t width;
uint32_t height;

void __am_gpu_init() {
  uint32_t info = inl(VGACTL_ADDR);
  width = info >> 16;
  height = info & 0xffff; 
  // uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
  // for(int i = 0; i < width * height; i++) fb[i] = i;
  // outb(SYNC_ADDR, 1);
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
  *cfg = (AM_GPU_CONFIG_T) {
    .present = true, .has_accel = false,
    .width = 0, .height = 0,
    .vmemsz = 0
  };
  uint32_t info = inl(VGACTL_ADDR);
  cfg->width = info >> 16;
  cfg->height = info & 0xffff;
  cfg->vmemsz = cfg->width * cfg->height;
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) {
  int x = ctl->x, y = ctl->y, w = ctl->w, h = ctl->h;
  void *pixels = ctl->pixels;
  for(int i=0; i<h; i++){
    for(int j=0; j<w; j++){
      if(y+i<height && x+j<width){
        uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
        fb[(y+i)*width + (x+j)] = ((uint32_t *)pixels)[i*w+j];
      }
    }
  }
  if (ctl->sync) {
    outb(SYNC_ADDR, 1);
  }
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
  status->ready = true;
}
