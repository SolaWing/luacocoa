//
//  luaoc_var.m
//  luaoc
//
//  Created by Wangxh on 15/8/3.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_var.h"
#import "luaoc_helper.h"
#import "lauxlib.h"

#import <Foundation/Foundation.h>

void luaoc_push_var(lua_State *L, const char* typeDescription, void* initRef) {
  NSCParameterAssert(typeDescription);

  char *structName = NULL;
  const char *endPos;
  int size = luaoc_get_one_typesize(typeDescription, &endPos, &structName);

  if (size == 0) {DLOG("empty var size!!"); lua_pushnil(L); return;}

  void* ud = lua_newuserdata(L, size);
  if (initRef) memcpy(ud, initRef, size);
  else memset(ud, 0, size);

  luaL_getmetatable(L, LUAOC_VAR_METATABLE_NAME);
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

static const luaL_Reg varFuncs[] = {
  {NULL, NULL},
};

static int createVar(lua_State *L){
  return 1;
}

static const luaL_Reg varMetaFuncs[] = {
  {"__call", createVar},
  {NULL, NULL},
};

static int __index(lua_State *L) {
  void* ud = luaL_checkudata(L, 1, LUAOC_VAR_METATABLE_NAME);

  lua_getuservalue(L,1);
  lua_pushvalue(L, 2);
  if (lua_rawget(L, -2) == LUA_TNIL && lua_type(L,2) == LUA_TSTRING){
    const char *key = lua_tostring(L,2);
    if (strcmp(key, "v") == 0) {
      lua_rawgetfield(L, -2, "__encoding");
      luaoc_push_obj(L, lua_tostring(L, -1), ud);
    }
  }

  return 1;
}

static int __newindex(lua_State *L) {
  void* ud = luaL_checkudata(L, 1, LUAOC_VAR_METATABLE_NAME);

  const char* key = lua_tostring(L, 2);
  if (strcmp(key, "v") == 0) {
    lua_getuservalue(L,1);
    lua_rawgetfield(L, -1, "__encoding");
    size_t outSize;
    void* v = luaoc_copy_toobjc(L, 3, lua_tostring(L, -1), &outSize);
    if (outSize <= lua_rawlen(L, 1)) {
      memcpy(ud, v, outSize);
    } else {
      DLOG("assign to wrong data!");
    }
    free(v);
  } else { // set in uservalue
    lua_getuservalue(L, 1);
    lua_insert(L, 2);
    lua_rawset(L, 2);                         // udv[key] = value
  }

  return 0;
}

static const luaL_Reg metaFuncs[] = {
  {"__index",__index},
  {"__newindex",__newindex},
  {NULL, NULL},
};

int luaopen_luaoc_var(lua_State *L) {
  luaL_newlib(L, varFuncs);
  luaL_newlib(L, varMetaFuncs);
  lua_setmetatable(L, -2);

  luaL_newmetatable(L, LUAOC_VAR_METATABLE_NAME);
  luaL_setfuncs(L, metaFuncs, 0);

  lua_pushinteger(L, luaoc_var_type);
  lua_rawsetfield(L, -2, "__type");

  lua_pop(L,1);

  return 1;
}

