//
//  luaoc_instance.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_instance.h"
#import "lua.h"
#import "lauxlib.h"

static int __index(lua_State *L){
  return 1;
}

static int __newindex(lua_State *L){
  return 1;
}

static int __gc(lua_State *L){
  return 0;
}

static const luaL_Reg metaFunctions[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {"__gc", __gc},
  {NULL, NULL}
};

int luaopen_luaoc_instance(lua_State* L) {
  luaL_newmetatable(L, LUAOC_INSTANCE_METATABLE_NAME);
  luaL_setfuncs(L, metaFunctions, 0);
  lua_pop(L, 1);

  lua_pushboolean(L, 1);

  return 1;
}
