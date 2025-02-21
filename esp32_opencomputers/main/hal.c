#include "hal.h"
#include <esp_heap_caps.h>
#include <driver/gpio.h>

typedef struct {
    uint8_t cmd;
    uint8_t data[16];
    uint8_t datalen;
    int16_t delay; //-1 = end of commands
} tsgl_driver_command;

typedef struct {
    tsgl_driver_command list[8];
} tsgl_driver_commandList;

// ---------------------------------------------- display init

static const tsgl_driver_command display_init[] = {
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
    {0x38, {0}, 0, 1},
	/* enable display */
	{0x29, {0}, 0, -1}
};

#define _ROTATION_0 0
#define _ROTATION_1 (1<<5) | (1<<6) | (1<<2)
#define _ROTATION_2 (1<<6) | (1<<7) | (1<<2) | (1<<4)
#define _ROTATION_3 (1<<5) | (1<<7) | (1<<4)
static tsgl_driver_command _rotate(uint8_t rotation) {
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

    return (tsgl_driver_command) {0x36, {regvalue}, 1, -1};
}

static tsgl_driver_commandList _select(hal_pos x, hal_pos y, hal_pos x2, hal_pos y2) {
    return (tsgl_driver_commandList) {
        .list = {
            {0x2A, {x >> 8, x & 0xff, x2 >> 8, x2 & 0xff}, 4},
            {0x2B, {y >> 8, y & 0xff, y2 >> 8, y2 & 0xff}, 4},
            {0x2C, {0}, 0, -1}
        }
    };
}

// ----------------------------------------------

#define DISPLAY_PACKET_SIZE 1024

spi_device_handle_t display;
static uint8_t* sendbuffer = NULL;
static uint8_t* framebuffer = NULL;
static uint8_t currentTier;

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

static bool _doCommand(const tsgl_driver_command command) {
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

static void _doCommands(const tsgl_driver_command* list) {
    uint16_t cmd = 0;
    while (!_doCommand(list[cmd++]));
}

static void _doCommandList(const tsgl_driver_commandList list) {
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

void hal_init() {
	// ---- init sendbuffer
	sendbuffer = heap_caps_malloc(DISPLAY_PACKET_SIZE, MALLOC_CAP_DMA);

	// ---- init spi bus
	spi_bus_config_t buscfg={
        .miso_io_num=DISPLAY_MISO,
        .mosi_io_num=DISPLAY_MOSI,
        .sclk_io_num=DISPLAY_CLK,
        .quadwp_io_num=-1,
        .quadhd_io_num=-1,
        .max_transfer_sz = DISPLAY_PACKET_SIZE
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

	#ifdef DISPLAY_RST
		gpio_set_level(DISPLAY_RST, false);
		hal_delay(100);
		gpio_set_level(DISPLAY_RST, true);
		hal_delay(100);
	#endif

	_doCommands(display_init);
	_doCommand(_rotate(DISPLAY_ROTATION));
	_sendSelectAll();
}

void hal_delay(uint32_t milliseconds) {
	size_t ticks = milliseconds / portTICK_PERIOD_MS;
    if (ticks <= 0) ticks = 1;
    vTaskDelay(ticks);
}

// ---------------------------------------------- framebuffer

void hal_createBuffer(uint8_t tier) {
	currentTier = tier;

	size_t size = 0;
	switch (tier) {
		case 1: //1 bit per color
			size = (DISPLAY_WIDTH * DISPLAY_HEIGHT) / 8;
			break;

		case 2: //4 bit per color
			size = (DISPLAY_WIDTH * DISPLAY_HEIGHT) / 2;
			break;
		
		case 3: //8 bit per color
			size = DISPLAY_WIDTH * DISPLAY_HEIGHT;
			break;

		default:
			return;
	}

	if (framebuffer == NULL) {
		framebuffer = malloc(size);
	} else {
		framebuffer = realloc(framebuffer, size);
	}


}

void hal_sendBuffer() {
	switch (currentTier) {
		case 1:
			_sendData(sendbuffer, DISPLAY_PACKET_SIZE);
			break;
	}
}

// ---------------------------------------------- touchscreen