#include "hal.h"
#include <esp_heap_caps.h>
#include <driver/gpio.h>
#include <string.h>

// ---------------------------------------------- canvas

static hal_color _defaultPalette[] = {0x000000, 0x000040, 0x000080, 0x0000BF, 0x0000FF, 0x002400, 0x002440, 0x002480, 0x0024BF, 0x0024FF, 0x004900, 0x004940, 0x004980, 0x0049BF, 0x0049FF, 0x006D00, 0x006D40, 0x006D80, 0x006DBF, 0x006DFF, 0x009200, 0x009240, 0x009280, 0x0092BF, 0x0092FF, 0x00B600, 0x00B640, 0x00B680, 0x00B6BF, 0x00B6FF, 0x00DB00, 0x00DB40, 0x00DB80, 0x00DBBF, 0x00DBFF, 0x00FF00, 0x00FF40, 0x00FF80, 0x00FFBF, 0x00FFFF, 0x0F0F0F, 0x1E1E1E, 0x2D2D2D, 0x330000, 0x330040, 0x330080, 0x3300BF, 0x3300FF, 0x332400, 0x332440, 0x332480, 0x3324BF, 0x3324FF, 0x334900, 0x334940, 0x334980, 0x3349BF, 0x3349FF, 0x336D00, 0x336D40, 0x336D80, 0x336DBF, 0x336DFF, 0x339200, 0x339240, 0x339280, 0x3392BF, 0x3392FF, 0x33B600, 0x33B640, 0x33B680, 0x33B6BF, 0x33B6FF, 0x33DB00, 0x33DB40, 0x33DB80, 0x33DBBF, 0x33DBFF, 0x33FF00, 0x33FF40, 0x33FF80, 0x33FFBF, 0x33FFFF, 0x3C3C3C, 0x4B4B4B, 0x5A5A5A, 0x660000, 0x660040, 0x660080, 0x6600BF, 0x6600FF, 0x662400, 0x662440, 0x662480, 0x6624BF, 0x6624FF, 0x664900, 0x664940, 0x664980, 0x6649BF, 0x6649FF, 0x666D00, 0x666D40, 0x666D80, 0x666DBF, 0x666DFF, 0x669200, 0x669240, 0x669280, 0x6692BF, 0x6692FF, 0x66B600, 0x66B640, 0x66B680, 0x66B6BF, 0x66B6FF, 0x66DB00, 0x66DB40, 0x66DB80, 0x66DBBF, 0x66DBFF, 0x66FF00, 0x66FF40, 0x66FF80, 0x66FFBF, 0x66FFFF, 0x696969, 0x787878, 0x878787, 0x969696, 0x990000, 0x990040, 0x990080, 0x9900BF, 0x9900FF, 0x992400, 0x992440, 0x992480, 0x9924BF, 0x9924FF, 0x994900, 0x994940, 0x994980, 0x9949BF, 0x9949FF, 0x996D00, 0x996D40, 0x996D80, 0x996DBF, 0x996DFF, 0x999200, 0x999240, 0x999280, 0x9992BF, 0x9992FF, 0x99B600, 0x99B640, 0x99B680, 0x99B6BF, 0x99B6FF, 0x99DB00, 0x99DB40, 0x99DB80, 0x99DBBF, 0x99DBFF, 0x99FF00, 0x99FF40, 0x99FF80, 0x99FFBF, 0x99FFFF, 0xA5A5A5, 0xB4B4B4, 0xC3C3C3, 0xCC0000, 0xCC0040, 0xCC0080, 0xCC00BF, 0xCC00FF, 0xCC2400, 0xCC2440, 0xCC2480, 0xCC24BF, 0xCC24FF, 0xCC4900, 0xCC4940, 0xCC4980, 0xCC49BF, 0xCC49FF, 0xCC6D00, 0xCC6D40, 0xCC6D80, 0xCC6DBF, 0xCC6DFF, 0xCC9200, 0xCC9240, 0xCC9280, 0xCC92BF, 0xCC92FF, 0xCCB600, 0xCCB640, 0xCCB680, 0xCCB6BF, 0xCCB6FF, 0xCCDB00, 0xCCDB40, 0xCCDB80, 0xCCDBBF, 0xCCDBFF, 0xCCFF00, 0xCCFF40, 0xCCFF80, 0xCCFFBF, 0xCCFFFF, 0xD2D2D2, 0xE1E1E1, 0xF0F0F0, 0xFF0000, 0xFF0040, 0xFF0080, 0xFF00BF, 0xFF00FF, 0xFF2400, 0xFF2440, 0xFF2480, 0xFF24BF, 0xFF24FF, 0xFF4900, 0xFF4940, 0xFF4980, 0xFF49BF, 0xFF49FF, 0xFF6D00, 0xFF6D40, 0xFF6D80, 0xFF6DBF, 0xFF6DFF, 0xFF9200, 0xFF9240, 0xFF9280, 0xFF92BF, 0xFF92FF, 0xFFB600, 0xFFB640, 0xFFB680, 0xFFB6BF, 0xFFB6FF, 0xFFDB00, 0xFFDB40, 0xFFDB80, 0xFFDBBF, 0xFFDBFF, 0xFFFF00, 0xFFFF40, 0xFFFF80, 0xFFFFBF, 0xFFFFFF};

hal_canvas* hal_createBuffer(hal_pos sizeX, hal_pos sizeY, uint8_t depth) {
	hal_canvas* canvas = malloc(sizeof(hal_canvas));
	memcpy(canvas->palette, _defaultPalette, sizeof(_defaultPalette));

	canvas->size = sizeX * sizeY;
	canvas->sizeX = sizeX;
	canvas->sizeY = sizeY;
	canvas->depth = depth;

	canvas->chars = malloc(canvas->size * sizeof(*canvas->chars));
	canvas->foregrounds = malloc(canvas->size * sizeof(*canvas->foregrounds));
	canvas->backgrounds = malloc(canvas->size * sizeof(*canvas->backgrounds));
	return canvas;
}

void hal_bufferSetDepth(hal_canvas* canvas, uint8_t depth) {
	for (size_t i = 0; i < canvas->size; i++) {
		if (canvas->foregrounds[i] )
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