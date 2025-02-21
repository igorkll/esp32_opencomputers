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

#define DISPLAY_SWAP_RGB true
#define DISPLAY_INVERT   true
#define DISPLAY_FLIP_X   true
#define DISPLAY_FLIP_Y   false
#define DISPLAY_FLIP_XY  false
#define DISPLAY_ROTATION 1
#define DISPLAY_OFFSET_X 0
#define DISPLAY_OFFSET_Y 0

void hal_initDisplay();
void hal_sendBuffer(canvas_t* canvas);

// ---------------------------------------------- touchscreen

// ---------------------------------------------- other

void hal_delay(uint32_t milliseconds);