#include <driver/spi_master.h>
#include <esp_heap_caps.h>
#include <esp_vfs.h>
#include <esp_vfs_fat.h>
#include <driver/gptimer.h>
#include <esp_timer.h>
#include <esp_random.h>
#include <esp_lcd_io_spi.h>
#include <esp_lcd_panel_io.h>
#include <esp_spiffs.h>
#include <string.h>
#include <math.h>
#include <map.h>
#include "hal.h"
#include "main.h"
#include "font.h"
#include "functions.h"

const char* HAL_LOG_TAG = "opencomputers";

// ---------------------------------------------- display

#define BYTES_PER_COLOR 2

esp_lcd_panel_io_handle_t display;

typedef struct {
	uint8_t cmd;
	uint8_t data[16];
	uint8_t datalen;
	int16_t delay; //-1 = end of commands
} _command;

typedef struct {
	_command list[8];
	size_t count;
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

// X+ Y+
//#define _ROTATION_0 0
//#define _ROTATION_1 (1<<5) | (1<<6) | (1<<2)
//#define _ROTATION_2 (1<<6) | (1<<7) | (1<<2) | (1<<4)
//#define _ROTATION_3 (1<<5) | (1<<7) | (1<<4)
// Y+ X+
#define _ROTATION_0 (1<<5)
#define _ROTATION_1 (1<<6) | (1<<2)
#define _ROTATION_2 (1<<5) | (1<<6) | (1<<7) | (1<<2) | (1<<4)
#define _ROTATION_3 (1<<7) | (1<<4)
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
	if (DISPLAY_SWAP_XY) {
		regvalue ^= (1 << 5);
	}

	return (_command) {0x36, {regvalue}, 1, -1};
}

static _commandList _select(uint16_t x, uint16_t y, uint16_t x2, uint16_t y2) {
	/*
	return (_commandList) {
		.list = {
			{0x2A, {x >> 8, x & 0xff, x2 >> 8, x2 & 0xff}, 4},
			{0x2B, {y >> 8, y & 0xff, y2 >> 8, y2 & 0xff}, 4},
			{0x2C, {0}, 0, -1}
		}
	};
	*/
	return (_commandList) {
		.count = 3,
		.list = {
			{0x2A, {y >> 8, y & 0xff, y2 >> 8, y2 & 0xff}, 4},
			{0x2B, {x >> 8, x & 0xff, x2 >> 8, x2 & 0xff}, 4},
			{0x2C, {0}, 0, -1}
		}
	};
}

static _commandList _selectFrame(uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
	return _select(
		DISPLAY_OFFSET_X + x,
		DISPLAY_OFFSET_Y + y,
		(DISPLAY_OFFSET_X + x + width) - 1,
		(DISPLAY_OFFSET_Y + y + height) - 1
	);
}

static void _sendCommand(const uint8_t cmd) {
	ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(display, cmd, NULL, 0));
}

static void _sendData(const uint8_t* data, size_t size) {
	ESP_ERROR_CHECK(esp_lcd_panel_io_tx_color(display, -1, data, size));
}

static bool _doCommand(const _command command) {
	ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(display, command.cmd, command.data, command.datalen));

	if (command.delay > 0) {
		vTaskDelay(command.delay / portTICK_PERIOD_MS);
	} else if (command.delay < 0) {
		return true;
	}
	return false;
}

static void _doCommands(const _command* list, size_t count) {
	for (size_t i = 0; i < count; i++) {
		_doCommand(list[i]);
	}
}

static void _doCommandList(const _commandList* list) {
	_doCommands(list->list, list->count);
}

static void _sendSelect(uint16_t x, uint16_t y, uint16_t width, uint16_t height) {
	_commandList list = _selectFrame(x, y, width, height);
	_doCommandList(&list);
}

static void _sendSelectAll() {
	_sendSelect(0, 0, DISPLAY_WIDTH, DISPLAY_HEIGHT);
}

static uint8_t clear_buffer[1024] = {0};
static void _clear() {
	_sendSelectAll();
	for (size_t i = 0; i < (DISPLAY_WIDTH * DISPLAY_HEIGHT * BYTES_PER_COLOR) / sizeof(clear_buffer); i++) {
		_sendData(clear_buffer, sizeof(clear_buffer));
	}
}

// ----------------------------------------------

bool _on_color_trans_done(esp_lcd_panel_io_handle_t panel_io, esp_lcd_panel_io_event_data_t* edata, void* user) {
	return true;
}

static void _initDisplay() {
	// ---- init spi bus
	spi_bus_config_t buscfg={
		#ifdef DISPLAY_MISO
			.miso_io_num=DISPLAY_MISO,
		#else
			.miso_io_num=-1,
		#endif
		.mosi_io_num=DISPLAY_MOSI,
		.sclk_io_num=DISPLAY_CLK,
		.quadwp_io_num=-1,
		.quadhd_io_num=-1,
		.max_transfer_sz = DISPLAY_WIDTH * DISPLAY_HEIGHT * BYTES_PER_COLOR
	};
	ESP_ERROR_CHECK(spi_bus_initialize(DISPLAY_HOST, &buscfg, SPI_DMA_CH_AUTO));

	// ---- init spi device
	esp_lcd_panel_io_spi_config_t io_config = {
		.dc_gpio_num = DISPLAY_DC,
		#ifdef DISPLAY_CS
			.cs_gpio_num = DISPLAY_CS,
		#else
			.cs_gpio_num = -1,
		#endif
		.pclk_hz = DISPLAY_FREQ,
		.lcd_cmd_bits = 8,
		.lcd_param_bits = 8,
		.spi_mode = 0,
		.trans_queue_depth = 128,
	};
	ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi(DISPLAY_HOST, &io_config, &display));

	esp_lcd_panel_io_callbacks_t callback_config = {
		.on_color_trans_done = _on_color_trans_done,
	};
	ESP_ERROR_CHECK(esp_lcd_panel_io_register_event_callbacks(display, &callback_config, NULL));

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

	_doCommands(display_init, sizeof(display_init) / sizeof(*display_init));
	#ifdef DISPLAY_INVERT
		_doCommand(display_invert);
	#endif
	_doCommand(_rotate(DISPLAY_ROTATION));
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
static hashmap* cache_rasterized = NULL;
static bool pixelPerfect = RENDER_PIXEL_PERFECT;

typedef struct {
	uchar chr;
	canvas_color fg;
	canvas_color bg;
} CharCacheData;

static int _hashmap_free(const void *key, size_t ksize, uintptr_t value, void *usr) {
	void* chardata = value;
	free(key);
	free(chardata);
	return 0;
}

hal_display_sendInfo hal_display_sendBuffer(canvas_t* canvas) {
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
			return hal_display_sendBuffer(canvas);
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
		_clear();
	}

	old_sizeX = canvas->sizeX;
	old_sizeY = canvas->sizeY;
	old_pixelPerfect = pixelPerfect;

	if (!cache_rasterized || canvas->sizeX != canvas->sizeX_current || canvas->sizeY != canvas->sizeY_current) {
		if (cache_rasterized) {
			//hashmap_iterate(cache_rasterized, _hashmap_free, NULL);
			hashmap_free(cache_rasterized);
		}
		cache_rasterized = hashmap_create();
		canvas_freeCache(canvas);
		canvas->sizeX_current = canvas->sizeX;
		canvas->sizeY_current = canvas->sizeY;
	}

	bool force = !canvas->palette_current;
	if (force) {
		canvas->palette_current = malloc(256 * BYTES_PER_COLOR);
		canvas->chars_current = malloc(canvas->size * sizeof(uchar));
		canvas->backgrounds_current = malloc(canvas->size);
		canvas->foregrounds_current = malloc(canvas->size);
	}

	for (size_t iy = 0; iy < canvas->sizeY; iy++) {
		bool needSelect = true;
		for (size_t ix = 0; ix < canvas->sizeX; ix++) {
			size_t index = ix + (iy * canvas->sizeX);
			uint8_t background = canvas->backgrounds[index];
			uint8_t foreground = canvas->foregrounds[index];
			uchar chr = canvas->chars[index];
			bool isSpace = chr == UCHAR_SPACE;
			bool foregroundVisible = !isSpace;
			bool backgroundVisible = true;
			if (force ||
				(backgroundVisible && canvas->palette[background] != canvas->palette_current[background]) ||
				(foregroundVisible && canvas->palette[foreground] != canvas->palette_current[foreground]) ||
				canvas->chars[index] != canvas->chars_current[index] ||
				(backgroundVisible && canvas->backgrounds[index] != canvas->backgrounds_current[index]) ||
				(foregroundVisible && canvas->foregrounds[index] != canvas->foregrounds_current[index])) {
				
				canvas->chars_current[index] = canvas->chars[index];
				canvas->backgrounds_current[index] = canvas->backgrounds[index];
				canvas->foregrounds_current[index] = canvas->foregrounds[index];

				if (needSelect) {
					int selectX = offsetX + (ix * charSizeX);
					_sendSelect(selectX, offsetY + (iy * charSizeY), DISPLAY_WIDTH - selectX, charSizeY);
					needSelect = false;
				}

				#ifdef DISPLAY_SWAP_ENDIAN
					uint8_t* _color = (uint8_t*)(&canvas->palette[background]);
					canvas_color backgroundColor = (_color[0] << 8) + _color[1];

					_color = (uint8_t*)(&canvas->palette[foreground]);
					canvas_color foregroundColor = (_color[0] << 8) + _color[1];
				#else
					canvas_color backgroundColor = canvas->palette[background];
					canvas_color foregroundColor = canvas->palette[foreground];
				#endif

				size_t bytesPerChar = charSizeX * charSizeY * BYTES_PER_COLOR;
				uint8_t* charBuffer;

				CharCacheData finding = {
					.chr = chr,
					.fg = foregroundVisible ? foregroundColor : 0,
					.bg = backgroundVisible ? backgroundColor : 0
				};

				if (hashmap_get(cache_rasterized, &finding, sizeof(CharCacheData), &charBuffer) == 0) {
					charBuffer = malloc(bytesPerChar);
					
					if (isSpace) {
						for (size_t icx = 0; icx < charSizeX; icx++) {
							for (size_t icy = 0; icy < charSizeY; icy++) {
								memcpy(charBuffer + ((icy + (icx * charSizeY)) * BYTES_PER_COLOR), &backgroundColor, BYTES_PER_COLOR);
							}
						}
					} else {
						uint8_t rawCharBuffer[FONT_MAXCHAR];

						int charOffset = font_findOffset(chr);
						if (charOffset >= 0) {
							font_readData(rawCharBuffer, charOffset);
						} else {
							memset(rawCharBuffer, 0, FONT_MAXCHAR);
						}

						if (pixelPerfect) {
							size_t pixelScale = charSizeX / 8;
							for (size_t icx = 0; icx < 8; icx++) {
								for (size_t icy = 0; icy < 16; icy++) {
									canvas_color color = font_readPixel(rawCharBuffer, icx, icy) ? foregroundColor : backgroundColor;
									for (size_t ibx = 0; ibx < pixelScale; ibx++) {
										for (size_t iby = 0; iby < pixelScale; iby++) {
											memcpy(charBuffer + ((iby + (icy * pixelScale) + (((icx * pixelScale) + ibx) * charSizeY)) * BYTES_PER_COLOR), &color, BYTES_PER_COLOR);
										}
									}
								}
							}
						} else {
							for (size_t icx = 0; icx < charSizeX; icx++) {
								for (size_t icy = 0; icy < charSizeY; icy++) {
									canvas_color color = font_readPixel(rawCharBuffer, rmap(icx, 0, charSizeX - 1, 0, 7), rmap(icy, 0, charSizeY - 1, 0, 15)) ? foregroundColor : backgroundColor;
									memcpy(charBuffer + ((icy + (icx * charSizeY)) * BYTES_PER_COLOR), &color, BYTES_PER_COLOR);
								}
							}
						}
					}

					CharCacheData* cacheKey = malloc(sizeof(CharCacheData));
					memcpy(cacheKey, &finding, sizeof(CharCacheData));
					hashmap_set(cache_rasterized, cacheKey, sizeof(CharCacheData), charBuffer);
				}

				_sendData(charBuffer, bytesPerChar);
			} else {
				needSelect = true;
			}
		}
	}

	memcpy(canvas->palette_current, canvas->palette, 256 * BYTES_PER_COLOR);

	return (hal_display_sendInfo) {
		.startX = offsetX,
		.startY = offsetY,
		.charSizeX = charSizeX,
		.charSizeY = charSizeY
	};
}

// ---------------------------------------------- touchscreen

#ifdef TOUCHSCREEN_FT6336U
#include <driver/i2c.h>

static uint8_t i2c_readReg(uint8_t addr) {
    uint8_t val = 0;
    i2c_master_write_read_device(TOUCHSCREEN_HOST, TOUCHSCREEN_ADDR, &addr, 1, &val, 1, 100 / portTICK_PERIOD_MS);
    return val;
}

static int i2c_readDualReg(uint8_t addr) {
    uint8_t read_buf[2];
    read_buf[0] = i2c_readReg(addr);
    read_buf[1] = i2c_readReg(addr + 1);
    return ((read_buf[0] & 0x0f) << 8) | read_buf[1];
}

static void _initTouchscreen() {
	i2c_config_t config = {
		.mode = I2C_MODE_MASTER,
		.sda_io_num = TOUCHSCREEN_SDA,
		.scl_io_num = TOUCHSCREEN_SCL,
		.sda_pullup_en = GPIO_PULLUP_ENABLE,
		.scl_pullup_en = GPIO_PULLUP_ENABLE,
		.master.clk_speed = 400000,
	};

	ESP_ERROR_CHECK(i2c_param_config(TOUCHSCREEN_HOST, &config));
	ESP_ERROR_CHECK(i2c_driver_install(TOUCHSCREEN_HOST, config.mode, 0, 0, 0));

	#ifdef TOUCHSCREEN_RST
		gpio_config_t io_conf = {};
		io_conf.pin_bit_mask |= 1ULL << TOUCHSCREEN_RST;
		io_conf.mode = GPIO_MODE_OUTPUT;
		gpio_config(&io_conf);

		gpio_set_level(TOUCHSCREEN_RST, false);
		vTaskDelay(100 / portTICK_PERIOD_MS);
		gpio_set_level(TOUCHSCREEN_RST, true);
		vTaskDelay(100 / portTICK_PERIOD_MS);
	#endif
}

uint8_t hal_touchscreen_touchCount() {
	return i2c_readReg(0x02) & 0x0F;
}

hal_touchscreen_point hal_touchscreen_getPoint(uint8_t index) {
	float x = 0;
    float y = 0;
    float z = 0;

	switch (index) {
		case 0:
			x = i2c_readDualReg(0x03);
			y = i2c_readDualReg(0x05);
			z = 1;
			break;

		case 1:
			x = i2c_readDualReg(0x09);
			y = i2c_readDualReg(0x0B);
			z = 1;
			break;
	}

    if (TOUCHSCREEN_SWAP_XY) {
        int t = x;
        x = y;
        y = t;
    }

    x *= TOUCHSCREEN_MUL_X;
    y *= TOUCHSCREEN_MUL_Y;
    x += TOUCHSCREEN_OFFSET_X;
    y += TOUCHSCREEN_OFFSET_Y;

    if (x < 0) {
        x = 0;
    } else if (x >= TOUCHSCREEN_WIDTH) {
        x = TOUCHSCREEN_WIDTH - 1;
    }

    if (y < 0) {
        y = 0;
    } else if (y >= TOUCHSCREEN_HEIGHT) {
        y = TOUCHSCREEN_HEIGHT - 1;
    }

    bool flipFlip = TOUCHSCREEN_ROTATION == 2 || TOUCHSCREEN_ROTATION == 3;
    if (TOUCHSCREEN_FLIP_X ^ flipFlip) x = TOUCHSCREEN_WIDTH - 1 - x;
    if (TOUCHSCREEN_FLIP_Y ^ flipFlip) y = TOUCHSCREEN_HEIGHT - 1 - y;

    switch (TOUCHSCREEN_ROTATION) {
        case 1:
        case 3:
            int t = x;
            x = y;
            y = TOUCHSCREEN_WIDTH - t;
            break;
    }

    return (hal_touchscreen_point) {
        .x = x + 0.5,
        .y = y + 0.5,
        .z = z
    };
}
#else
static void _initTouchscreen() {
}

uint8_t hal_touchscreen_touchCount() {
	return 0;
}

hal_touchscreen_point hal_touchscreen_getPoint(uint8_t index) {
	return (hal_touchscreen_point) {.x = 0, .y = 0, .z = 0};
}
#endif

// ---------------------------------------------- filesystem

static void _initFilesystem() {
	{
		static wl_handle_t s_wl_handle = WL_INVALID_HANDLE;
		esp_vfs_fat_mount_config_t fs_config = {
			.max_files = 8,
			.format_if_mount_failed = true,
			.allocation_unit_size = CONFIG_WL_SECTOR_SIZE
		};

		ESP_ERROR_CHECK(esp_vfs_fat_spiflash_mount_rw_wl("/storage", "storage", &fs_config, &s_wl_handle));
	}

	{
		esp_vfs_spiffs_conf_t fs_config = {
			.base_path = "/rom",
			.partition_label = "rom",
			.max_files = 2,
			.format_if_mount_failed = false
		};

		ESP_ERROR_CHECK(esp_vfs_spiffs_register(&fs_config));
	}

	hal_filesystem_loadStorageDataFromROM();
}

bool hal_filesystem_exists(const char* path) {
	struct stat state = {0};
	return stat(path, &state) == 0;
}

bool hal_filesystem_isDirectory(const char* path) {
	struct stat state = {0};
    if(stat(path, &state) == 0) {
        if (state.st_mode & S_IFDIR) {
            return true;
        } else {
            return false;
        }
    }
    return false;
}

bool hal_filesystem_isFile(const char* path) {
	struct stat state = {0};
    if(stat(path, &state) == 0) {
        if (state.st_mode & S_IFMT) {
            return true;
        } else {
            return false;
        }
    }
    return false;
}

size_t hal_filesystem_size(const char* path) {
	if (hal_filesystem_isDirectory(path)) {
		long total_size = 0;
		struct dirent *entry;
		struct stat statbuf;
		DIR *dp = opendir(path);

		if (dp == NULL) {
			return 0;
		}

		while ((entry = readdir(dp)) != NULL) {
			if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
				continue;
			}

			char full_path[PATH_MAX+1];
			snprintf(full_path, PATH_MAX, "%s/%s", path, entry->d_name);

			if (stat(full_path, &statbuf) == -1) {
				perror("stat");
				continue;
			}

			if (S_ISDIR(statbuf.st_mode)) {
				long dir_size = hal_filesystem_size(full_path);
				if (dir_size != -1) {
					total_size += dir_size;
				}
			} else {
				total_size += statbuf.st_size;
			}
		}

		closedir(dp);
		return total_size;
	} else {
		struct stat state;
		if (stat(path, &state) == 0) return state.st_size;
		return 0;
	}
}

void hal_filesystem_list(const char *path, void (*callback)(void* arg, const char *filename), void* arg) {
    struct dirent *entry;
    DIR *dp = opendir(path);

    if (dp == NULL) {
        return;
    }

    while ((entry = readdir(dp)) != NULL) {
        if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
            if (entry->d_type == DT_DIR) {
                char dir_name[PATH_MAX+1];
                snprintf(dir_name, PATH_MAX, "%s/", entry->d_name);
                callback(arg, dir_name);
            } else {
                callback(arg, entry->d_name);
            }
        }
    }

    closedir(dp);
}

bool hal_filesystem_mkdir(const char* path) {
	if (hal_filesystem_isDirectory(path)) return false;
    mkdir(path, S_IRWXU);
    return hal_filesystem_isDirectory(path);
}

size_t hal_filesystem_count(const char* path, bool files, bool dirs) {
	DIR *dir = opendir(path);
    if (dir == NULL) return 0;
    uint16_t count = 0;
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_DIR && strcmp(entry->d_name, ".") == 0) continue;
        if (entry->d_type == DT_DIR && strcmp(entry->d_name, "..") == 0) continue;
        if ((files && entry->d_type == DT_REG) || (dirs && entry->d_type == DT_DIR)) count++;
    }
    closedir(dir);
    return count;
}

size_t hal_filesystem_lastModified(const char* path) {
	struct stat file_stat;
    if (stat(path, &file_stat) == -1) {
        return 0;
    }
    return file_stat.st_mtime;
}

bool hal_filesystem_copy(const char* from, const char* to) {
    FILE* source;
	FILE* dest;
    uint8_t buffer[1024];
    size_t bytesRead;

    source = fopen(from, "rb");
    if (source == NULL) {
        return false;
    }

    dest = fopen(to, "wb");
    if (dest == NULL) {
		fclose(source);
		return false;
    }

    while ((bytesRead = fread(buffer, 1, sizeof(buffer), source)) > 0) {
        fwrite(buffer, 1, bytesRead, dest);
    }

    fclose(source);
    fclose(dest);

	return true;
}

bool hal_filesystem_formatStorage() {
	return esp_vfs_fat_spiflash_format_rw_wl("/storage", "storage") != ESP_OK;
}

static void _loadFile(char* from, char* to) {
	if (!hal_filesystem_isFile(to)) {
		hal_filesystem_copy(from, to);
	}
}

void hal_filesystem_loadStorageDataFromROM() {
	hal_filesystem_mkdir("/storage/system");
	_loadFile("/rom/eeprom.dat", "/storage/eeprom.dat");
	_loadFile("/rom/eeprom.lbl", "/storage/eeprom.lbl");
	_loadFile("/rom/eeprom.lua", "/storage/eeprom.lua");
}

// ---------------------------------------------- sound

#ifdef SOUND_DAC
#include <driver/dac_oneshot.h>

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
	uint32_t value = 0;
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
			value += (localValue * channel->volume * SOUND_MASTER_VOLUME) / 255 / 255;
		}
	}
	dac_oneshot_output_voltage(sound_output, value > 255 ? 255 : value);
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
	sound_channels[index] = settings;
}
#else
static void _initSound() {
}

void hal_sound_updateChannel(uint8_t index, hal_sound_channel settings) {
}
#endif

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

void hal_yield() {
	vTaskDelay(1);
}

double hal_uptimeM() {
	return esp_timer_get_time() / 1000.0;
}

double hal_uptime() {
	return hal_uptimeM() / 1000.0;
}

uint32_t hal_random() {
	return esp_random();
}

double hal_frandom() {
	uint32_t random_value = esp_random();
	return random_value / (double)UINT32_MAX;
}

size_t hal_freeMemory() {
	return heap_caps_get_free_size(MALLOC_CAP_8BIT);
}

static size_t totalMemory;
size_t hal_totalMemory() {
	return totalMemory;
}

// ---------------------------------------------- leds

static ledc_channel_t channel = 0;

hal_led* hal_led_new(gpio_num_t pin, bool invert, uint8_t enableLight, uint8_t disableLight) {
	hal_led* led = malloc(sizeof(hal_led));
	
	channel = channel + 1;
	if (channel >= LEDC_CHANNEL_MAX) {
		channel = LEDC_CHANNEL_MAX - 1;
	}

	ledc_channel_config_t ledc_channel = {
        .speed_mode = HAL_LEDC_MODE,
        .channel = channel,
        .gpio_num = pin,
        .duty = 0,
        .hpoint = 0,
        .flags.output_invert = invert,
        .timer_sel = HAL_LEDC_TIMER
    };
    ledc_channel_config(&ledc_channel);

	led->empty = false;
	led->channel = channel;
	led->task = NULL;
	led->enableLight = enableLight;
	led->disableLight = disableLight;
	return led;
}

hal_led* hal_led_stub() {
	hal_led* led = malloc(sizeof(hal_led));
	led->empty = true;
	return led;
}

static void _led_blink_task(void* arg) {
	hal_led* led = arg;
	while (true) {
		ledc_set_duty(HAL_LEDC_MODE, led->channel, led->enableLight);
		ledc_update_duty(HAL_LEDC_MODE, led->channel);
		hal_delay(1000);

		ledc_set_duty(HAL_LEDC_MODE, led->channel, led->disableLight);
		ledc_update_duty(HAL_LEDC_MODE, led->channel);
		hal_delay(1000);
	}
}

void hal_led_blink(hal_led* led) {
	if (led->empty) return;
	if (led->task) {
		vTaskDelete(led->task);
		led->task = NULL;
	}
	xTaskCreate(_led_blink_task, NULL, 1024, led, tskIDLE_PRIORITY, &led->task);
}

void hal_led_set(hal_led* led, uint8_t value) {
	if (led->empty) return;
	if (led->task) {
		vTaskDelete(led->task);
		led->task = NULL;
	}
	ledc_set_duty(HAL_LEDC_MODE, led->channel, value);
	ledc_update_duty(HAL_LEDC_MODE, led->channel);
}

void hal_led_setBool(hal_led* led, bool state) {
	hal_led_set(led, state ? led->enableLight : led->disableLight);
}

void hal_led_enable(hal_led* led) {
	hal_led_setBool(led, true);
}

void hal_led_disable(hal_led* led) {
	hal_led_setBool(led, false);
}

void hal_led_free(hal_led* led) {
	hal_led_disable(led);
	free(led);
}

static void _ledInit() {
	ledc_timer_config_t ledc_timer = {
        .speed_mode = HAL_LEDC_MODE,
        .timer_num = HAL_LEDC_TIMER,
        .duty_resolution = LEDC_TIMER_8_BIT,
        .freq_hz = 1000,
        .clk_cfg = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);
}

// ---------------------------------------------- buttons

hal_button* hal_button_new(gpio_num_t pin, bool invert, bool needhold, uint8_t pull) {
	hal_button* button = malloc(sizeof(hal_button));
	button->pin = pin;
	button->invert = invert;
	button->needhold = needhold;
	button->changedTime = hal_uptimeM();
	button->rawChangedTime = button->changedTime;
	button->unlocked = false;
	button->triggered = false;
	button->holdTriggered = false;
	button->rawstate = false;
	button->state = false;
	button->oldState = false;

	gpio_config_t io_conf = {};
	io_conf.pin_bit_mask |= 1ULL << pin;
	io_conf.mode = GPIO_MODE_INPUT;
	io_conf.pull_down_en = pull == PULL_DOWN ? GPIO_PULLDOWN_ENABLE : GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = pull == PULL_UP ? GPIO_PULLUP_ENABLE : GPIO_PULLUP_DISABLE;
	gpio_config(&io_conf);

	return button;
}

hal_button* hal_button_stub() {
	hal_button* button = malloc(sizeof(hal_button));
	button->pin = -1;
	return button;
}

void hal_button_update(hal_button* button) {
	if (button->pin == -1) return;

	bool rawstate = gpio_get_level(button->pin);
	if (button->invert) rawstate = !rawstate;

	double uptime = hal_uptimeM();
	if (rawstate != button->rawstate) {
		button->rawChangedTime = uptime;
		button->rawstate = rawstate;
	}

	if (uptime - button->rawChangedTime > BUTTON_DEBOUNCE) {
		if (!rawstate) {
			button->unlocked = true;
		}
		button->rawChangedTime = uptime;
		if (button->unlocked) {
			button->state = button->rawstate;
		}
	}

	if (button->state != button->oldState) {
		button->changedTime = uptime;
		button->oldState = button->state;
		button->holdTriggered = false;
		if (!button->needhold && button->state) {
			button->triggered = true;
		}
	}
	
	if (!button->holdTriggered && button->needhold && button->state && uptime - button->changedTime > BUTTON_HOLDTIME) {
		button->triggered = true;
		button->holdTriggered = true;
	}
}

bool hal_button_hasTriggered(hal_button* button) {
	if (button->pin == -1) return false;
	hal_button_update(button);
	
	bool triggered = button->triggered;
	button->triggered = false;
	return triggered;
}

void hal_button_free(hal_button* button) {
	free(button);
}

// ---------------------------------------------- powerlock

void _powerlock_setState(uint8_t value) {
	#ifdef POWER_POWERLOCK
		static bool hasOutput = false;
		gpio_config_t io_conf = {};
		io_conf.pin_bit_mask |= 1ULL << POWER_POWERLOCK;
		switch (value) {
			case PL_MODE_LOW:
				if (!hasOutput) {
					hasOutput = true;
					io_conf.mode = GPIO_MODE_OUTPUT;
					gpio_config(&io_conf);
				}
				gpio_set_level(POWER_POWERLOCK, false);
				break;

			case PL_MODE_HIGH:
				if (!hasOutput) {
					hasOutput = true;
					io_conf.mode = GPIO_MODE_OUTPUT;
					gpio_config(&io_conf);
				}
				gpio_set_level(POWER_POWERLOCK, true);
				break;
			
			default:
				if (hasOutput) {
					hasOutput = false;
					io_conf.mode = GPIO_MODE_DISABLE;
					gpio_config(&io_conf);
				}
				break;
		}
		
	#endif
} 

void hal_powerlock_lock() {
	#ifdef POWER_POWERLOCK_LOCKED_MODE
		_powerlock_setState(POWER_POWERLOCK_LOCKED_MODE);
	#endif
}

void hal_powerlock_unlock() {
	#ifdef POWER_POWERLOCK_UNLOCKED_MODE
		_powerlock_setState(POWER_POWERLOCK_UNLOCKED_MODE);
	#endif
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
	_initTouchscreen();
	_initFilesystem();
	_initSound();
	_ledInit();
	font_init();
	_main();
}