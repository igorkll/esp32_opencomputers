#pragma once
#include <stdint.h>
#include "canvas.h"

// ---------------------------------------------- display

#define DISPLAY_FREQ 60000000
#define DISPLAY_HOST SPI2_HOST
#define DISPLAY_MISO 12
#define DISPLAY_MOSI 13
#define DISPLAY_CLK  14
#define DISPLAY_DC   21
#define DISPLAY_CS   22
#define DISPLAY_RST  33
#define DISPLAY_BL   4

#define DISPLAY_WIDTH  480
#define DISPLAY_HEIGHT 320

#define DISPLAY_SWAP_ENDIAN true
#define DISPLAY_SWAP_RGB    true
#define DISPLAY_INVERT      true
#define DISPLAY_FLIP_X      true
#define DISPLAY_FLIP_Y      false
#define DISPLAY_FLIP_XY     false
#define DISPLAY_ROTATION    1
#define DISPLAY_OFFSET_X    0
#define DISPLAY_OFFSET_Y    0

void hal_display_sendBuffer(canvas_t* canvas, bool pixelPerfect);

// ---------------------------------------------- touchscreen

// ---------------------------------------------- filesystem

// ---------------------------------------------- sound

#define SOUND_CHANNELS ((8 * 3) + 1)
#define SOUND_FREQ 40000
#define SOUND_OUTPUT 0

typedef struct {
    bool enabled;
	uint64_t disableTimer;
	uint16_t freq;
	uint8_t volume;
} hal_sound_channel;

void hal_sound_updateChannel(uint8_t index, hal_sound_channel settings);

// ---------------------------------------------- other

void hal_init();
void hal_delay(uint32_t milliseconds);