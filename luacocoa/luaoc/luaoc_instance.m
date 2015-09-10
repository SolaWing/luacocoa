//
//  luaoc_instance.m
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "luaoc_instance.h"
#import "lua.h"
#import "lauxlib.h"
#import "luaoc_helper.h"
#import "luaoc_class.h"

#import <objc/runtime.h>

void luaoc_push_instance(lua_State *L, id v){
  if (NULL == v){
    lua_pushnil(L); return;
  }

  LUA_PUSH_STACK(L);
  if (!luaL_getmetatable(L, LUAOC_INSTANCE_METATABLE_NAME)){
    // no meta table, there is some wrong , or call this method when not open
    DLOG("ERROR: can't get metaTable");
    LUA_POP_STACK(L, 1);
    return;
  }

  lua_pushstring(L, "loaded");
  lua_rawget(L, -2);                            // :meta loaded

  // TODO: should check if the obj is in deallocing! don't use it in gc after deallocing
  // deallocing obj can call lua when :
  //    lua override deallocing
  //    lua callback or msg when some obj deallocing
  //    
  // loaded table need cleanup immediately. because index pointer may be reuse
  // by other data.
  if (lua_rawgetp(L, -1, v) == LUA_TNIL){
    // bind new ud
    *(id*)lua_newuserdata(L, sizeof(id)) = v;

    lua_pushvalue(L, LUA_START_INDEX(L)+1);
    lua_setmetatable(L, -2);                            // + ud ; set ud meta

    lua_newtable(L);
    lua_setuservalue(L, -2);                            // ; set ud uservalue a newtable

    lua_pushvalue(L, -1);                               // copy ud
    lua_rawsetp(L, LUA_START_INDEX(L)+2, v);            // loaded[p] = ud

    // now don't auto retain the obj.
    // if the retained obj is in deallocing, it's always be free after
    // deallocing. and thus release in gc cause bad_acesss.
    // [v retain];                                         // retain when create and release in gc
  }
  LUA_POP_STACK(L, 1);
}

void luaoc_push_super(lua_State *L, int index, Class cls) {
  LUA_PUSH_STACK(L);

  index = lua_absindex(L, index);

  id* ud = (id*)lua_touserdata(L, index);
  if ( NULL == cls && luaL_getmetafield(L, index, "__type") == LUA_TNUMBER){
    LUA_INTEGER tt = lua_tointeger(L, -1);
    if (tt == luaoc_instance_type) cls = object_getClass(*ud);
    else if (tt == luaoc_super_type) cls = *(ud+1);
  }
  if (unlikely(NULL == cls)){
    DLOG("ERROR: invalid instance type!");
    lua_pushnil(L);
    LUA_POP_STACK(L, 1);
    return;
  }

  cls = class_getSuperclass(cls);
  if (unlikely(NULL == cls)){
    lua_pushnil(L);
    LUA_POP_STACK(L, 1);
    return;
  }

  id* su = (id*)lua_newuserdata(L, sizeof(id)*2);
  su[0] = *ud, su[1] = cls;

  luaL_getmetatable(L, LUAOC_SUPER_METATABLE_NAME);
  lua_setmetatable(L, -2);

  // use same uservalue
  lua_getuservalue(L, index);
  lua_setuservalue(L, -2);

  // [*ud retain]; // retain it and release it in gc

  LUA_POP_STACK(L, 1); // + su
}

id luaoc_toinstance(lua_State *L, int index) {
  id* ud = (id*)lua_touserdata(L, index);
  if (ud && luaL_getmetafield(L, index, "__type") != LUA_TNIL){
    LUA_INTEGER tt = lua_tointeger(L, -1); lua_pop(L, 1);

    if (tt == luaoc_instance_type || tt == luaoc_super_type) {
      return *ud;
    }
  }

  return NULL;
}

LUA_INTEGER luaoc_change_lua_retain_count(lua_State *L, int index, LUA_INTEGER change) {
    lua_getuservalue(L, index);
    LUA_INTEGER count = 0;
    if (lua_rawgetfield(L, -1, "__retainCount") == LUA_TNUMBER) {
        count = lua_tointeger(L, -1);
    }
    count = count + change;
    if (count < 1) lua_pushnil(L);
    else lua_pushinteger(L, count);
    lua_rawsetfield(L, -3, "__retainCount");

    lua_pop(L, 2); // - uv, __retainCount

    return count;
}

#pragma mark - Meta Funcs
static int __index(lua_State *L){
  id* ud = (id*)lua_touserdata(L, 1);
  if ( unlikely( !ud )) LUAOC_ARGERROR( 1, "index obj should be userdata" );
  // FIXME may need to check userdata type

  lua_getuservalue(L, 1);
  lua_pushvalue(L, 2); // : ud key udv key
  if (lua_rawget(L, -2) == LUA_TNIL) {
    if (lua_type(L,2) == LUA_TSTRING) {
      const char* key = lua_tostring(L, 2);
      SEL sel = luaoc_find_SEL_byname(*ud, key);
      if (sel){
          luaoc_push_msg_send(L, sel);
      }
    }
    if (lua_isnil(L, -1)){
      // when not a oc msg, try to find lua value in cls
      index_value_from_class(L, [*ud class], 2);
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
  id* ud = luaL_testudata(L, 1, LUAOC_INSTANCE_METATABLE_NAME);
  if (ud) {
      // get lua retain count. release it in gc
      lua_getuservalue(L, 1);
      if (lua_rawgetfield(L, -1, "__retainCount") == LUA_TNUMBER &&
          lua_tointeger(L, -1) > 0)
      {
          /** NOTE: when lua retain a deallocing obj. the gc call normally after
           * freeing the deallocing obj. this will cause bad_acesss.
           *
           * the deallocing obj will call lua code by dealloc method or other
           * callback, msg etc. user should ensure when dealloc return, lua is no
           * retainCount left */
          [*ud release];
      }
  }
  // else is super type

  return 0;
}

// TODO: other meta funcs
static int __add(lua_State *L){
  return 1;
}

static const luaL_Reg metaFunctions[] = {
  {"__index", __index},
  {"__newindex", __newindex},
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

  lua_pushcfunction(L, __gc);
  lua_rawsetfield(L, -2, "__gc");
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

