// esp-idf - 5.3
// display - st7796 480x320

#include <sdkconfig.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>

#include "hal.h"

void app_main() {
	hal_initDisplay();

	hal_canvas* canvas;
    while (true) {
		canvas = hal_createBuffer(50, 16, 1);
		hal_bufferSetBg(canvas, 0xff0000, false);
		hal_bufferSetFg(canvas, 0xff00ff, false);
		hal_bufferFill(canvas, 3, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		hal_bufferFree(canvas);
        hal_delay(1000);

		canvas = hal_createBuffer(50, 16, 4);
		hal_bufferSetBg(canvas, 0xff0000, false);
		hal_bufferSetFg(canvas, 0xff00ff, false);
		hal_bufferFill(canvas, 4, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		hal_bufferFree(canvas);
        hal_delay(1000);

		canvas = hal_createBuffer(50, 16, 8);
		hal_bufferSetBg(canvas, 0xff0000, false);
		hal_bufferSetFg(canvas, 0xff00ff, false);
		hal_bufferFill(canvas, 5, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		hal_bufferFree(canvas);
        hal_delay(1000);

		canvas = hal_createBuffer(50, 16, 4);
		for (size_t i = 0; i < 16; i++) {
			hal_bufferSetBg(canvas, i, true);
			hal_bufferFill(canvas, 4, 1 + i, 3, 1, 'A');
		}
		hal_sendBuffer(canvas);
		hal_bufferFree(canvas);
        hal_delay(1000);
    }
}