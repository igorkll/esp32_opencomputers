#include "font.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <map.h>

static FILE* font;
#ifdef FONT_CACHE_METADATA
	static hashmap* cache_metadata;

	typedef struct {
		uint8_t metadata;
	} FontMetadataCache;
#endif

#ifdef FONT_CACHE_OFFSETS
	static hashmap* cache_offsets;
#endif

typedef struct {
	int offset;
	uint8_t metadata;
} FontOffset;

#ifdef FONT_CACHE_DATA
	static hashmap* cache_data;

	typedef struct {
		uint8_t* data;
		uint8_t metadata;
	} FontDataCache;
#endif

uint8_t _getMetadata(int offset) {
	#ifdef FONT_CACHE_DATA
	{
		FontMetadataCache* fontMetadataCache;
		if (hashmap_get(cache_metadata, &offset, sizeof(int), (uintptr_t*)(&fontMetadataCache)) != 0) {
			return fontMetadataCache->metadata;
		}
	}
	#endif

	fseek(font, offset, SEEK_SET);
	uint8_t metadata = 0;
	fread(&metadata, 1, 1, font);

	#ifdef FONT_CACHE_METADATA
		int* cpy_offset = malloc(sizeof(int));
		memcpy(cpy_offset, &offset, sizeof(int));
		
		FontMetadataCache* fontMetadataCache = malloc(sizeof(FontDataCache));
		fontMetadataCache->metadata = metadata;

		hashmap_set(cache_metadata, cpy_offset, sizeof(int), (uintptr_t)fontMetadataCache);
	#endif

	return metadata;
}

// ----------------------------------------------

void font_init() {
	font = fopen("/rom/font.bin", "rb");
	#ifdef FONT_CACHE_METADATA
		cache_metadata = hashmap_create();
	#endif
	#ifdef FONT_CACHE_OFFSETS
		cache_offsets = hashmap_create();
	#endif
	#ifdef FONT_CACHE_DATA
		cache_data = hashmap_create();
	#endif
}

char* font_ptrOffset(char* text, size_t offset) {
	while (offset > 0) {
        if ((*text >= 0xC2) && (*text <= 0xDF)) {
            text += 2;
        } else if ((*text >= 0xE0) && (*text <= 0xEF)) {
            text += 3;
        } else if ((*text >= 0xF0) && (*text <= 0xF7)) {
            text += 4;
        } else {
            text += 1;
        }
		offset--;
    }

	return text;
}

uchar font_toUChar(char* chr, uint8_t len) {
	uchar out = 0;
	for (size_t i = 0; i < len; i++) {
		out += chr[i] << (i * 8);
	}
	return out;
}

uint8_t font_charLen(char chr) {
    if (chr <= 0x7F) {
        return 1;
    } else if ((chr >= 0xC2) && (chr <= 0xDF)) {
        return 2;
    } else if ((chr >= 0xE0) && (chr <= 0xEF)) {
		return 3;
    } else if ((chr >= 0xF0) && (chr <= 0xF7)) {
		return 4;
    }

	return 1;
}

uint8_t font_ucharLen(uchar uchr) {
	char* arr = (char*)(&uchr);
	return font_charLen(arr[0]);
}

int font_len(char* text, int len) {
	int length = 0;
	bool autolen = len == 0;

    while ((autolen && *text) || len > 0) {
		uint8_t llen = font_charLen(*text);
		text += llen;
		len -= llen;
        length++;
    }

    return length;
}

static FontOffset _find(uchar uchr) {
	uint8_t* chr = (uint8_t*)(&uchr);
	uint8_t len = font_ucharLen(uchr);

	uint8_t charcode[sizeof(uchar)];

	if (len == 1) {
		int offset = chr[0] * 19;
		uint8_t metadata = _getMetadata(offset);
		if (metadata != 2) {
			return (FontOffset) {
				.offset = offset,
				.metadata = metadata
			};
		}
	}

	#ifdef FONT_CACHE_OFFSETS
		FontOffset* data;
		if (hashmap_get(cache_offsets, chr, len, (uintptr_t*)(&data)) != 0) {
			return *data;
		}
	#endif

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
				#ifdef FONT_CACHE_OFFSETS
					uint8_t* cpy_chr = malloc(len);
					memcpy(cpy_chr, chr, len);

					FontOffset* cpy_val = malloc(sizeof(FontOffset));
					cpy_val->offset = offset;
					cpy_val->metadata = metadata;

					hashmap_set(cache_offsets, cpy_chr, len, (uintptr_t)cpy_val);
				#endif

				return (FontOffset) {
					.offset = offset,
					.metadata = metadata
				};
			}
		}

		bool isWide = metadata & 0b00000001;
		offset += 2 + charlen + (isWide ? 32 : 16);
	} while (!feof(font));

	FontOffset fontOffset = _find(FONT_UNKNOWN_CHARCODE);
	#ifdef FONT_CACHE_OFFSETS
		uint8_t* cpy_chr = malloc(len);
		memcpy(cpy_chr, chr, len);

		FontOffset* cpy_val = malloc(sizeof(FontOffset));
		cpy_val->offset = fontOffset.offset;
		cpy_val->metadata = fontOffset.metadata;

		hashmap_set(cache_offsets, cpy_chr, len, (uintptr_t)cpy_val);
	#endif
	return fontOffset;
}

int font_findOffset(uchar uchr) {
	FontOffset FontOffset = _find(uchr);
	return FontOffset.offset;
}

uint8_t font_charWidth(uchar uchr) {
	if (uchr < 255) return 1;

	FontOffset fontOffset = _find(uchr);
	return (fontOffset.metadata & 0b00000001) + 1;
}

bool font_readData(uint8_t* data, int offset) {
	#ifdef FONT_CACHE_DATA
	{
		FontDataCache* fontDataCache;
		if (hashmap_get(cache_data, &offset, sizeof(int), (uintptr_t*)(&fontDataCache)) != 0) {
			bool isWide = fontDataCache->metadata & 0b00000001;
			size_t charsize = isWide ? 32 : 16;
			memcpy(data, fontDataCache->data, charsize);
			return isWide;
		}
	}
	#endif

	fseek(font, offset, SEEK_SET);

	uint8_t metadata;
	fread(&metadata, 1, 1, font);
	
	uint8_t charlen;
	fread(&charlen, 1, 1, font);

	fseek(font, charlen, SEEK_CUR);

	bool isWide = metadata & 0b00000001;
	size_t charsize = isWide ? 32 : 16;
	fread(data, 1, charsize, font);

	#ifdef FONT_CACHE_DATA
		int* cpy_offset = malloc(sizeof(int));
		memcpy(cpy_offset, &offset, sizeof(int));
		
		FontDataCache* fontDataCache = malloc(sizeof(FontDataCache));
		fontDataCache->data = malloc(charsize);
		fontDataCache->metadata = metadata;
		memcpy(fontDataCache->data, data, charsize);

		hashmap_set(cache_data, cpy_offset, sizeof(int), (uintptr_t)fontDataCache);
	#endif

	return isWide;
}

bool font_readPixel(uint8_t* data, uint8_t x, uint8_t y) {
	uint8_t offset = y + (x >= 8 ? 8 : 0);
	uint8_t mask = 1 << (7 - (x % 8));
	return data[offset] & mask;
}