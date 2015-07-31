//
//  luaoc_instance.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "luaoc_instance.h"
#import "lua.h"
#import "lauxlib.h"
#import "luaoc_helper.h"

#import <objc/runtime.h>

void luaoc_push_instance(lua_State *L, id v){
  if (NULL == v){
    lua_pushnil(L); return;
  }

  LUA_PUSH_STACK(L);
  if (!luaL_getmetatable(L, LUAOC_INSTANCE_METATABLE_NAME)){
    // no meta table, there is some wrong , or call this method when not open
    DLOG("ERROR: can't get metaTable\n");
    LUA_POP_STACK(L, 1);
    return;
  }

  lua_pushstring(L, "loaded");
  lua_rawget(L, -2);                            // :meta loaded

  if (lua_rawgetp(L, -1, v) == LUA_TNIL){
    // bind new ud
    *(id*)lua_newuserdata(L, sizeof(id)) = v;

    lua_pushvalue(L, LUA_START_INDEX(L)+1);
    lua_setmetatable(L, -2);                            // + ud ; set ud meta

    lua_newtable(L);
    lua_setuservalue(L, -2);                            // ; set ud uservalue a newtable

    lua_pushvalue(L, -1);                               // copy ud
    lua_rawsetp(L, LUA_START_INDEX(L)+2, v);            // loaded[p] = ud

    [v retain];                                         // retain when create and release in gc
  }
  LUA_POP_STACK(L, 1);
  return;
}

void luaoc_push_super(lua_State *L, int index) {
  // NOTE: if use outside, may need type check
  LUA_PUSH_STACK(L);

  if (IS_RELATIVE_INDEX(index)) index = LUA_START_INDEX(L) + index + 1;

  id* ud = (id*)lua_touserdata(L, index);
  Class cls = NULL;
  if (luaL_getmetafield(L, index, "__type") == LUA_TNUMBER){
    LUA_INTEGER tt = lua_tointeger(L, -1);
    if (tt == luaoc_instance_type) cls = object_getClass(*ud);
    else if (tt == luaoc_super_type) cls = *(ud+1);
  }
  if (NULL == cls){
    luaL_error(L, "invalid instance type!");
  }

  cls = class_getSuperclass(cls);
  if (cls == nil){
    lua_pushnil(L);
    LUA_POP_STACK(L, 1);
    return;
  }

  id* su = (id*)lua_newuserdata(L, sizeof(id)*2);
  su[0] = *ud, su[1] = cls;

  luaL_getmetatable(L, LUAOC_SUPER_METATABLE_NAME);
  lua_setmetatable(L, -2);

  // use some uservalue
  lua_getuservalue(L, index);
  lua_setuservalue(L, -2);

  [*ud retain]; // retain it and release it in gc

  LUA_POP_STACK(L, 1); // + su
}

static int __index(lua_State *L){
  luaL_checkudata(L, 1, LUAOC_INSTANCE_METATABLE_NAME);

  lua_getuservalue(L, 1);
  lua_pushvalue(L, 2); // : ud key udv key
  // is nil and key is string , return message wrapper
  if (lua_rawget(L, -2) == LUA_TNIL && lua_type(L,2) == LUA_TSTRING) {
    if ( strcmp( lua_tostring(L, 2), "super" ) == 0 ){
      luaoc_push_super(L, 1);
    } else {
      lua_pushvalue(L,2); // cclosure with key as upvalue
      lua_pushcclosure(L, luaoc_msg_send, 1);
    }
  }

  return 1;
}

static int __newindex(lua_State *L){
  if (lua_isuserdata(L, 1)) {
    lua_getuservalue(L, 1);
    lua_insert(L, 2);
    lua_rawset(L, 2);                         // udv[key] = value
  }

  return 0;
}

static int __gc(lua_State *L){
  id* ud = (id*)luaL_checkudata(L, 1, LUAOC_INSTANCE_METATABLE_NAME);
  [*ud release];

  // TODO: need to test dealloc in gc, and call lua method

  return 0;
}

static const luaL_Reg metaFunctions[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {"__gc", __gc},
  {NULL, NULL}
};

int luaopen_luaoc_instance(lua_State* L) {
  LUA_PUSH_STACK(L);

  luaL_newmetatable(L, LUAOC_SUPER_METATABLE_NAME);
  luaL_setfuncs(L, metaFunctions, 0);

  lua_pushstring(L, "__type");
  lua_pushinteger(L, luaoc_super_type);
  lua_rawset(L, -3);

  luaL_newmetatable(L, LUAOC_INSTANCE_METATABLE_NAME);
  luaL_setfuncs(L, metaFunctions, 0);

  lua_pushstring(L, "__type");
  lua_pushinteger(L, luaoc_instance_type);
  lua_rawset(L, -3);                        // meta.type = "id"

  {
    lua_pushstring(L, "loaded");

    lua_newtable(L);

    lua_newtable(L);
    lua_pushstring(L, "__mode");              // use weak table, so loaded value can be recycle
    lua_pushstring(L, "v");
    lua_rawset(L, -3);                        // :meta "loaded" {} {__mode="v"}

    lua_setmetatable(L, -2);                  // :meta "loaded" {}

    lua_rawset(L, -3);                        // meta.loaded = {} : meta
  }

  lua_pushboolean(L, 1);

  LUA_POP_STACK(L, 1);
  return 1;
}

