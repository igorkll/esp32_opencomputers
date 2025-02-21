#pragma once
#include <stdint.h>
#include <stdbool.h>

typedef uint16_t canvas_pos;

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
} canvas_t;



canvas_t* canvas_create(canvas_pos sizeX, canvas_pos sizeY, uint8_t depth);

void canvas_setResolution(canvas_t* canvas, canvas_pos sizeX, canvas_pos sizeY);
void canvas_setDepth(canvas_t* canvas, uint8_t depth);

void canvas_setBackground(canvas_t* canvas, canvas_fullColor color, bool isPal);
void canvas_setForeground(canvas_t* canvas, canvas_fullColor color, bool isPal);

void canvas_fill(canvas_t* canvas, canvas_pos x, canvas_pos y, canvas_pos sizeX, canvas_pos sizeY, char chr);
void canvas_set(canvas_t* canvas, canvas_pos x, canvas_pos y, char chr);

void canvas_free(canvas_t* canvas);