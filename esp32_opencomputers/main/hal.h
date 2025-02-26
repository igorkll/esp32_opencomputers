#pragma once
#include <stdint.h>
#include <esp_log.h>
#include "canvas.h"

// ---------------------------------------------- display

#define DISPLAY_FREQ 80000000
#define DISPLAY_HOST SPI2_HOST
#define DISPLAY_MISO 12
#define DISPLAY_MOSI 13
#define DISPLAY_CLK  14
#define DISPLAY_DC   21
#define DISPLAY_CS   22
#define DISPLAY_RST  33 //comment if you connected this pin to the microcontroller RST
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
#define DISPLAY_INVERT_BL   false

typedef struct {
    canvas_pos startX;
    canvas_pos startY;
	canvas_pos charSizeX;
    canvas_pos charSizeY;
} hal_display_sendInfo;

void hal_display_backlight(bool state);
hal_display_sendInfo hal_display_sendBuffer(canvas_t* canvas, bool pixelPerfect);

// ---------------------------------------------- touchscreen

#define TOUCHSCREEN_FT6336U
#define TOUCHSCREEN_SDA   5
#define TOUCHSCREEN_SCL   27
#define TOUCHSCREEN_HOST  I2C_NUM_0
#define TOUCHSCREEN_ADDR  0x38
#define TOUCHSCREEN_RST   23

#define TOUCHSCREEN_FLIP_XY false //swaps X and Y
#define TOUCHSCREEN_MUL_X 0 // if 0, it is counted as 1
#define TOUCHSCREEN_MUL_Y 0
#define TOUCHSCREEN_OFFSET_X 0
#define TOUCHSCREEN_OFFSET_Y 0
#define TOUCHSCREEN_WIDTH 320 //required parameters. the width and height of the touch screen in pixels
#define TOUCHSCREEN_HEIGHT 480
#define TOUCHSCREEN_FLIP_X false
#define TOUCHSCREEN_FLIP_Y false
#define TOUCHSCREEN_ROTATION 1

typedef struct {
    int x;
    int y;
    float z;
} hal_touchscreen_point;

uint8_t hal_touchscreen_touchCount();
hal_touchscreen_point hal_touchscreen_getPoint(uint8_t index);

// ---------------------------------------------- filesystem

bool hal_filesystem_exists(const char* path);
bool hal_filesystem_isDirectory(const char* path);
bool hal_filesystem_isFile(const char* path);
size_t hal_filesystem_size(const char* path);
bool hal_filesystem_mkdir(const char* path);
size_t hal_filesystem_count(const char* path, bool files, bool dirs);
size_t hal_filesystem_lastModified(const char* path);
void hal_filesystem_list(const char *path, void (*callback)(void* arg, const char *filename), void* arg);

// ---------------------------------------------- sound

#define SOUND_MASTER_VOLUME 16
#define SOUND_CHANNELS ((8 * 3) + 2)
#define SOUND_FREQ 40000
#define SOUND_OUTPUT 0

typedef enum {
    hal_sound_square,
	hal_sound_saw,
	hal_sound_triangle,
	hal_sound_sin,
	hal_sound_noise
} hal_sound_wave;

typedef struct {
    bool enabled;
	uint64_t disableTimer;
	uint16_t freq;
	uint8_t volume;
	hal_sound_wave wave;
} hal_sound_channel;

void hal_sound_updateChannel(uint8_t index, hal_sound_channel settings);

// ---------------------------------------------- logs

extern const char* HAL_LOG_TAG;

#define HAL_LOGI(...) ESP_LOGI(HAL_LOG_TAG, __VA_ARGS__)
#define HAL_LOGE(...) ESP_LOGE(HAL_LOG_TAG, __VA_ARGS__)
#define HAL_LOGW(...) ESP_LOGW(HAL_LOG_TAG, __VA_ARGS__)

// ---------------------------------------------- other

void hal_task(void(*func)(void* arg), void* arg);
void hal_delay(uint32_t milliseconds);
double hal_uptime();
uint32_t hal_random();
size_t hal_freeMemory();
size_t hal_totalMemory();