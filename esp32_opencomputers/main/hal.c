#include "hal.h"
#include <esp_heap_caps.h>
#include <driver/gpio.h>
#include <string.h>

// ---------------------------------------------- canvas

static uint8_t _blackColorIndex = 16;
static uint8_t _whiteColorIndex = 255;

static hal_color _defaultTier2Palette[] = {0xFFFF, 0xFE66, 0xCB39, 0x64DF, 0xFFE6, 0x3666, 0xFB33, 0x3186, 0xCE79, 0x3333, 0x9999, 0x3193, 0x6180, 0x3320, 0xF986, 0x0000};
static hal_color _defaultPalette[] = {0x0861, 0x18E3, 0x2965, 0x39E7, 0x4A49, 0x5ACB, 0x6B4D, 0x7BCF, 0x8430, 0x94B2, 0xA534, 0xB5B6, 0xC618, 0xD69A, 0xE71C, 0xF79E, 0x0000, 0x0008, 0x0010, 0x0017, 0x001F, 0x0120, 0x0128, 0x0130, 0x0137, 0x013F, 0x0240, 0x0248, 0x0250, 0x0257, 0x025F, 0x0360, 0x0368, 0x0370, 0x0377, 0x037F, 0x0480, 0x0488, 0x0490, 0x0497, 0x049F, 0x05A0, 0x05A8, 0x05B0, 0x05B7, 0x05BF, 0x06C0, 0x06C8, 0x06D0, 0x06D7, 0x06DF, 0x07E0, 0x07E8, 0x07F0, 0x07F7, 0x07FF, 0x3000, 0x3008, 0x3010, 0x3017, 0x301F, 0x3120, 0x3128, 0x3130, 0x3137, 0x313F, 0x3240, 0x3248, 0x3250, 0x3257, 0x325F, 0x3360, 0x3368, 0x3370, 0x3377, 0x337F, 0x3480, 0x3488, 0x3490, 0x3497, 0x349F, 0x35A0, 0x35A8, 0x35B0, 0x35B7, 0x35BF, 0x36C0, 0x36C8, 0x36D0, 0x36D7, 0x36DF, 0x37E0, 0x37E8, 0x37F0, 0x37F7, 0x37FF, 0x6000, 0x6008, 0x6010, 0x6017, 0x601F, 0x6120, 0x6128, 0x6130, 0x6137, 0x613F, 0x6240, 0x6248, 0x6250, 0x6257, 0x625F, 0x6360, 0x6368, 0x6370, 0x6377, 0x637F, 0x6480, 0x6488, 0x6490, 0x6497, 0x649F, 0x65A0, 0x65A8, 0x65B0, 0x65B7, 0x65BF, 0x66C0, 0x66C8, 0x66D0, 0x66D7, 0x66DF, 0x67E0, 0x67E8, 0x67F0, 0x67F7, 0x67FF, 0x9800, 0x9808, 0x9810, 0x9817, 0x981F, 0x9920, 0x9928, 0x9930, 0x9937, 0x993F, 0x9A40, 0x9A48, 0x9A50, 0x9A57, 0x9A5F, 0x9B60, 0x9B68, 0x9B70, 0x9B77, 0x9B7F, 0x9C80, 0x9C88, 0x9C90, 0x9C97, 0x9C9F, 0x9DA0, 0x9DA8, 0x9DB0, 0x9DB7, 0x9DBF, 0x9EC0, 0x9EC8, 0x9ED0, 0x9ED7, 0x9EDF, 0x9FE0, 0x9FE8, 0x9FF0, 0x9FF7, 0x9FFF, 0xC800, 0xC808, 0xC810, 0xC817, 0xC81F, 0xC920, 0xC928, 0xC930, 0xC937, 0xC93F, 0xCA40, 0xCA48, 0xCA50, 0xCA57, 0xCA5F, 0xCB60, 0xCB68, 0xCB70, 0xCB77, 0xCB7F, 0xCC80, 0xCC88, 0xCC90, 0xCC97, 0xCC9F, 0xCDA0, 0xCDA8, 0xCDB0, 0xCDB7, 0xCDBF, 0xCEC0, 0xCEC8, 0xCED0, 0xCED7, 0xCEDF, 0xCFE0, 0xCFE8, 0xCFF0, 0xCFF7, 0xCFFF, 0xF800, 0xF808, 0xF810, 0xF817, 0xF81F, 0xF920, 0xF928, 0xF930, 0xF937, 0xF93F, 0xFA40, 0xFA48, 0xFA50, 0xFA57, 0xFA5F, 0xFB60, 0xFB68, 0xFB70, 0xFB77, 0xFB7F, 0xFC80, 0xFC88, 0xFC90, 0xFC97, 0xFC9F, 0xFDA0, 0xFDA8, 0xFDB0, 0xFDB7, 0xFDBF, 0xFEC0, 0xFEC8, 0xFED0, 0xFED7, 0xFEDF, 0xFFE0, 0xFFE8, 0xFFF0, 0xFFF7, 0xFFFF};

uint8_t _get_color_red(hal_color color) {
    return (color >> 11) & 0x1F;
}

uint8_t _get_color_green(hal_color color) {
    return (color >> 5) & 0x3F;
}

uint8_t _get_color_blue(hal_color color) {
    return color & 0x1F;
}

uint16_t _get_color_value(hal_color color) {
    return _get_color_red(color) + _get_color_green(color) + _get_color_blue(color);
}

uint16_t _get_color_gray(hal_color color) {
    return _get_color_value(color) / 3;
}

uint16_t _get_rgb_components(uint16_t color, uint8_t* r, uint8_t* g, uint8_t* b) {
    *r = (color >> 11) & 0x1F;
    *g = (color >> 5) & 0x3F;
    *b = color & 0x1F;
}

int _find_closest_color(uint16_t* colors, size_t size, uint16_t target_color) {
    uint8_t target_r, target_g, target_b;
    _get_rgb_components(target_color, &target_r, &target_g, &target_b);

    int closest_index = -1;
    uint32_t min_distance = UINT32_MAX;

    for (size_t i = 0; i < size; i++) {
        uint8_t r, g, b;
        _get_rgb_components(colors[i], &r, &g, &b);

        uint32_t distance = (target_r - r) * (target_r - r) +
                            (target_g - g) * (target_g - g) +
                            (target_b - b) * (target_b - b);

        if (distance < min_distance) {
            min_distance = distance;
            closest_index = i;
        }
    }

    return closest_index;
}


hal_canvas* hal_createBuffer(hal_pos sizeX, hal_pos sizeY, uint8_t depth) {
	hal_canvas* canvas = malloc(sizeof(hal_canvas));
	memcpy(canvas->palette, _defaultPalette, sizeof(_defaultPalette));

	canvas->size = sizeX * sizeY;
	canvas->sizeX = sizeX;
	canvas->sizeY = sizeY;

	canvas->depth = depth;
	canvas->foreground = _whiteColorIndex;
	canvas->background = _blackColorIndex;

	canvas->chars = malloc(canvas->size);
	canvas->foregrounds = malloc(canvas->size);
	canvas->backgrounds = malloc(canvas->size);

	memset(canvas->chars, ' ', sizeof(canvas->size));
	memset(canvas->foregrounds, _whiteColorIndex, sizeof(canvas->size));
	memset(canvas->backgrounds, _blackColorIndex, sizeof(canvas->size));

	return canvas;
}

void hal_bufferResize(hal_canvas* canvas, hal_pos sizeX, hal_pos sizeY) {
	char* old_chars = canvas->chars;
	uint8_t* old_foregrounds = canvas->foregrounds;
	uint8_t* old_backgrounds = canvas->backgrounds;
	hal_pos old_sizeX = canvas->sizeX;
	hal_pos old_sizeY = canvas->sizeY;

	canvas->size = sizeX * sizeY;
	canvas->sizeX = sizeX;
	canvas->sizeY = sizeY;

	canvas->chars = malloc(canvas->size);
	canvas->foregrounds = malloc(canvas->size);
	canvas->backgrounds = malloc(canvas->size);

	for () {

	}

	free(old_chars);
	free(old_foregrounds);
	free(old_backgrounds);
}

void hal_bufferSetDepth(hal_canvas* canvas, uint8_t depth) {
	canvas->depth = depth;
	switch (depth) {
		case 1:
			for (size_t i = 0; i < canvas->size; i++) {
				canvas->foregrounds[i] = _get_color_value(canvas->palette[canvas->foregrounds[i]]) > 0 ? _whiteColorIndex : _blackColorIndex;
				canvas->backgrounds[i] = _get_color_value(canvas->palette[canvas->backgrounds[i]]) > 0 ? _whiteColorIndex : _blackColorIndex;
			}
			break;
		
		case 2:
			static hal_color oldPalette[256];
			memcpy(oldPalette, canvas->palette, 256);
			memcpy(canvas->palette, _defaultTier2Palette, 16);
			for (size_t i = 0; i < canvas->size; i++) {
				canvas->foregrounds[i] = _find_closest_color(canvas->palette, 16, oldPalette[canvas->foregrounds[i]]);
				canvas->backgrounds[i] = _find_closest_color(canvas->palette, 16, oldPalette[canvas->backgrounds[i]]);
			}
			break;

		case 3:
			memcpy(canvas->palette, _defaultPalette, 16);
			break;
	}
}

void hal_bufferFree(hal_canvas* canvas) {
	free(canvas->chars);
	free(canvas->foregrounds);
	free(canvas->backgrounds);
	free(canvas);
}

// ---------------------------------------------- display

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

static _commandList _select(hal_pos x, hal_pos y, hal_pos x2, hal_pos y2) {
    return (_commandList) {
        .list = {
            {0x2A, {x >> 8, x & 0xff, x2 >> 8, x2 & 0xff}, 4},
            {0x2B, {y >> 8, y & 0xff, y2 >> 8, y2 & 0xff}, 4},
            {0x2C, {0}, 0, -1}
        }
    };
}

#define DISPLAY_MAXSEND         1024 * 8
#define DISPLAY_BYTES_PER_COLOR 2

spi_device_handle_t display;

typedef struct {
    gpio_num_t pin;
    bool state;
} spi_pretransfer_info;

static void _sendCommand(const uint8_t cmd) {
    spi_pretransfer_info pre_transfer_info = {
        .pin = DISPLAY_DC,
        .state = false
    };

    spi_transaction_t transaction = {
        .length = 8,
        .tx_buffer = &cmd,
        .user = (void*)(&pre_transfer_info)
    };

    ESP_ERROR_CHECK(spi_device_transmit(display, &transaction));
}

static void _sendData(const uint8_t* data, size_t size) {
    spi_pretransfer_info pre_transfer_info = {
        .pin = DISPLAY_DC,
        .state = true
    };

    spi_transaction_t transaction = {
        .length = size * 8,
        .tx_buffer = data,
        .user = (void*)(&pre_transfer_info)
    };
    
    ESP_ERROR_CHECK(spi_device_transmit(display, &transaction));
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

static void _sendSelect(hal_pos x, hal_pos y, hal_pos width, hal_pos height) {
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

static void _spi_pre_transfer_callback(spi_transaction_t* t) {
    spi_pretransfer_info* pretransfer_info = (spi_pretransfer_info*)t->user;
    gpio_set_level(pretransfer_info->pin, pretransfer_info->state);
}

static void _clear() {
	uint8_t package[DISPLAY_MAXSEND];
	memset(package, 0, DISPLAY_MAXSEND);

	size_t pixelsPerSend = DISPLAY_MAXSEND / DISPLAY_BYTES_PER_COLOR;
	for (size_t i = 0; i < DISPLAY_WIDTH * DISPLAY_HEIGHT; i += pixelsPerSend) {
		_sendData(package, DISPLAY_MAXSEND);
	}
}

void hal_initDisplay() {
	// ---- init spi bus
	spi_bus_config_t buscfg={
        .miso_io_num=DISPLAY_MISO,
        .mosi_io_num=DISPLAY_MOSI,
        .sclk_io_num=DISPLAY_CLK,
        .quadwp_io_num=-1,
        .quadhd_io_num=-1,
        .max_transfer_sz = DISPLAY_MAXSEND
    };
    ESP_ERROR_CHECK(spi_bus_initialize(DISPLAY_HOST, &buscfg, SPI_DMA_CH_AUTO));

	// ---- init spi device
	spi_device_interface_config_t devcfg = {
		.clock_speed_hz = DISPLAY_FREQ,
		.mode = 0,
		.spics_io_num = DISPLAY_CS,
		.input_delay_ns = 0,
		.queue_size = 2,
		.pre_cb = _spi_pre_transfer_callback,
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

void hal_sendBuffer(hal_canvas* canvas) {
	/*
	static uint8_t t;
	uint8_t package[DISPLAY_MAXSEND];
	memset(package, t++, DISPLAY_MAXSEND);

	size_t pixelsPerSend = DISPLAY_MAXSEND / DISPLAY_BYTES_PER_COLOR;
	for (size_t i = 0; i < DISPLAY_WIDTH * DISPLAY_HEIGHT; i += pixelsPerSend) {
		_sendData(package, DISPLAY_MAXSEND);
	}

	switch (currentTier) {
		case 1:
			break;
	}
	*/

	static uint8_t t;

	hal_pos charSizeX = DISPLAY_WIDTH / canvas->sizeX;
	hal_pos charSizeY = DISPLAY_HEIGHT / canvas->sizeY;
	size_t bytesPerChar = charSizeX * charSizeY * DISPLAY_BYTES_PER_COLOR;
	uint8_t charBuffer[bytesPerChar];

	for (size_t ix = 0; ix < canvas->sizeX; ix++) {
		for (size_t iy = 0; iy < canvas->sizeY; iy++) {
			_sendSelect(ix * charSizeX, iy * charSizeY, charSizeX, charSizeY);
			memset(charBuffer, t++, bytesPerChar);
			_sendData(charBuffer, bytesPerChar);
		}
	}
}

// ---------------------------------------------- touchscreen

// ---------------------------------------------- other

void hal_delay(uint32_t milliseconds) {
	size_t ticks = milliseconds / portTICK_PERIOD_MS;
    if (ticks <= 0) ticks = 1;
    vTaskDelay(ticks);
}