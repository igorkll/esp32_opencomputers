#pragma once

#include <stdint.h>

static uint8_t _increment(uint8_t* v) {
    (*v)++;
    return *v;
}

#define LUA_ARG_LUA L
#define LUA_ARG_BOOL lua_toboolean(L, _increment(&i))
#define LUA_ARG_INT luaL_checkinteger(L, _increment(&i))
#define LUA_ARG_NUM luaL_checknumber(L, _increment(&i))
#define LUA_ARG_STR luaL_checkstring(L, _increment(&i))
#define LUA_ARG_USR lua_touserdata(L, _increment(&i))

#define LUA_RET_BOOL(val) lua_pushboolean(L, val)
#define LUA_RET_INT(val) lua_pushinteger(L, val)
#define LUA_RET_NUM(val) lua_pushnumber(L, val)
#define LUA_RET_STR(val) lua_pushstring(L, val)

#define LUA_BIND_VOID(func, args) { \
    int c_func(lua_State* L) { \
        uint8_t i = 0; \
        func args; \
        return 0; \
    } \
    lua_pushcfunction(lua, c_func); \
    lua_setglobal(lua, #func); \
}

#define LUA_BIND_RETR(func, args, returnType) { \
    int c_func(lua_State* L) { \
        uint8_t i = 0; \
        returnType(func args); \
        return 1; \
    } \
    lua_pushcfunction(lua, c_func); \
    lua_setglobal(lua, #func); \
}

#define LUA_PUSH_INT(val) { \
    lua_pushinteger(lua, val); \
    lua_setglobal(lua, #val); \
}

#define LUA_PUSH_USR(val) { \
    lua_pushlightuserdata(lua, val); \
    lua_setglobal(lua, #val); \
}