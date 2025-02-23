#include "font.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

FILE* font;

uint8_t _getMetadata(int offset) {
	fseek(font, offset, SEEK_SET);
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

	if (len == 1) {
		int offset = chr[0] * 19;
		fseek(font, offset, SEEK_SET);

		uint8_t metadata;
		fread(&metadata, 1, 1, font);

		if (metadata != 2) {
			return offset;
		}
	}

	int offset = 0;
	do {
		fseek(font, offset, SEEK_SET);

		uint8_t metadata;
		fread(&metadata, 1, 1, font);
		
		uint8_t charlen;
		fread(&charlen, 1, 1, font);

		if (metadata != 2 && charlen == len) {
			fread(charcode, 1, charlen, font);
			if (memcmp(charcode, chr, len) == 0) {
				return offset;
			}
		}

		bool isWide = metadata & 0b00000001;
		offset += 2 + charlen + (isWide ? 32 : 16);
	} while (!feof(font));
	return -1;
}

uint8_t font_charWidth(int offset) {
	return _getMetadata(offset) & 0b00000001;
}

bool font_isWide(int offset) {
	return font_charWidth(offset) > 1;
}

bool font_readData(uint8_t* data, int offset) {
	uint8_t metadata = _getMetadata(offset);
	
	uint8_t charlen;
	fread(&charlen, 1, 1, font);
	fseek(font, charlen, SEEK_CUR);

	bool isWide = metadata & 0b00000001;
	fread(data, 1, isWide ? 32 : 16, font);
	return isWide;
}

bool font_readPixel(uint8_t* data, uint8_t x, uint8_t y) {
	uint8_t offset = y + (x >= 8 ? 8 : 0);
	uint8_t mask = 1 << (7 - (x % 8));
	return data[offset] & mask;
}