// esp-idf - 5.3
// display - st7796 480x320

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "main.h"
#include "hal.h"
#include "canvas.h"
#include "sound.h"
#include "lua_binder.h"
#include "config.h"

static hal_led* led_power;
static hal_led* led_error;
static hal_led* led_hdd;

static hal_button* button_wakeup;
static hal_button* button_shutdown;
static hal_button* button_reboot;

static void bsod(canvas_t* canvas, const char* text) {
	canvas_setDepth(canvas, 8);
	canvas_setResolution(canvas, BSOD_RESOLUTION_X, BSOD_RESOLUTION_Y);
	canvas_setBackground(canvas, BSOD_COLOR_BG, false);
	canvas_setForeground(canvas, BSOD_COLOR_TEXT, false);
	canvas_fill(canvas, 1, 1, canvas->sizeX, canvas->sizeY, ' ');

	size_t len = strlen(text);
	canvas_pos x = 1;
	canvas_pos y = 3;
	for (size_t i = 0; i < len; i++) {
		char chr = text[i];
		canvas_set(canvas, x++, y, &chr, 1, false);
		if (chr == '\n' || x >= canvas->sizeX) {
			x = 1;
			y++;
		}
	}

	canvas_setBackground(canvas, BSOD_COLOR_TITLE_BG, false);
	canvas_setForeground(canvas, BSOD_COLOR_TITLE, false);
	canvas_set(canvas, 1, 1, "Unrecoverable Error", 0, false);

	sound_computer_beepString("--", 2);
}

static void blackscreen(canvas_t* canvas) {
	canvas_setDepth(canvas, 1);
	canvas_setResolution(canvas, 50, 16);
	canvas_setBackground(canvas, 0x000000, false);
	canvas_setForeground(canvas, 0xffffff, false);
	canvas_fill(canvas, 1, 1, canvas->sizeX, canvas->sizeY, ' ');
}

typedef struct {
	lua_State* lua;
	size_t count;
} _list_bind_data;

static void _list_bind_callback(void* arg, const char* filename) {
	_list_bind_data* bind_data = (_list_bind_data*)arg;
	bind_data->count++;
	lua_pushstring(bind_data->lua, filename);
}

static int _list_bind(lua_State* lua) {
	const char* path = luaL_checkstring(lua, 1);
	_list_bind_data bind_data = {
		.lua = lua,
		.count = 0
	};
	hal_filesystem_list(path, _list_bind_callback, (void*)(&bind_data));
	return bind_data.count;
}

static int _getPoint_bind(lua_State* lua) {
	uint8_t index = luaL_checknumber(lua, 1);
	hal_touchscreen_point point = hal_touchscreen_getPoint(index);
	lua_pushinteger(lua, point.x);
	lua_pushinteger(lua, point.y);
	lua_pushnumber(lua, point.z);
	return 3;
}

static int _sendBuffer_bind(lua_State* lua) {
	canvas_t* canvas = lua_touserdata(lua, 1);
	hal_display_sendInfo sendInfo = hal_display_sendBuffer(canvas);
	lua_pushinteger(lua, sendInfo.startX);
	lua_pushinteger(lua, sendInfo.startY);
	lua_pushinteger(lua, sendInfo.charSizeX);
	lua_pushinteger(lua, sendInfo.charSizeY);
	return 4;
}

static int _canvasGet_bind(lua_State* lua) {
	canvas_t* canvas = lua_touserdata(lua, 1);
	int x = luaL_checknumber(lua, 2);
	int y = luaL_checknumber(lua, 3);
	canvas_get_result pixelInfo = canvas_get(canvas, x, y);
	lua_pushinteger(lua, pixelInfo.chr);
	lua_pushinteger(lua, pixelInfo.foreground);
	lua_pushinteger(lua, pixelInfo.background);
	lua_pushinteger(lua, pixelInfo.foregroundIndex);
	lua_pushinteger(lua, pixelInfo.backgroundIndex);
	lua_pushboolean(lua, pixelInfo.foreground_isPal);
	lua_pushboolean(lua, pixelInfo.background_isPal);
	return 7;
}

static double hddled_updateTime = -1;
static void _hdd_blink() {
	hddled_updateTime = hal_uptimeM();
}

static void rawSandbox(lua_State* lua, canvas_t* canvas) {
	luaL_openlibs(lua);
	LUA_PUSH_USR(canvas);
	lua_pushinteger(lua, hal_random());
	lua_setglobal(lua, "_defaultRandomSeed");

	// ---- defines
	LUA_PUSH_INT(DISPLAY_WIDTH);
	LUA_PUSH_INT(DISPLAY_HEIGHT);
	LUA_PUSH_INT(RENDER_RESOLUTION_X);
	LUA_PUSH_INT(RENDER_RESOLUTION_Y);
	LUA_PUSH_INT(CONTROL_SECONDARY_PRESS_ON_LONG_TOUCH_TIME);
	LUA_PUSH_INT(ENV_EEPROM_SIZE);
	LUA_PUSH_INT(ENV_EEPROM_DATASIZE);
	LUA_PUSH_BOOL(ENV_EEPROM_READONLY);

	// ---- canvas
	LUA_BIND_VOID(canvas_setResolution, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_setDepth, (LUA_ARG_USR, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_setBackground, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_BOOL));
	LUA_BIND_VOID(canvas_setForeground, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_BOOL));
	LUA_BIND_RETR(canvas_getBackground, (LUA_ARG_USR), LUA_RET_INT);
	LUA_BIND_RETR(canvas_getForeground, (LUA_ARG_USR), LUA_RET_INT);
	LUA_BIND_VOID(canvas_fill, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_set, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_STR, LUA_ARG_INT, LUA_ARG_BOOL));
	LUA_BIND_VOID(canvas_copy, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_setPaletteColor, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_RETR(canvas_getPaletteColor, (LUA_ARG_USR, LUA_ARG_INT), LUA_RET_INT);
	lua_pushcfunction(lua, _canvasGet_bind);
	lua_setglobal(lua, "canvas_get");

	// ---- display
	lua_pushcfunction(lua, _sendBuffer_bind);
	lua_setglobal(lua, "hal_display_sendBuffer");
	LUA_BIND_VOID(hal_display_backlight, (LUA_ARG_BOOL));

	// ---- touchscreen
	LUA_BIND_RETR(hal_touchscreen_touchCount, (), LUA_RET_INT);
	lua_pushcfunction(lua, _getPoint_bind);
	lua_setglobal(lua, "hal_touchscreen_getPoint");

	// ---- font
	LUA_BIND_RETR(font_toUChar, (LUA_ARG_STR, LUA_ARG_INT), LUA_RET_INT);
	LUA_BIND_RETR(font_findOffset, (LUA_ARG_INT), LUA_RET_INT);
	LUA_BIND_RETR(font_charWidth, (LUA_ARG_INT), LUA_RET_INT);

	// ---- filesystem
	LUA_BIND_RETR(hal_filesystem_exists, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_isDirectory, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_isFile, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_size, (LUA_ARG_STR), LUA_RET_INT);
	LUA_BIND_RETR(hal_filesystem_mkdir, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_count, (LUA_ARG_STR, LUA_ARG_BOOL, LUA_ARG_BOOL), LUA_RET_INT);
	LUA_BIND_RETR(hal_filesystem_lastModified, (LUA_ARG_STR), LUA_RET_INT);
	lua_pushcfunction(lua, _list_bind);
	lua_setglobal(lua, "hal_filesystem_list");

	// ---- sound
	LUA_BIND_VOID(sound_computer_beep, (LUA_ARG_INT, LUA_ARG_NUM));
	LUA_BIND_VOID(sound_computer_beepString, (LUA_ARG_STR, LUA_ARG_INT));
	LUA_BIND_RETR(sound_beep_addBeep, (LUA_ARG_INT, LUA_ARG_NUM), LUA_RET_BOOL);
	LUA_BIND_VOID(sound_beep_beep, ());
	LUA_BIND_RETR(sound_beep_getBeepCount, (), LUA_RET_INT);

	// ---- hal
	LUA_BIND_RETR(hal_uptimeM, (), LUA_RET_NUM);
	LUA_BIND_RETR(hal_uptime, (), LUA_RET_NUM);
	LUA_BIND_VOID(hal_delay, (LUA_ARG_INT));
	LUA_BIND_VOID(hal_yield, ());
	LUA_BIND_RETR(hal_freeMemory, (), LUA_RET_INT);
	LUA_BIND_RETR(hal_totalMemory, (), LUA_RET_INT);

	// ---- other
	LUA_BIND_VOID(_hdd_blink, ());
}

static void _bg_task(void* arg) {
	while (true) {
		if (hddled_updateTime >= 0) {
			hal_led_setBool(led_hdd, hal_uptimeM() - hddled_updateTime < 400 && hal_frandom() > 0.1);
		} else {
			hal_led_disable(led_hdd);
		}
		hal_delay(1000 / 60);
	}
}

static char* shutdown_error = "7dcb1fb3";
static char* reboot_error = "9bb7973d";
static void _lua_hook(lua_State *L) {
	if (hal_button_hasTriggered(button_shutdown)) {
		lua_pushstring(L, shutdown_error);
        lua_error(L);
	} else if (hal_button_hasTriggered(button_reboot)) {
		lua_pushstring(L, reboot_error);
		lua_error(L);
	}
}

static void shutdownAction(canvas_t* canvas, lua_State* lua, bool reboot) {
	HAL_LOGI("shutdown: %i\n", reboot);
	blackscreen(canvas);
	if (!reboot) {
		hal_led_disable(led_power);
		hal_display_backlight(false);
		lua_close(lua);
		hal_display_sendBuffer(canvas);
		hal_powerlock_unlock();
	}
}

void _main() {
	// ---- leds
	#ifdef LEDS_POWER_PIN
		led_power = hal_led_new(LEDS_POWER_PIN, LEDS_POWER_INVERT, LEDS_POWER_LIGHT_ON, LEDS_POWER_LIGHT_OFF);
	#else
		led_power = hal_led_stub();
	#endif

	#ifdef LEDS_ERROR_ALIAS_POWER
		led_error = led_power;
	#elif LEDS_ERROR_PIN
		led_error = hal_led_new(LEDS_ERROR_PIN, LEDS_ERROR_INVERT, LEDS_ERROR_LIGHT_ON, LEDS_ERROR_LIGHT_OFF);
	#else
		led_error = hal_led_stub();
	#endif

	#ifdef LEDS_HDD_PIN
		led_hdd = hal_led_new(LEDS_HDD_PIN, LEDS_HDD_INVERT, LEDS_HDD_LIGHT_ON, LEDS_HDD_LIGHT_OFF);
	#else
		led_hdd = hal_led_stub();
	#endif

	// ---- buttons
	#ifdef BUTTON_WAKEUP_PIN
		button_wakeup = hal_button_new(BUTTON_WAKEUP_PIN, BUTTON_WAKEUP_INVERT, BUTTON_WAKEUP_NEEDHOLD, BUTTON_WAKEUP_PULL);
	#else
		button_wakeup = hal_button_stub();
	#endif

	#ifdef BUTTON_SHUTDOWN_ALIAS_WAKEUP
		button_shutdown = button_wakeup;
	#elif BUTTON_SHUTDOWN_PIN
		button_shutdown = hal_button_new(BUTTON_SHUTDOWN_PIN, BUTTON_SHUTDOWN_INVERT, BUTTON_SHUTDOWN_NEEDHOLD, BUTTON_SHUTDOWN_PULL);
	#else
		button_shutdown = hal_button_stub();
	#endif

	#ifdef BUTTON_REBOOT_PIN
		button_reboot = hal_button_new(BUTTON_REBOOT_PIN, BUTTON_REBOOT_INVERT, BUTTON_REBOOT_NEEDHOLD, BUTTON_REBOOT_PULL);
	#else
		button_reboot = hal_button_stub();
	#endif

	// ---- init
	hal_task(_bg_task, NULL);
	sound_init();
	canvas_t* canvas = canvas_create(50, 16, 1);

	bool disabled = POWER_DEFAULT_DISABLED;
	bool crashed = false;
	if (disabled) {
		hal_powerlock_unlock();
	}

	while (true) {
		while (disabled) {
			if (hal_button_hasTriggered(button_wakeup)) break;
			if (crashed && hal_button_hasTriggered(button_reboot)) break;
			hal_yield();
		}

		crashed = false;
		hal_powerlock_lock();
		hal_led_disable(led_error);
		hal_led_enable(led_power);
		blackscreen(canvas);
		hal_display_sendBuffer(canvas);
		hal_display_backlight(true);

		while (true) {
			lua_State* lua = luaL_newstate();
		    lua_sethook(lua, _lua_hook, LUA_MASKCOUNT, 16);
			rawSandbox(lua, canvas);
			if (luaL_dofile(lua, "/rom/machine.lua")) {
				char* err = lua_tostring(lua, -1);
				if (strcmp(err, shutdown_error) == 0) {
					shutdownAction(canvas, lua, false);
					break;
				} else if (strcmp(err, reboot_error) == 0) {
					shutdownAction(canvas, lua, true);
				} else {
					HAL_LOGE("%s\n", err);
					bsod(canvas, err);
					hal_led_disable(led_power);
					#ifdef LEDS_ERROR_NO_BLINK
						hal_led_enable(led_error);
					#else
						hal_led_blink(led_error);
					#endif
					lua_close(lua);
					hal_display_sendBuffer(canvas);
					crashed = true;
					break;
				}
			} else {
				bool reboot = lua_toboolean(lua, -1);
				shutdownAction(canvas, lua, reboot);
				if (!reboot) {
					break;
				}
			}
			lua_close(lua);
			hal_display_sendBuffer(canvas);
		}

		disabled = true;
	}
}