#include "canvas.h"
#include <stdint.h>
#include "funcs.h"

#define BYTES_PER_COLOR 2

static uint8_t _blackColorIndex = 16;
static uint8_t _whiteColorIndex = 255;

static canvas_color _defaultTier2Palette[] = {0xFFFF, 0xFE66, 0xCB39, 0x64DF, 0xFFE6, 0x3666, 0xFB33, 0x3186, 0xCE79, 0x3333, 0x9999, 0x3193, 0x6180, 0x3320, 0xF986, 0x0000};
static canvas_color _defaultPalette[] = {0x0861, 0x18E3, 0x2965, 0x39E7, 0x4A49, 0x5ACB, 0x6B4D, 0x7BCF, 0x8430, 0x94B2, 0xA534, 0xB5B6, 0xC618, 0xD69A, 0xE71C, 0xF79E, 0x0000, 0x0008, 0x0010, 0x0017, 0x001F, 0x0120, 0x0128, 0x0130, 0x0137, 0x013F, 0x0240, 0x0248, 0x0250, 0x0257, 0x025F, 0x0360, 0x0368, 0x0370, 0x0377, 0x037F, 0x0480, 0x0488, 0x0490, 0x0497, 0x049F, 0x05A0, 0x05A8, 0x05B0, 0x05B7, 0x05BF, 0x06C0, 0x06C8, 0x06D0, 0x06D7, 0x06DF, 0x07E0, 0x07E8, 0x07F0, 0x07F7, 0x07FF, 0x3000, 0x3008, 0x3010, 0x3017, 0x301F, 0x3120, 0x3128, 0x3130, 0x3137, 0x313F, 0x3240, 0x3248, 0x3250, 0x3257, 0x325F, 0x3360, 0x3368, 0x3370, 0x3377, 0x337F, 0x3480, 0x3488, 0x3490, 0x3497, 0x349F, 0x35A0, 0x35A8, 0x35B0, 0x35B7, 0x35BF, 0x36C0, 0x36C8, 0x36D0, 0x36D7, 0x36DF, 0x37E0, 0x37E8, 0x37F0, 0x37F7, 0x37FF, 0x6000, 0x6008, 0x6010, 0x6017, 0x601F, 0x6120, 0x6128, 0x6130, 0x6137, 0x613F, 0x6240, 0x6248, 0x6250, 0x6257, 0x625F, 0x6360, 0x6368, 0x6370, 0x6377, 0x637F, 0x6480, 0x6488, 0x6490, 0x6497, 0x649F, 0x65A0, 0x65A8, 0x65B0, 0x65B7, 0x65BF, 0x66C0, 0x66C8, 0x66D0, 0x66D7, 0x66DF, 0x67E0, 0x67E8, 0x67F0, 0x67F7, 0x67FF, 0x9800, 0x9808, 0x9810, 0x9817, 0x981F, 0x9920, 0x9928, 0x9930, 0x9937, 0x993F, 0x9A40, 0x9A48, 0x9A50, 0x9A57, 0x9A5F, 0x9B60, 0x9B68, 0x9B70, 0x9B77, 0x9B7F, 0x9C80, 0x9C88, 0x9C90, 0x9C97, 0x9C9F, 0x9DA0, 0x9DA8, 0x9DB0, 0x9DB7, 0x9DBF, 0x9EC0, 0x9EC8, 0x9ED0, 0x9ED7, 0x9EDF, 0x9FE0, 0x9FE8, 0x9FF0, 0x9FF7, 0x9FFF, 0xC800, 0xC808, 0xC810, 0xC817, 0xC81F, 0xC920, 0xC928, 0xC930, 0xC937, 0xC93F, 0xCA40, 0xCA48, 0xCA50, 0xCA57, 0xCA5F, 0xCB60, 0xCB68, 0xCB70, 0xCB77, 0xCB7F, 0xCC80, 0xCC88, 0xCC90, 0xCC97, 0xCC9F, 0xCDA0, 0xCDA8, 0xCDB0, 0xCDB7, 0xCDBF, 0xCEC0, 0xCEC8, 0xCED0, 0xCED7, 0xCEDF, 0xCFE0, 0xCFE8, 0xCFF0, 0xCFF7, 0xCFFF, 0xF800, 0xF808, 0xF810, 0xF817, 0xF81F, 0xF920, 0xF928, 0xF930, 0xF937, 0xF93F, 0xFA40, 0xFA48, 0xFA50, 0xFA57, 0xFA5F, 0xFB60, 0xFB68, 0xFB70, 0xFB77, 0xFB7F, 0xFC80, 0xFC88, 0xFC90, 0xFC97, 0xFC9F, 0xFDA0, 0xFDA8, 0xFDB0, 0xFDB7, 0xFDBF, 0xFEC0, 0xFEC8, 0xFED0, 0xFED7, 0xFEDF, 0xFFE0, 0xFFE8, 0xFFF0, 0xFFF7, 0xFFFF};

static uint8_t _get_color_red(canvas_color color) {
    return rmap((color >> 11) & 0x1F, 0, 31, 0, 255);
}

static uint8_t _get_color_green(canvas_color color) {
    return rmap((color >> 5) & 0x3F, 0, 63, 0, 255);
}

static uint8_t _get_color_blue(canvas_color color) {
    return rmap(color & 0x1F, 0, 31, 0, 255);
}

static uint16_t _get_color_value(canvas_color color) {
    return _get_color_red(color) + _get_color_green(color) + _get_color_blue(color);
}

static uint16_t _get_color_gray(canvas_color color) {
    return _get_color_value(color) / 3;
}

static void _get_rgb_components(uint16_t color, uint8_t* r, uint8_t* g, uint8_t* b) {
    *r = _get_color_red(color);
    *g = _get_color_green(color);
    *b = _get_color_blue(color);
}

static void _get_rgb_components888(uint32_t color, uint8_t* r, uint8_t* g, uint8_t* b) {
    *r = (color >> 16) & 0xFF;
    *g = (color >> 8) & 0xFF;
    *b = color & 0xFF;
}

static int _find_closest_color(uint16_t* colors, size_t size, uint16_t target_color) {
    uint8_t target_r, target_g, target_b;
    _get_rgb_components(target_color, &target_r, &target_g, &target_b);

    int closest_index = -1;
    uint32_t min_distance = UINT32_MAX;

    for (size_t i = 0; i < size; i++) {
        uint8_t r, g, b;
        _get_rgb_components(colors[i], &r, &g, &b);

        uint32_t distance = (target_r - r) * (target_r - r) +
                            (target_g - g) * (target_g - g) +
                            (target_b - b) * (target_b - b);

        if (distance < min_distance) {
            min_distance = distance;
            closest_index = i;
        }
    }

    return closest_index;
}

static int _find_closest_color888(uint16_t* colors, size_t size, uint32_t target_color) {
    uint8_t target_r, target_g, target_b;
    _get_rgb_components888(target_color, &target_r, &target_g, &target_b);

    int closest_index = -1;
    uint32_t min_distance = UINT32_MAX;

    for (size_t i = 0; i < size; i++) {
        uint8_t r, g, b;
        _get_rgb_components(colors[i], &r, &g, &b);

        uint32_t distance = (target_r - r) * (target_r - r) +
                            (target_g - g) * (target_g - g) +
                            (target_b - b) * (target_b - b);

        if (distance < min_distance) {
            min_distance = distance;
            closest_index = i;
        }
    }

	uint8_t r, g, b;
	_get_rgb_components(colors[closest_index], &r, &g, &b);
    return closest_index;
}

static uint8_t _getColorIndexForCanvas(canvas_t* canvas, uint32_t color) {
	if (canvas->depth == 1) {
		return color > 0 ? _whiteColorIndex : _blackColorIndex;
	}
	return _find_closest_color888(canvas->palette, canvas->depth == 4 ? 16 : 256, color);
}

// ----------------------------------------------

canvas_t* canvas_create(canvas_pos sizeX, canvas_pos sizeY, uint8_t depth) {
	canvas_t* canvas = malloc(sizeof(canvas_t));
	switch (depth) {
		case 4:
			memcpy(canvas->palette, _defaultTier2Palette, 16 * BYTES_PER_COLOR);
			break;

		case 1:
		case 8:
			memcpy(canvas->palette, _defaultPalette, 256 * BYTES_PER_COLOR);
			break;
	}

	canvas->size = sizeX * sizeY;
	canvas->sizeX = sizeX;
	canvas->sizeY = sizeY;

	canvas->depth = depth;
	canvas_setBackground(canvas, 0x000000, false);
	canvas_setForeground(canvas, 0xffffff, false);

	canvas->chars = malloc(canvas->size);
	canvas->foregrounds = malloc(canvas->size);
	canvas->backgrounds = malloc(canvas->size);

	memset(canvas->chars, ' ', canvas->size);
	memset(canvas->foregrounds, canvas->foreground, canvas->size);
	memset(canvas->backgrounds, canvas->background, canvas->size);
	
	return canvas;
}

void canvas_setResolution(canvas_t* canvas, canvas_pos sizeX, canvas_pos sizeY) {
	char* old_chars = canvas->chars;
	uint8_t* old_foregrounds = canvas->foregrounds;
	uint8_t* old_backgrounds = canvas->backgrounds;
	canvas_pos old_sizeX = canvas->sizeX;
	canvas_pos old_sizeY = canvas->sizeY;

	canvas->size = sizeX * sizeY;
	canvas->sizeX = sizeX;
	canvas->sizeY = sizeY;

	canvas->chars = malloc(canvas->size);
	canvas->foregrounds = malloc(canvas->size);
	canvas->backgrounds = malloc(canvas->size);

	memset(canvas->chars, ' ', canvas->size);
	memset(canvas->foregrounds, canvas->foreground, canvas->size);
	memset(canvas->backgrounds, canvas->background, canvas->size);

	for (size_t ix = 0; ix < sizeX; ix++) {
		for (size_t iy = 0; iy < sizeY; iy++) {
			size_t index = ix + (iy * sizeX);
			canvas->chars[index] = old_chars[index];
			canvas->foregrounds[index] = old_foregrounds[index];
			canvas->backgrounds[index] = old_backgrounds[index];
		}
	}

	free(old_chars);
	free(old_foregrounds);
	free(old_backgrounds);
}

void canvas_setDepth(canvas_t* canvas, uint8_t depth) {
	canvas->depth = depth;
	switch (depth) {
		case 1:
			for (size_t i = 0; i < canvas->size; i++) {
				canvas->foregrounds[i] = canvas->palette[canvas->foregrounds[i]] > 0 ? _whiteColorIndex : _blackColorIndex;
				canvas->backgrounds[i] = canvas->palette[canvas->backgrounds[i]] > 0 ? _whiteColorIndex : _blackColorIndex;
			}
			break;
		
		case 4:
			static canvas_color oldPalette[256];
			memcpy(oldPalette, canvas->palette, 256 * BYTES_PER_COLOR);
			memcpy(canvas->palette, _defaultTier2Palette, 16 * BYTES_PER_COLOR);
			for (size_t i = 0; i < canvas->size; i++) {
				canvas->foregrounds[i] = _find_closest_color(canvas->palette, 16, oldPalette[canvas->foregrounds[i]]);
				canvas->backgrounds[i] = _find_closest_color(canvas->palette, 16, oldPalette[canvas->backgrounds[i]]);
			}
			break;

		case 8:
			memcpy(canvas->palette, _defaultPalette, 16 * BYTES_PER_COLOR);
			break;
	}
}

void canvas_setBackground(canvas_t* canvas, uint32_t color, bool isPal) {
	canvas->background = isPal ? color : _getColorIndexForCanvas(canvas, color);
}

void canvas_setForeground(canvas_t* canvas, uint32_t color, bool isPal) {
	canvas->foreground = isPal ? color : _getColorIndexForCanvas(canvas, color);
}

void canvas_fill(canvas_t* canvas, canvas_pos x, canvas_pos y, canvas_pos sizeX, canvas_pos sizeY, char chr) {
	x--;
	y--;
	for (size_t ix = x; ix < x + sizeX; ix++) {
		for (size_t iy = y; iy < y + sizeY; iy++) {
			size_t index = ix + (iy * canvas->sizeX);
			canvas->chars[index] = chr;
			canvas->foregrounds[index] = canvas->foreground;
			canvas->backgrounds[index] = canvas->background;
		}
	}
	printf("%i %i\n", canvas->background, canvas->foreground);
}

void canvas_set(canvas_t* canvas, canvas_pos x, canvas_pos y, char chr) {
	x--;
	y--;
	size_t index = x + (y * canvas->sizeX);
	canvas->chars[index] = chr;
	canvas->foregrounds[index] = canvas->foreground;
	canvas->backgrounds[index] = canvas->background;
}

void canvas_free(canvas_t* canvas) {
	free(canvas->chars);
	free(canvas->foregrounds);
	free(canvas->backgrounds);
	free(canvas);
}