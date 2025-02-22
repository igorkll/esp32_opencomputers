#include "font.h"
#include "stdio.h"
#include "string.h"

FILE* font;

uint8_t _charWidth(int offset) {
	fseek(font, 0, SEEK_SET);
	uint8_t metadata = 0;
	fread(&metadata, 1, 1, font);
	return metadata;
}

// ----------------------------------------------

void font_init() {
	font = fopen("/storage/font.bin", "rb");
}

int font_findOffset(char* chr, size_t len) {
	uint8_t charcode[8];
	int offset = 0;
	while (true) {
		fseek(font, offset + 1, SEEK_SET);
		
		uint8_t charlen;
		fread(charlen, 1, 1, font);

		if (charlen == len) {
			fread(charcode, 1, charlen, font);
			if (memcpy(charcode, chr, len)) {
				return offset;
			}
		}
	}
	return -1;
}

uint8_t font_charWidth(int offset) {
	return _charWidth(offset) & 0b00000001;
}

bool font_isWide(int offset) {
	return font_charWidth(offset) > 0;
}