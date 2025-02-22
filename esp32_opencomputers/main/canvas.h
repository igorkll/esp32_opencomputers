#pragma once
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

typedef int16_t canvas_pos;

typedef uint8_t canvas_paletteIndex;
typedef uint16_t canvas_color;
typedef uint32_t canvas_fullColor;

typedef struct {
	canvas_color palette[256];

	canvas_pos size;
	canvas_pos sizeX;
	canvas_pos sizeY;

	uint8_t depth;
	canvas_paletteIndex foreground;
	canvas_paletteIndex background;

	bool foreground_isPal;
	bool background_isPal;

    char* chars;
	canvas_paletteIndex* foregrounds;
	canvas_paletteIndex* backgrounds;

	// ---- double buffering
	canvas_pos sizeX_current;
	canvas_pos sizeY_current;
	canvas_color* palette_current;
	char* chars_current;
	canvas_paletteIndex* foregrounds_current;
	canvas_paletteIndex* backgrounds_current;
} canvas_t;

typedef struct {
	char chr;

	canvas_fullColor foreground;
	canvas_fullColor background;

	canvas_paletteIndex foregroundIndex;
	canvas_paletteIndex backgroundIndex;
	
	bool foreground_isPal;
	bool background_isPal;
} canvas_get_result;

// ----------------------------------------------

canvas_t* canvas_create(canvas_pos sizeX, canvas_pos sizeY, uint8_t depth);

void canvas_setResolution(canvas_t* canvas, canvas_pos sizeX, canvas_pos sizeY);
void canvas_setDepth(canvas_t* canvas, uint8_t depth);

void canvas_setBackground(canvas_t* canvas, canvas_fullColor color, bool isPal);
void canvas_setForeground(canvas_t* canvas, canvas_fullColor color, bool isPal);
canvas_fullColor canvas_getBackground(canvas_t* canvas);
canvas_fullColor canvas_getForeground(canvas_t* canvas);

void canvas_fill(canvas_t* canvas, canvas_pos x, canvas_pos y, canvas_pos sizeX, canvas_pos sizeY, char chr);
void canvas_set(canvas_t* canvas, canvas_pos x, canvas_pos y, char* text, size_t len);
void canvas_copy(canvas_t* canvas, canvas_pos x, canvas_pos y, canvas_pos sizeX, canvas_pos sizeY, canvas_pos offsetX, canvas_pos offsetY);
canvas_get_result canvas_get(canvas_t* canvas, canvas_pos x, canvas_pos y);

void canvas_freeCache(canvas_t* canvas);
void canvas_free(canvas_t* canvas);