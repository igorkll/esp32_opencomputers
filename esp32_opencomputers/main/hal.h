#pragma once
#include <stdint.h>
#include <esp_log.h>
#include <driver/ledc.h>
#include <driver/gpio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include "canvas.h"
#include "config.h"

// ---------------------------------------------- display

typedef struct {
    canvas_pos startX;
    canvas_pos startY;
	canvas_pos charSizeX;
    canvas_pos charSizeY;
} hal_display_sendInfo;

void hal_display_backlight(bool state);
hal_display_sendInfo hal_display_sendBuffer(canvas_t* canvas);

// ---------------------------------------------- touchscreen

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
bool hal_filesystem_copy(const char* from, const char* to);
bool hal_filesystem_formatStorage();
void hal_filesystem_loadStorageDataFromROM();

// ---------------------------------------------- sound

#define SOUND_CHANNELS ((8 * 3) + 2)

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

// ---------------------------------------------- leds

#define HAL_LEDC_TIMER LEDC_TIMER_0
#define HAL_LEDC_MODE LEDC_LOW_SPEED_MODE

typedef struct {
	bool empty;
    ledc_channel_t channel;
	TaskHandle_t task;
	uint8_t enableLight;
	uint8_t disableLight;
} hal_led;

hal_led* hal_led_new(gpio_num_t pin, bool invert, uint8_t enableLight, uint8_t disableLight);
hal_led* hal_led_stub();
void hal_led_blink(hal_led* led);
void hal_led_set(hal_led* led, uint8_t value);
void hal_led_setBool(hal_led* led, bool state);
void hal_led_enable(hal_led* led);
void hal_led_disable(hal_led* led);
void hal_led_free(hal_led* led);

// ---------------------------------------------- buttons

typedef struct {
	gpio_num_t pin;
	bool invert;
	bool needhold;
	
	double rawChangedTime;
	bool rawstate;

	double changedTime;
	bool state;
	bool oldState;

	bool triggered;
	bool holdTriggered;
	bool unlocked;
} hal_button;

#define PULL_NONE 0
#define PULL_UP   1
#define PULL_DOWN 2

hal_button* hal_button_new(gpio_num_t pin, bool invert, bool needhold, uint8_t pull);
hal_button* hal_button_stub();
void hal_button_update(hal_button* button);
bool hal_button_hasTriggered(hal_button* button);
void hal_button_free(hal_button* button);

// ---------------------------------------------- powerlock

#define PL_MODE_LOW  0
#define PL_MODE_HIGH 1
#define PL_MODE_VOID 2

void hal_powerlock_lock();
void hal_powerlock_unlock();

// ---------------------------------------------- other

void hal_task(void(*func)(void* arg), void* arg);
void hal_delay(uint32_t milliseconds);
void hal_yield();
double hal_uptimeM();
double hal_uptime();
double hal_frandom();
uint32_t hal_random();
size_t hal_freeMemory();
size_t hal_totalMemory();