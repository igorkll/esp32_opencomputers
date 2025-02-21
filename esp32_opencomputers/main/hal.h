#include <driver/spi_master.h>

// ---------------------------------------------- hardware settings

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

// ----------------------------------------------

#include <stdint.h>

typedef uint16_t hal_pos;

void hal_init();
void hal_delay(uint32_t milliseconds);

// ---------------------------------------------- framebuffer

void hal_createBuffer(uint8_t tier);
void hal_sendBuffer();