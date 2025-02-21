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
#include "canvas.h"

void app_main() {
	hal_initDisplay();

	canvas_t* canvas;
    while (true) {
		canvas = canvas_create(50, 16, 1);
		canvas_setBackground(canvas, 0xff0000, false);
		canvas_setForeground(canvas, 0xff00ff, false);
		canvas_fill(canvas, 3, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		canvas_free(canvas);
        hal_delay(1000);

		canvas = canvas_create(50, 16, 4);
		canvas_setBackground(canvas, 0xff0000, false);
		canvas_setForeground(canvas, 0xff00ff, false);
		canvas_fill(canvas, 4, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		canvas_free(canvas);
        hal_delay(1000);

		canvas = canvas_create(50, 16, 8);
		canvas_setBackground(canvas, 0xff0000, false);
		canvas_setForeground(canvas, 0xff00ff, false);
		canvas_fill(canvas, 5, 3, 3, 2, 'A');
		hal_sendBuffer(canvas);
		canvas_free(canvas);
        hal_delay(1000);

		canvas = canvas_create(50, 16, 4);
		for (size_t i = 0; i < 16; i++) {
			canvas_setBackground(canvas, i, true);
			canvas_fill(canvas, 4, 1 + i, 3, 1, 'A');
		}
		hal_sendBuffer(canvas);
		canvas_free(canvas);
        hal_delay(1000);
    }
}