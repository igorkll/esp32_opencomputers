#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "sound.h"
#include "hal.h"
#include "stddef.h"
#include "functions.h"

// ---------------------------------------------- computer beep

void sound_computer_beep(uint16_t freq, float time) {
	if (time < 0.05) time = 0.05;
	if (time > 5) time = 5;
	time = floorf(time * 20) / 20;

	hal_sound_channel channel = {
		.enabled = true,
		.disableTimer = time * SOUND_FREQ,
		.freq = freq,
		.volume = 255,
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
		.volume = 255,
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

void sound_computer_beepString(const char* text, size_t len) {
	char* string = malloc(len + 1);
	memcpy(string, text, len);
	string[len] = 0;
	hal_task(_beepString, string);
}

// ---------------------------------------------- beep card

typedef struct {
	bool enable;
	uint16_t freq
	double deadline;
} sound_beep;

static uint8_t beep_index = 0;
static sound_beep currentBeeps[SOUND_BEEPCARD_CHANNELS];
static bool currentBeeps_lock = false;
static sound_beep beeps[SOUND_BEEPCARD_CHANNELS];

bool sound_beep_addBeep(uint16_t freq, float time) {
	if (beep_index < SOUND_BEEPCARD_CHANNELS) {
		beeps[beep_index++] = (sound_beep) {
			.enabled = true,
			.freq = freq,
			.deadline = time
		};
		return true;
	}
	return false;
}

void sound_beep_beep() {
	currentBeeps_lock = true;
	for (size_t i = 0; i < SOUND_BEEPCARD_CHANNELS; i++) {
		sound_beep* beep = &beeps[i];
		if (!beep->enable) continue;
		beep->deadline += hal_uptime();

		for (size_t i2 = SOUND_BEEPCARD_CHANNELS - 1; i2 >= 0; i2--) {
			if (!currentBeeps[i2].enable) {
				hal_sound_updateChannel(i2, (hal_sound_channel) {
					.enabled = true,
					.freq = beep->freq,
					.volume = 255,
					.wave = hal_sound_square
				});
				currentBeeps[i2] = *beep;
			}
		}
	}
	currentBeeps_lock = false;

	for (size_t i = 0; i < SOUND_BEEPCARD_CHANNELS; i++) {
		beeps[i] = (sound_beep) {.enabled=false};
	}
	beep_index = 0;
}

uint8_t sound_beep_getBeepCount() {
	uint8_t beepCount = 0;
	for (size_t i = 0; i < SOUND_BEEPCARD_CHANNELS; i++) {
		if (currentBeeps[i].enable) {
			beepCount++;
		}
	}
	return beepCount;
}

static void _beep_init(void* arg) {
	while (true) {
		if (!currentBeeps_lock) {
			double uptime = hal_uptime();
			for (size_t i = 0; i < SOUND_BEEPCARD_CHANNELS; i++) {
				sound_beep* beep = &currentBeeps[i]; 
				if (beep->enable && uptime >= beep->deadline) {
					beep->enable = false;
					hal_sound_updateChannel(i, (hal_sound_channel) {.enabled=false});
				}
			}
		}
		hal_delay(50);
	}
	
}

// ----------------------------------------------

void sound_init() {
	hal_task(_beep_init, NULL);
}