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

static void bsod(canvas_t* canvas, const char* text) {
	canvas_setDepth(canvas, 8);
	canvas_setResolution(canvas, 50, 16);
	canvas_setBackground(canvas, 0x0000ff, false);
	canvas_setForeground(canvas, 0xffffff, false);
	canvas_fill(canvas, 1, 1, canvas->sizeX, canvas->sizeY, ' ');

	size_t len = strlen(text);
	canvas_pos x = 1;
	canvas_pos y = 3;
	for (size_t i = 0; i < len; i++) {
		char chr = text[i];
		canvas_set(canvas, x++, y, &chr, 1);
		if (chr == '\n' || x >= canvas->sizeX) {
			x = 1;
			y++;
		}
	}

	canvas_setBackground(canvas, 0xffffff, false);
	canvas_setForeground(canvas, 0x0000ff, false);
	canvas_set(canvas, 1, 1, "Unrecoverable Error", 0);

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

static void rawSandbox(lua_State* lua, canvas_t* canvas) {
	luaL_openlibs(lua);
	LUA_PUSH_USR(canvas);

	// ---- defines
	LUA_PUSH_INT(DISPLAY_WIDTH);
	LUA_PUSH_INT(DISPLAY_HEIGHT);

	// ---- canvas
	LUA_BIND_VOID(canvas_setResolution, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_setDepth, (LUA_ARG_USR, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_setBackground, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_BOOL));
	LUA_BIND_VOID(canvas_setForeground, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_BOOL));
	LUA_BIND_RETR(canvas_getBackground, (LUA_ARG_USR), LUA_RET_INT);
	LUA_BIND_RETR(canvas_getForeground, (LUA_ARG_USR), LUA_RET_INT);
	LUA_BIND_VOID(canvas_fill, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_set, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_STR, LUA_ARG_INT));
	LUA_BIND_VOID(canvas_copy, (LUA_ARG_USR, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT, LUA_ARG_INT));
	//LUA_BIND_RETR(canvas_get, (LUA_ARG_USR, LUA_ARG_INT), LUA_RET_BOOL);

	// ---- display
	LUA_BIND_VOID(hal_display_backlight, (LUA_ARG_BOOL));

	// ---- touchscreen

	// ---- filesystem
	LUA_BIND_RETR(hal_filesystem_exists, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_isDirectory, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_size, (LUA_ARG_STR), LUA_RET_INT);
	LUA_BIND_RETR(hal_filesystem_mkdir, (LUA_ARG_STR), LUA_RET_BOOL);
	LUA_BIND_RETR(hal_filesystem_count, (LUA_ARG_STR, LUA_ARG_BOOL, LUA_ARG_BOOL), LUA_RET_INT);
	LUA_BIND_RETR(hal_filesystem_lastModified, (LUA_ARG_STR), LUA_RET_INT);
	lua_pushcfunction(lua, _list_bind);
    lua_setglobal(lua, "hal_filesystem_list");

	// ---- sound
	LUA_BIND_VOID(sound_computer_beep, (LUA_ARG_INT, LUA_ARG_NUM));
	LUA_BIND_VOID(sound_computer_beepString, (LUA_ARG_STR, LUA_ARG_INT));

	// ---- hal
	LUA_BIND_RETR(hal_uptime, (), LUA_RET_NUM);
	LUA_BIND_VOID(hal_delay, (LUA_ARG_INT));
	LUA_BIND_RETR(hal_freeMemory, (), LUA_RET_INT);
	LUA_BIND_RETR(hal_totalMemory, (), LUA_RET_INT);
}

void _main() {
	canvas_t* canvas = canvas_create(50, 16, 1);
	hal_display_backlight(true);
	while (true) {
		lua_State* lua = luaL_newstate();
		rawSandbox(lua, canvas);
		if (luaL_dofile(lua, "/storage/machine.lua")) {
			char* err = lua_tostring(lua, -1);
			HAL_LOGE("lua crashed: %s\n", err);
			bsod(canvas, err);
			lua_close(lua);
			hal_display_sendBuffer(canvas, false);
			break;
		} else {
			bool reboot = lua_toboolean(lua, -1);
			HAL_LOGI("shutdown: %i\n", reboot);
			blackscreen(canvas);
			if (!reboot) {
				lua_close(lua);
				hal_display_sendBuffer(canvas, false);
				break;
			}
		}
		lua_close(lua);
		hal_display_sendBuffer(canvas, false);
	}
	
    while (true) {
		hal_delay(1000);
    }
}