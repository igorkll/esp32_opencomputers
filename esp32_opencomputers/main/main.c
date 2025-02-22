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

static void rawSandbox(lua_State* lua) {
	luaL_openlibs(lua);

	// ---- sound
	LUA_BIND_VOID(sound_computer_beep, (LUA_ARG_INT, LUA_ARG_NUM));
	LUA_BIND_VOID(sound_computer_beepString, (LUA_ARG_STR, LUA_ARG_INT));

	// ---- hal
	LUA_BIND_VOID(hal_delay, (LUA_ARG_INT));
}

void _main() {
	canvas_t* canvas = canvas_create(50, 16, 1);
	lua_State* lua = luaL_newstate();
    rawSandbox(lua);
    if (luaL_dofile(lua, "/storage/machine.lua")) {
		bsod(canvas, lua_tostring(lua, -1));
    } else {
		bsod(canvas, "computer halted");
	}
    lua_close(lua);
	hal_display_sendBuffer(canvas, false);
	
    while (true) {
		hal_delay(1000);
    }
}