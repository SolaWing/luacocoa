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

#import <stdlib.h>
#import <string.h>

#import <Foundation/Foundation.h>

/// table use to find offset by name {struct_name = {name = offset, ...}, ...}
#define NAMED_STRUCT_TABLE_NAME "named_struct"

void luaoc_push_struct(lua_State *L, const char* typeDescription, void* structRef) {
  char *structName = NULL;
  const char *endPos;
  int size = luaoc_get_one_typesize(typeDescription, &endPos, &structName);

  if (size == 0) {DLOG("empty struct size!!"); lua_pushnil(L); return;}

  void* ud = lua_newuserdata(L, size);
  memcpy(ud, structRef, size);

  luaL_getmetatable(L, LUAOC_STRUCT_METATABLE_NAME);
  lua_setmetatable(L, -2);

  { // the new user value table
    lua_newtable(L);

    lua_pushlstring(L, typeDescription, endPos-typeDescription);
    lua_rawsetfield(L, -2, "__encoding");

    if (structName){
      lua_pushstring(L, structName);
      lua_rawsetfield(L, -2, "__name");
    }

    lua_setuservalue(L, -2);
  }

  free(structName);
}

int luaoc_tostruct(lua_State *L, int index, void* outStructRef) {
  return luaoc_tostruct_n(L, index, outStructRef, INT_MAX);
}

int luaoc_tostruct_n(lua_State *L, int index, void* outStructRef, size_t n) {
  NSCParameterAssert(outStructRef);

  void* ud = luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
  if (NULL == ud) return false;

  size_t size = lua_rawlen(L, index);
  if (n < size) return false;

  memcpy(outStructRef, ud, size);
  return true;
}

void* luaoc_copystruct(lua_State *L, int index, size_t* outSize) {
  void* ud = luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
  if (NULL == ud) return false;

  size_t size = lua_rawlen(L, index);
  if (outSize) *outSize = size;

  void* ret = malloc(size);
  memcpy(ret, ud, size);

  return ret;
}

void* luaoc_getstruct(lua_State *L, int index) {
  return luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
}

static int __index(lua_State *L){
  lua_getuservalue(L, 1);
  lua_pushvalue(L, 2);

  lua_rawget(L, -2);

  return 1;
}

static int __newindex(lua_State *L){
  return 0;
}

static int __len(lua_State *L){
  lua_pushinteger(L, lua_rawlen(L, 1));
  return 1;
}

static const luaL_Reg metaMethods[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {"__len", __len},
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

