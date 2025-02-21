#include "hal.h"
#include <esp_heap_caps.h>

#define DISPLAY_PACKET_SIZE 1024

spi_bus_add_device display;
static uint8_t* sendbuffer = NULL;
static uint8_t* framebuffer = NULL;

typedef struct {
    gpio_num_t pin;
    bool state;
} spi_pretransfer_info;

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
		gpio_set_level(rst, false);
		hal_delay(100);
		gpio_set_level(rst, true);
		hal_delay(100);
	#endif
}

void hal_delay(uint32_t milliseconds) {
	size_t ticks = milliseconds / portTICK_PERIOD_MS;
    if (ticks <= 0) ticks = 1;
    vTaskDelay(ticks);
}

// ---------------------------------------------- framebuffer

void hal_createBuffer(uint8_t tier) {
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

}

// ---------------------------------------------- touchscreen