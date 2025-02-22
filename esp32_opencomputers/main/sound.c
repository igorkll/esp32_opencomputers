#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "sound.h"
#include "hal.h"
#include "stddef.h"
#include "functions.h"

void sound_computer_beep(uint16_t freq, float time) {
	if (time < 0.05) time = 0.05;
	if (time > 5) time = 5;
	time = floorf(time * 20) / 20;

	hal_sound_channel channel = {
		.enabled = true,
		.disableTimer = time * SOUND_FREQ,
		.freq = freq,
		.volume = 8,
		.wave = hal_sound_square
	};
	hal_sound_updateChannel(SOUND_CHANNEL_BEEP, channel);
	hal_delay((time * 1000) + 100);
}

static void _beepString(void* _text) {
	char* text = _text;
	size_t len = strlen(text);
	hal_sound_channel channel = {
		.enabled = true,
		.freq = 1000,
		.volume = 8,
		.wave = hal_sound_square
	};
	
	for (size_t i = 0; i < len; i++) {
		float beepTime;
		if (text[i] == '.') {
			beepTime = 0.2;
		} else {
			beepTime = 0.4;
		}

		channel.disableTimer = beepTime * SOUND_FREQ;
		hal_sound_updateChannel(SOUND_CHANNEL_BEEP, channel);
		hal_delay((beepTime * 1000) + 50);
	}

	free(text);
}

void sound_computer_beepString(char* text, size_t len) {
	char* string = malloc(len + 1);
	memcpy(string, text, len);
	string[len] = 0;
	hal_task(_beepString, string);
}