#include <driver/spi_master.h>
#include <stdint.h>

// ---------------------------------------------- hardware display settings

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

// ---------------------------------------------- canvas

typedef uint16_t hal_pos;
typedef uint16_t hal_color;
typedef struct {
	hal_color palette[256];

	hal_pos size;
	hal_pos sizeX;
	hal_pos sizeY;

	uint8_t depth;
	uint8_t foreground;
	uint8_t background;

    char* chars;
	uint8_t* foregrounds;
	uint8_t* backgrounds;
} hal_canvas;

hal_canvas* hal_createBuffer(hal_pos sizeX, hal_pos sizeY, uint8_t depth);
void hal_bufferResize(hal_canvas* canvas, hal_pos sizeX, hal_pos sizeY);
void hal_bufferSetDepth(hal_canvas* canvas, uint8_t depth);
void hal_bufferFree(hal_canvas* canvas);

// ---------------------------------------------- display

void hal_initDisplay();
void hal_sendBuffer(hal_canvas* canvas);

// ---------------------------------------------- touchscreen

// ---------------------------------------------- other

void hal_delay(uint32_t milliseconds);