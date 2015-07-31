//
//  luaoc_struct.m
//  luaoc
//
//  Created by Wangxh on 15/7/29.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_struct.h"
#import "lauxlib.h"
#import "luaoc_helper.h"

/// table use to find offset by name {struct_name = {name = offset, ...}, ...}
#define NAMED_STRUCT_TABLE_NAME "named_struct"

void luaoc_push_struct(lua_State *L, const char* typeDescription, void* structRef) {

}

static int __index(lua_State *L){
  return 1;
}

static int __newindex(lua_State *L){
  return 0;
}

static const luaL_Reg metaMethods[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {NULL, NULL},
};

static int pack(lua_State *L){
  return 1;
}

static const luaL_Reg structFunctions[] = {
  {"pack", pack},
  {NULL, NULL},
};

int luaopen_luaoc_struct(lua_State *L) {
  luaL_newlib(L, structFunctions);

  luaL_newmetatable(L, LUAOC_STRUCT_METATABLE_NAME);
  luaL_setfuncs(L, metaMethods, 0);

  lua_pushstring(L, "__type");
  lua_pushinteger(L, luaoc_struct_type);
  lua_rawset(L, -3);

  luaL_newmetatable(L, NAMED_STRUCT_TABLE_NAME);    // use to save named struct info
  lua_pop(L, 2);                                    // pop 2 metaTable

  return 1; // :structFunctions;
}

