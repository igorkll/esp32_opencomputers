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
	hal_init();
	hal_createBuffer(1);

    while (true) {
		hal_sendBuffer();
        vTaskDelay(1);
    }
}