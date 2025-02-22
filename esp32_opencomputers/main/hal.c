#include <driver/spi_master.h>
#include <esp_heap_caps.h>
#include <driver/gpio.h>
#include <esp_vfs.h>
#include <esp_vfs_fat.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <string.h>
#include "hal.h"
#include "main.h"
#include "font.h"
#include "functions.h"

// ---------------------------------------------- display

#define MAXSEND 1024 * 8
#define BYTES_PER_COLOR 2

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
    size_t bytesCount = size * BYTES_PER_COLOR;
	size_t part = min(MAXSEND, bytesCount);
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

void hal_sendBuffer(canvas_t* canvas) {
	_clear();

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

	if (charSizeX < 1) charSizeX = 1;
	if (charSizeY < 2) charSizeY = 2;

	canvas_pos offsetX = (DISPLAY_WIDTH / 2) - ((charSizeX * canvas->sizeX) / 2);
	canvas_pos offsetY = (DISPLAY_HEIGHT / 2) - ((charSizeY * canvas->sizeY) / 2);

	for (size_t ix = 0; ix < canvas->sizeX; ix++) {
		for (size_t iy = 0; iy < canvas->sizeY; iy++) {
			size_t index = ix + (iy * canvas->sizeX);
			uint8_t background = canvas->backgrounds[index];
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
				uint8_t foreground = canvas->foregrounds[index];

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

				for (size_t icx = 0; icx < charSizeX; icx++) {
					for (size_t icy = 0; icy < charSizeY; icy++) {
						canvas_color color = font_readPixel(rawCharBuffer, rmap(icx, 0, charSizeX - 1, 0, 7), rmap(icy, 0, charSizeY - 1, 0, 15)) ? foregroundColor : backgroundColor;
						memcpy(charBuffer + ((icx + (icy * charSizeX)) * BYTES_PER_COLOR), &color, BYTES_PER_COLOR);
					}
				}
				_sendData(charBuffer, bytesPerChar);
			}
		}
	}
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

// ---------------------------------------------- other

void hal_init() {
	_initDisplay();
	_initFilesystem();
	font_init();
}

void hal_delay(uint32_t milliseconds) {
	size_t ticks = milliseconds / portTICK_PERIOD_MS;
    if (ticks <= 0) ticks = 1;
    vTaskDelay(ticks);
}

// ----------------------------------------------

void app_main() {
	_main();
}