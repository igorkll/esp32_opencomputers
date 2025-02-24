#include "font.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <map.h>

FILE* font;
#ifdef FONT_CACHE_OFFSETS
	hashmap* cache_offsets;
#endif
#ifdef FONT_CACHE_DATA
	hashmap* cache_data;
#endif

uint8_t _getMetadata(int offset) {
	fseek(font, offset, SEEK_SET);
	uint8_t metadata = 0;
	fread(&metadata, 1, 1, font);
	return metadata;
}

// ----------------------------------------------

void font_init() {
	font = fopen("/storage/font.bin", "rb");
	#ifdef FONT_CACHE_OFFSETS
		cache_offsets = hashmap_create();
	#endif
	#ifdef FONT_CACHE_DATA
		cache_data = hashmap_create();
	#endif
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

	#ifdef FONT_CACHE_OFFSETS
		int* offsetPtr;
		if (hashmap_get(cache_offsets, chr, len, &offsetPtr) != 0) {
			return *offsetPtr;
		}
	#endif

	int offset = -1;
	do {
		fseek(font, offset, SEEK_SET);

		uint8_t metadata;
		fread(&metadata, 1, 1, font);
		
		uint8_t charlen;
		fread(&charlen, 1, 1, font);

		if (metadata != 2 && charlen == len) {
			fread(charcode, 1, charlen, font);
			if (memcmp(charcode, chr, len) == 0) {
				break;
			}
		}

		bool isWide = metadata & 0b00000001;
		offset += 2 + charlen + (isWide ? 32 : 16);
	} while (!feof(font));

	#ifdef FONT_CACHE_OFFSETS
		char* cpy_chr = malloc(len);
		int* cpy_val = malloc(sizeof(int));
		memcpy(cpy_chr, chr, len);
		memcpy(cpy_val, &offset, sizeof(int));
		hashmap_set(cache_offsets, cpy_chr, len, cpy_val);
	#endif

	return offset;
}

uint8_t font_charWidth(int offset) {
	return _getMetadata(offset) & 0b00000001;
}

bool font_isWide(int offset) {
	return font_charWidth(offset) > 1;
}

#ifdef FONT_CACHE_DATA
	typedef struct {
		uint8_t* data;
		uint8_t metadata;
	} FontDataCache;
#endif

bool font_readData(uint8_t* data, int offset) {
	
	#ifdef FONT_CACHE_DATA
	{
		FontDataCache* fontDataCache;
		if (hashmap_get(cache_data, &offset, sizeof(offset), &fontDataCache) != 0) {
			bool isWide = fontDataCache->metadata & 0b00000001;
			size_t charsize = isWide ? 32 : 16;
			memcpy(data, fontDataCache->data, charsize);
			return isWide;
		}
	}
	#endif

	uint8_t metadata = _getMetadata(offset);
	
	uint8_t charlen;
	fread(&charlen, 1, 1, font);
	fseek(font, charlen, SEEK_CUR);

	bool isWide = metadata & 0b00000001;
	size_t charsize = isWide ? 32 : 16;
	fread(data, 1, charsize, font);

	#ifdef FONT_CACHE_DATA
		FontDataCache* fontDataCache = malloc(sizeof(FontDataCache));
		fontDataCache->data = malloc(charsize);
		fontDataCache->metadata = metadata;
		memcpy(fontDataCache->data, data, charsize);

		hashmap_set(cache_data, &offset, sizeof(offset), fontDataCache);
	#endif

	return isWide;
}

bool font_readPixel(uint8_t* data, uint8_t x, uint8_t y) {
	uint8_t offset = y + (x >= 8 ? 8 : 0);
	uint8_t mask = 1 << (7 - (x % 8));
	return data[offset] & mask;
}