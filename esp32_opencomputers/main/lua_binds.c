#include "lua_binds.h"
#include "lua_binder.h"

#include "sound.h"
#include "canvas.h"
#include "hal.h"

void lua_binds_bind(lua_State* lua) {
	// ---- sound
	LUA_BIND_VOID(sound_computer_beep, (LUA_ARG_INT, LUA_ARG_NUM));
	LUA_BIND_VOID(sound_computer_beepString, (LUA_ARG_STR, LUA_ARG_INT));

	// ---- hal
	LUA_BIND_VOID(hal_delay, (LUA_ARG_INT));
}