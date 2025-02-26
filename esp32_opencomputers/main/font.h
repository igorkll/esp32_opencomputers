#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define FONT_MAXCHAR 32
#define FONT_CACHE_OFFSETS
#define FONT_CACHE_DATA

typedef uint32_t uchar;
#define UCHAR_SPACE ((uchar)(' '))

void font_init();
char* font_ptrOffset(char* text, size_t offset);
uchar font_toUChar(char* chr, size_t len);
int font_ucharLen(uchar uchr);
int font_len(char* text, int len);
int font_findOffset(uchar uchr);
uint8_t font_charWidth(int offset);
bool font_isWide(int offset);
bool font_readData(uint8_t* data, int offset);
bool font_readPixel(uint8_t* data, uint8_t x, uint8_t y);