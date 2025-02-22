#include <stdint.h>
#include <stdbool.h>

void font_init();
int font_findOffset(char* chr, size_t len);
uint8_t font_charWidth(int offset);
bool font_isWide(int offset);