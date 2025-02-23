#include <driver/spi_master.h>
#include <esp_heap_caps.h>
#include <driver/gpio.h>
#include <esp_vfs.h>
#include <esp_vfs_fat.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <driver/gptimer.h>
#include <esp_timer.h>
#include <driver/dac_oneshot.h>
#include <string.h>
#include <math.h>
#include "hal.h"
#include "main.h"
#include "font.h"
#include "functions.h"

const char* HAL_LOG_TAG = "opencomputers";

// ---------------------------------------------- display

#define BYTES_PER_COLOR 2
#define MAXSEND (DISPLAY_WIDTH * DISPLAY_HEIGHT * BYTES_PER_COLOR)

typedef struct {
	uint8_t cmd;
	uint8_t data[16];
	uint8_t datalen;
	int16_t delay; //-1 = end of commands
} _command;

typedef struct {
	_command list[8];
} _commandList;

static const _command display_enable = {0x29, {0}, 0, 0};
static const _command display_invert = {0x21, {0}, 0, 0};

static const _command display_init[] = {
	/* rgb 565 - big endian */
	{0x3A, {0x05}, 1, 0},
	/* Porch Setting */
	{0xB2, {0x0c, 0x0c, 0x00, 0x33, 0x33}, 5, 0},
	/* Gate Control, Vgh=13.65V, Vgl=-10.43V */
	{0xB7, {0x45}, 1, 0},
	/* VCOM Setting, VCOM=1.175V */
	{0xBB, {0x2B}, 1, 0},
	/* LCM Control, XOR: BGR, MX, MH */
	{0xC0, {0x2C}, 1, 0},
	/* VDV and VRH Command Enable, enable=1 */
	{0xC2, {0x01, 0xff}, 2, 0},
	/* VRH Set, Vap=4.4+... */
	{0xC3, {0x11}, 1, 0},
	/* VDV Set, VDV=0 */
	{0xC4, {0x20}, 1, 0},
	/* Power Control 1, AVDD=6.8V, AVCL=-4.8V, VDDS=2.3V */
	{0xD0, {0xA4, 0xA1}, 1, 0},
	/* Positive Voltage Gamma Control */
	{0xE0, {0xD0, 0x00, 0x05, 0x0E, 0x15, 0x0D, 0x37, 0x43, 0x47, 0x09, 0x15, 0x12, 0x16, 0x19}, 14, 0},
	/* Negative Voltage Gamma Control */
	{0xE1, {0xD0, 0x00, 0x05, 0x0D, 0x0C, 0x06, 0x2D, 0x44, 0x40, 0x0E, 0x1C, 0x18, 0x16, 0x19}, 14, 0},
	/* Sleep Out */
	{0x11, {0}, 0, 100},
	/* Idle mode off */
	{0x38, {0}, 0, -1},
};

#define _ROTATION_0 0
#define _ROTATION_1 (1<<5) | (1<<6) | (1<<2)
#define _ROTATION_2 (1<<6) | (1<<7) | (1<<2) | (1<<4)
#define _ROTATION_3 (1<<5) | (1<<7) | (1<<4)
static _command _rotate(uint8_t rotation) {
	uint8_t regvalue = 0;
	switch (rotation) {
		default:
			regvalue = _ROTATION_0;
			break;

		case 1:
			regvalue = _ROTATION_1;
			break;

		case 2:
			regvalue = _ROTATION_2;
			break;

		case 3:
			regvalue = _ROTATION_3;
			break;
	}

	if (DISPLAY_SWAP_RGB) regvalue ^= (1 << 3);
	if (DISPLAY_FLIP_X) {
		regvalue ^= (1 << 6);
		regvalue ^= (1 << 2);
	}
	if (DISPLAY_FLIP_Y) {
		regvalue ^= (1 << 7);
		regvalue ^= (1 << 4);
	}
	if (DISPLAY_FLIP_XY) {
		regvalue ^= (1 << 5);
	}

	return (_command) {0x36, {regvalue}, 1, -1};
}

static _commandList _select(uint16_t x, uint16_t y, uint16_t x2, uint16_t y2) {
	return (_commandList) {
		.list = {
			{0x2A, {x >> 8, x & 0xff, x2 >> 8, x2 & 0xff}, 4},
			{0x2B, {y >> 8, y & 0xff, y2 >> 8, y2 & 0xff}, 4},
			{0x2C, {0}, 0, -1}
		}
	};
}

spi_device_handle_t display;

static void _sendCommand(const uint8_t cmd) {
	gpio_set_level(DISPLAY_DC, false);

	spi_transaction_t transaction = {
		.length = 8,
		.tx_buffer = &cmd
	};

	ESP_ERROR_CHECK(spi_device_polling_transmit(display, &transaction));
}

static void _sendData(const uint8_t* data, size_t size) {
	gpio_set_level(DISPLAY_DC, true);

	spi_transaction_t transaction = {
		.length = size * 8,
		.tx_buffer = data
	};
	
	ESP_ERROR_CHECK(spi_device_polling_transmit(display, &transaction));
}

static bool _doCommand(const _command command) {
	_sendCommand(command.cmd);
	if (command.datalen > 0) {
		_sendData(command.data, command.datalen);
	}

	if (command.delay > 0) {
		vTaskDelay(command.delay / portTICK_PERIOD_MS);
	} else if (command.delay < 0) {
		return true;
	}
	return false;
}

static void _doCommands(const _command* list) {
	uint16_t cmd = 0;
	while (!_doCommand(list[cmd++]));
}

static void _doCommandList(const _commandList list) {
	uint16_t cmd = 0;
	while (!_doCommand(list.list[cmd++]));
}

static void _sendSelect(uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
	_doCommandList(
		_select(
			DISPLAY_OFFSET_X + x,
			DISPLAY_OFFSET_Y + y,
			(DISPLAY_OFFSET_X + x + width) - 1,
			(DISPLAY_OFFSET_Y + y + height) - 1
		)
	);
}

static void _sendSelectAll() {
	_sendSelect(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);
}

static void _spam(size_t size, uint16_t color) {
	multi_heap_info_t info;
	heap_caps_get_info(&info, MALLOC_CAP_INTERNAL);

	size_t bytesCount = size * BYTES_PER_COLOR;
	size_t part = min(info.largest_free_block / 2, bytesCount);
	size_t offset = 0;
	uint8_t* floodPart = malloc(part);
	if (floodPart == NULL) return;
	for (size_t i = 0; i < part; i += BYTES_PER_COLOR) {
		memcpy(floodPart + i, &color, BYTES_PER_COLOR);
	}
	while (true) {
		_sendData(floodPart, min(bytesCount - offset, part));
		offset += part;
		if (offset >= bytesCount) {
			break;
		}
	}
	free(floodPart);
}

static void _clear() {
	_spam(DISPLAY_WIDTH * DISPLAY_HEIGHT, 0);
}

static void _initDisplay() {
	// ---- init spi bus
	spi_bus_config_t buscfg={
		.miso_io_num=DISPLAY_MISO,
		.mosi_io_num=DISPLAY_MOSI,
		.sclk_io_num=DISPLAY_CLK,
		.quadwp_io_num=-1,
		.quadhd_io_num=-1,
		.max_transfer_sz = MAXSEND
	};
	ESP_ERROR_CHECK(spi_bus_initialize(DISPLAY_HOST, &buscfg, SPI_DMA_CH_AUTO));

	// ---- init spi device
	spi_device_interface_config_t devcfg = {
		.clock_speed_hz = DISPLAY_FREQ,
		.mode = 0,
		.spics_io_num = DISPLAY_CS,
		.input_delay_ns = 0,
		.queue_size = 1,
		.flags = SPI_DEVICE_NO_DUMMY
	};

	ESP_ERROR_CHECK(spi_bus_add_device(DISPLAY_HOST, &devcfg, &display));

	// ---- init display

	gpio_config_t io_conf = {};
	io_conf.pin_bit_mask |= 1ULL << DISPLAY_DC;
	#ifdef DISPLAY_RST
		io_conf.pin_bit_mask |= 1ULL << DISPLAY_RST;
	#endif
	io_conf.mode = GPIO_MODE_OUTPUT;
	gpio_config(&io_conf);

	#ifdef DISPLAY_RST
		gpio_set_level(DISPLAY_RST, false);
		hal_delay(100);
		gpio_set_level(DISPLAY_RST, true);
		hal_delay(100);
	#endif

	_doCommands(display_init);
	#ifdef DISPLAY_INVERT
		_doCommand(display_invert);
	#endif
	_doCommand(_rotate(DISPLAY_ROTATION));
	_sendSelectAll();
	_clear();
	_doCommand(display_enable);
	_sendSelectAll();
}

void hal_display_backlight(bool state) {
	#ifdef DISPLAY_BL
		gpio_set_level(DISPLAY_BL, DISPLAY_INVERT_BL ? !state : state);
	#endif
}

static bool firstFlush = false;
static canvas_pos old_sizeX;
static canvas_pos old_sizeY;
static bool old_pixelPerfect;
void hal_display_sendBuffer(canvas_t* canvas, bool pixelPerfect) {
	canvas_pos charSizeX = DISPLAY_WIDTH / canvas->sizeX;
	canvas_pos charSizeY = DISPLAY_HEIGHT / canvas->sizeY;
	if (charSizeY % 2 != 0) charSizeY--;
	
	canvas_pos squareCharSizeX = charSizeY / 2;
	canvas_pos squareCharSizeY = charSizeX * 2;
	if (charSizeX > squareCharSizeX) {
		charSizeX = squareCharSizeX;
	} else if (charSizeY > squareCharSizeY) {
		charSizeY = squareCharSizeY;
	}

	if (pixelPerfect) {
		charSizeX = (charSizeX / 8) * 8;
		charSizeY = (charSizeY / 16) * 16;
		if (charSizeX < 8 || charSizeY < 16) {
			charSizeX = 8;
			charSizeY = 16;
		}
		if (charSizeX * canvas->sizeX > DISPLAY_WIDTH || charSizeY * canvas->sizeY > DISPLAY_HEIGHT) {
			hal_display_sendBuffer(canvas, false);
			return;
		}
	} else {
		if (charSizeX < 1) charSizeX = 1;
		if (charSizeY < 2) charSizeY = 2;
	}

	canvas_pos offsetX = (DISPLAY_WIDTH / 2) - ((charSizeX * canvas->sizeX) / 2);
	canvas_pos offsetY = (DISPLAY_HEIGHT / 2) - ((charSizeY * canvas->sizeY) / 2);

	if (!firstFlush) {
		firstFlush = true;
	} else if (canvas->sizeX != old_sizeX || canvas->sizeY != old_sizeY || pixelPerfect != old_pixelPerfect) {
		_sendSelectAll();
		_clear();
	}

	old_sizeX = canvas->sizeX;
	old_sizeY = canvas->sizeY;
	old_pixelPerfect = pixelPerfect;

	if (canvas->sizeX != canvas->sizeX_current || canvas->sizeY != canvas->sizeY_current) {
		canvas_freeCache(canvas);
		canvas->sizeX_current = canvas->sizeX;
		canvas->sizeY_current = canvas->sizeY;
	}

	bool force = !canvas->palette_current;
	if (force) {
		canvas->palette_current = malloc(256 * BYTES_PER_COLOR);
		canvas->chars_current = malloc(canvas->size);
		canvas->backgrounds_current = malloc(canvas->size);
		canvas->foregrounds_current = malloc(canvas->size);
	}

	for (size_t ix = 0; ix < canvas->sizeX; ix++) {
		for (size_t iy = 0; iy < canvas->sizeY; iy++) {
			size_t index = ix + (iy * canvas->sizeX);
			uint8_t background = canvas->backgrounds[index];
			uint8_t foreground = canvas->foregrounds[index];
			if (force ||
				canvas->palette[background] != canvas->palette_current[background] ||
				canvas->palette[foreground] != canvas->palette_current[foreground] ||
				canvas->chars[index] != canvas->chars_current[index] ||
				canvas->backgrounds[index] != canvas->backgrounds_current[index] ||
				canvas->foregrounds[index] != canvas->foregrounds_current[index]) {
				
				canvas->chars_current[index] = canvas->chars[index];
				canvas->backgrounds_current[index] = canvas->backgrounds[index];
				canvas->foregrounds_current[index] = canvas->foregrounds[index];

				_sendSelect(offsetX + (ix * charSizeX), offsetY + (iy * charSizeY), charSizeX, charSizeY);

				#ifdef DISPLAY_SWAP_ENDIAN
					uint8_t* _color = (uint8_t*)(&canvas->palette[background]);
					canvas_color backgroundColor = (_color[0] << 8) + _color[1];
				#else
					canvas_color backgroundColor = canvas->palette[background];
				#endif

				if (canvas->chars[index] == ' ') {
					_spam(charSizeX * charSizeY, backgroundColor);
				} else {
					size_t bytesPerChar = charSizeX * charSizeY * BYTES_PER_COLOR;
					uint8_t charBuffer[bytesPerChar];
					uint8_t rawCharBuffer[FONT_MAXCHAR];
					

					int charOffset = font_findOffset(&canvas->chars[index], 1);
					bool isWide;
					if (charOffset >= 0) {
						font_readData(rawCharBuffer, charOffset);
					} else {
						memset(rawCharBuffer, 0, FONT_MAXCHAR);
					}

					#ifdef DISPLAY_SWAP_ENDIAN
						uint8_t* _color = (uint8_t*)(&canvas->palette[foreground]);
						canvas_color foregroundColor = (_color[0] << 8) + _color[1];
					#else
						canvas_color foregroundColor = canvas->palette[foreground];
					#endif

					if (pixelPerfect) {
						size_t pixelScale = charSizeX / 8;
						for (size_t icx = 0; icx < 8; icx++) {
							for (size_t icy = 0; icy < 16; icy++) {
								canvas_color color = font_readPixel(rawCharBuffer, icx, icy) ? foregroundColor : backgroundColor;
								for (size_t ibx = 0; ibx < pixelScale; ibx++) {
									for (size_t iby = 0; iby < pixelScale; iby++) {
										memcpy(charBuffer + ((ibx + (icx * pixelScale) + (((icy * pixelScale) + iby) * charSizeX)) * BYTES_PER_COLOR), &color, BYTES_PER_COLOR);
									}
								}
							}
						}
					} else {
						for (size_t icx = 0; icx < charSizeX; icx++) {
							for (size_t icy = 0; icy < charSizeY; icy++) {
								canvas_color color = font_readPixel(rawCharBuffer, rmap(icx, 0, charSizeX - 1, 0, 7), rmap(icy, 0, charSizeY - 1, 0, 15)) ? foregroundColor : backgroundColor;
								memcpy(charBuffer + ((icx + (icy * charSizeX)) * BYTES_PER_COLOR), &color, BYTES_PER_COLOR);
							}
						}
					}
					
					_sendData(charBuffer, bytesPerChar);
				}
			}
		}
	}

	memcpy(canvas->palette_current, canvas->palette, 256 * BYTES_PER_COLOR);
}

// ---------------------------------------------- touchscreen

// ---------------------------------------------- filesystem

static void _initFilesystem() {
	static wl_handle_t s_wl_handle = WL_INVALID_HANDLE;
	esp_vfs_fat_mount_config_t storage_mount_config = {
		.max_files = 4,
		.format_if_mount_failed = false,
		.allocation_unit_size = CONFIG_WL_SECTOR_SIZE
	};

	ESP_ERROR_CHECK(esp_vfs_fat_spiflash_mount_rw_wl("/storage", "storage", &storage_mount_config, &s_wl_handle));
}

// ---------------------------------------------- sound

static hal_sound_channel sound_channels[SOUND_CHANNELS];
static gptimer_handle_t sound_timer;
static dac_oneshot_handle_t sound_output;
static uint64_t sound_tick = 0;

#define SOUND_ARRAY_DIV 4
#define SOUND_ARRAY_SIZE (SOUND_FREQ / SOUND_ARRAY_DIV)
static uint8_t sound_sin[SOUND_ARRAY_SIZE];
static uint8_t sound_noise[SOUND_ARRAY_SIZE];

#define SOUND_FREQ_M (SOUND_FREQ - 1)
#define SOUND_FREQ_D (SOUND_FREQ / 2)
#define SOUND_FREQ_MD (SOUND_FREQ_M / 2)

static bool IRAM_ATTR _timer_ISR(gptimer_handle_t timer, const gptimer_alarm_event_data_t* edata, void* user_ctx) {
	uint16_t value = 0;
	for (size_t i = 0; i < SOUND_CHANNELS; i++) {
		hal_sound_channel* channel = &sound_channels[i];
		if (channel->enabled) {
			if (channel->disableTimer > 0) {
				channel->disableTimer--;
				if (channel->disableTimer == 0) {
					channel->enabled = false;
				}
			}

			int freqValue = sound_tick * channel->freq;
			int secondTick = freqValue % SOUND_FREQ;
			int tickChange = freqValue / SOUND_FREQ;
			uint8_t localValue = 0;
			switch (channel->wave) {
				case hal_sound_square:
					localValue = secondTick >= (SOUND_FREQ / 2) ? 255 : 0;
					break;

				case hal_sound_saw:
					localValue += secondTick / (SOUND_FREQ_M / 255);
					break;

				case hal_sound_triangle:
					localValue += (SOUND_FREQ_MD - abs(secondTick - SOUND_FREQ_MD)) / (SOUND_FREQ_D / 255);
					break;

				case hal_sound_sin:
					localValue += sound_sin[secondTick / SOUND_ARRAY_DIV];
					break;

				case hal_sound_noise:
					localValue += sound_noise[tickChange % SOUND_ARRAY_SIZE];
					break;
			}
			value += (localValue * channel->volume) / 255;
		}
	}
	uint8_t output = value;
	if (value > 255) output = 255;
	dac_oneshot_output_voltage(sound_output, (output * SOUND_MASTER_VOLUME) / 255);
	sound_tick++;
	return false;
}

static void _initSound() {
	memset(&sound_channels, 0, SOUND_CHANNELS * sizeof(hal_sound_channel));

	for (size_t i = 0; i < SOUND_ARRAY_SIZE; i++) {
		sound_sin[i] = nRound(((sin((i / (SOUND_ARRAY_SIZE - 1.0)) * (M_PI * 2.0)) + 1.0) / 2.0) * 255.0);
		sound_noise[i] = rand() % 256;
	}

	gptimer_alarm_config_t alarm_config = {
		.alarm_count = 1,
		.flags = {
			.auto_reload_on_alarm = true
		}
	};

	gptimer_config_t timer_config = {
		.clk_src = GPTIMER_CLK_SRC_DEFAULT,
		.direction = GPTIMER_COUNT_UP,
		.resolution_hz = SOUND_FREQ
	};
  
	gptimer_event_callbacks_t callback_config = {
		.on_alarm = _timer_ISR,
	};

	ESP_ERROR_CHECK(gptimer_new_timer(&timer_config, &sound_timer));
	ESP_ERROR_CHECK(gptimer_set_alarm_action(sound_timer, &alarm_config));
	ESP_ERROR_CHECK(gptimer_register_event_callbacks(sound_timer, &callback_config, NULL));
	ESP_ERROR_CHECK(gptimer_enable(sound_timer));
	gptimer_start(sound_timer);

	dac_oneshot_config_t conf = {
		.chan_id = SOUND_OUTPUT
	};
	dac_oneshot_new_channel(&conf, &sound_output);
}

void hal_sound_updateChannel(uint8_t index, hal_sound_channel settings) {
	gptimer_stop(sound_timer);
	sound_channels[index] = settings;
	gptimer_start(sound_timer);
}

// ---------------------------------------------- other

typedef struct {
	void(*func)(void* arg);
	void* arg;
} USERTask;

void _task_callback(void* _task) {
	USERTask* task = _task;
	task->func(task->arg);
	free(task);
	vTaskDelete(NULL);
}

void hal_task(void(*func)(void* arg), void* arg) {
	USERTask* task = malloc(sizeof(USERTask));
	task->func = func;
	task->arg = arg;
	xTaskCreate(_task_callback, "USER_TASK", 4096, task, tskIDLE_PRIORITY, NULL);
}

void hal_delay(uint32_t milliseconds) {
	size_t ticks = milliseconds / portTICK_PERIOD_MS;
	if (ticks <= 0) ticks = 1;
	vTaskDelay(ticks);
}

float hal_uptime() {
	return esp_timer_get_time() / 1000.0 / 1000.0;
}

size_t hal_freeMemory() {
	return heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

static size_t totalMemory;
size_t hal_totalMemory() {
	return totalMemory;
}

// ----------------------------------------------

void app_main() {
	totalMemory = heap_caps_get_total_size(MALLOC_CAP_8BIT);
	#ifdef DISPLAY_BL
		gpio_config_t io_conf = {};
		io_conf.pin_bit_mask |= 1ULL << DISPLAY_BL;
		io_conf.mode = GPIO_MODE_OUTPUT;
		gpio_config(&io_conf);
	#endif
	hal_display_backlight(false);
	_initDisplay();
	_initFilesystem();
	_initSound();
	font_init();
	_main();
}