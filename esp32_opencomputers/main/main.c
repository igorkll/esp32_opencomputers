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
	hal_canvas* canvas = hal_createBuffer(50, 16, 1);

    while (true) {
		hal_sendBuffer(canvas);
        vTaskDelay(1);
    }
}