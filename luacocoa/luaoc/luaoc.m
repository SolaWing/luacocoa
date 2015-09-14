//
//  luaoc.m
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc.h"
#import "lualib.h"
#import "lauxlib.h"
#import <objc/runtime.h>

#import "luaoc_class.h"
#import "luaoc_instance.h"
#import "luaoc_struct.h"
#import "luaoc_var.h"
#import "luaoc_helper.h"
#import "luaoc_block.h"
#import "luaoc_encode.h"

#ifndef NO_USE_FFI
#import "ffi_wrap.h"
#endif

lua_State *gLua_main_state = NULL;

lua_State* luaoc_setup(){
  lua_State *L = luaL_newstate();
  gLua_main_state = L;

  luaL_openlibs(L);

  luaL_requiref(L, "oc", luaopen_luaoc, true);

  lua_settop(L, 0);

  // TODO: create a dedicated queue, to prevent lua code run at other thread.
  // currently only use main thread

  return L;
}

void luaoc_close() {
  if (gLua_main_state) {
    lua_close(gLua_main_state);
    gLua_main_state = NULL;
  }
}

static const luaL_Reg luaoc_funcs[] = {
    {"tolua",       luaoc_tolua },
    // will autoconvert to oc type when needed
    // {"tooc",  tooc  },
    {"retain",      luaoc_retain},
    {"release",     luaoc_release},
    {"super",       luaoc_super},
    {"weakvar",     luaoc_weakvar},
    {"getvar",      luaoc_getvar},
    {"setvar",      luaoc_setvar},
    {"invoke",      luaoc_call_block},
    {NULL,          NULL  },
};

static int __index(lua_State *L) {
    // index class
    const char* name = luaL_checkstring(L, 2);
    Class cls = objc_getClass(name);
    if (cls) {
        luaoc_push_class(L, cls);
        return 1;
    }

    // index struct
    lua_rawgetfield(L, 1, "struct");
    lua_pushvalue(L, 2);
    if ( lua_gettable(L, -2) != LUA_TNIL ) return 1;
    lua_pop(L, 2);

    DLOG("unknown name %s, did you spell correct?", name);
    lua_pushnil(L);
    return 1;
}

static const luaL_Reg luaoc_metafuncs[] = {
    {"__index", __index},
    {NULL, NULL},
};

int luaopen_luaoc(lua_State *L){
#ifndef NO_USE_FFI
  ffi_initialize();
#endif

  luaL_newlib(L, luaoc_funcs);
  luaL_newlib(L, luaoc_metafuncs);
  lua_setmetatable(L, -2);

  luaopen_luaoc_class(L);
  lua_rawsetfield(L, -2, "class");

  luaopen_luaoc_instance(L);
  lua_pop(L, 1);

  luaopen_luaoc_struct(L);
  lua_rawsetfield(L, -2, "struct");

  luaopen_luaoc_var(L);
  lua_rawsetfield(L, -2, "var");

  luaopen_luaoc_encoding(L);
  lua_rawsetfield(L, -2, "encode");

  luaopen_luaoc_block(L);
  lua_rawsetfield(L, -2, "block");

  return 1;
}

