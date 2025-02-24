#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define FONT_MAXCHAR 32
#define FONT_CACHE_OFFSETS
#define FONT_CACHE_DATA

void font_init();
int font_findOffset(char* chr, size_t len);
uint8_t font_charWidth(int offset);
bool font_isWide(int offset);
bool font_readData(uint8_t* data, int offset);
bool font_readPixel(uint8_t* data, uint8_t x, uint8_t y);