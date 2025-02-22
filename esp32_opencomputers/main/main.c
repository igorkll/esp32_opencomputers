// esp-idf - 5.3
// display - st7796 480x320

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "main.h"
#include "hal.h"
#include "canvas.h"

static void bsod(canvas_t* canvas, const char* text) {
	canvas_setDepth(canvas, 8);
	canvas_setResolution(canvas, 80, 25);
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
}

void _main() {
	hal_init();

	canvas_t* canvas = canvas_create(50, 16, 1);

	
	lua_State* lua = luaL_newstate();
    luaL_openlibs(lua);
    if (luaL_dofile(lua, "/storage/machine.lua")) {
		bsod(canvas, lua_tostring(lua, -1));
    } else {
		bsod(canvas, "computer halted");
	}
    lua_close(lua);

	hal_sendBuffer(canvas, true);

	hal_delay(1000);
	
	canvas_setResolution(canvas, 16, 4);
	canvas_setDepth(canvas, 4);
	canvas_setBackground(canvas, 0xff00ff, false);
	canvas_setForeground(canvas, 0xff0000, false);
	canvas_fill(canvas, 1, 1, canvas->sizeX, canvas->sizeY, 'A');
	canvas_setBackground(canvas, 0x000000, false);
	canvas_setForeground(canvas, 0xff8800, false);
	uint8_t num = 0;
    while (true) {
		for (size_t i = 1; i <= canvas->sizeX; i++) {
			canvas_fill(canvas, i, 1, 1, canvas->sizeY, (num++ % 10) + '0');
			hal_sendBuffer(canvas, true);
			hal_delay(50);
		}
    }
}