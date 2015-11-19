//
//  luaoc_instance.m
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "lua.h"
#import "lauxlib.h"

#import "luaoc_helper.h"

#import "luaoc_instance.h"
#import "luaoc_class.h"
#import "luaoc.h"

#define LOADED_INSTANCE_TABLE "oc.loadedObj"
#define LOADED_INSTANCE_ENV_TABLE "oc.loadedObjENV"

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

  lua_rawgetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_TABLE); // :meta loaded

  /** userdata table can be collect and release when gc.
   *  id associate uservalue bind life circle with id */
  if (lua_rawgetp(L, -1, v) == LUA_TNIL){
    // bind new ud
    *(id*)lua_newuserdata(L, sizeof(id)) = v;

    lua_pushvalue(L, LUA_START_INDEX(L)+1);
    lua_setmetatable(L, -2);                            // + ud ; set ud meta

    lua_rawgetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_ENV_TABLE);
    // when lua not need obj, may gc userdata. but instance still alive and can be reuse
    if (lua_rawgetp(L, -1, v) == LUA_TNIL){
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_rawsetp(L, -4, v);  // env[p] = uv, : ... ud env nil uv
    }
    // don't retain stack block, release later will crash. may autoconvert to heap?
    if ( object_getClass(v) != (Class)&_NSConcreteStackBlock )
    {
        lua_pushinteger(L, 1);
        lua_rawsetfield(L, -2, "__retainCount");
        [v retain];                                         // retain when create and release in gc
    }
    lua_setuservalue(L, LUA_START_INDEX(L)+4);          // ; set ud uservalue

    lua_settop(L, LUA_START_INDEX(L)+4);                // : meta loaded nil ud

    lua_pushvalue(L, -1);                               // copy ud
    lua_rawsetp(L, LUA_START_INDEX(L)+2, v);            // loaded[p] = ud

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

int luaoc_retain(lua_State *L){
    LUAOC_RETAIN(L, 1);
    lua_pushvalue(L, 1);

    return 1; // return pass in obj
}

int luaoc_release(lua_State *L){
    LUAOC_RELEASE(L, 1);
    return 0;
}

int luaoc_super(lua_State *L) {
    Class cls = NULL;
    switch( lua_type(L, 2) ) {
        case LUA_TUSERDATA: {
            cls = luaL_testudata(L, 2, LUAOC_CLASS_METATABLE_NAME);
            break;
        }
        case LUA_TSTRING: {
            cls = objc_getClass(lua_tostring(L, 2));
            break;
        }
        default: { break; }
    }
    luaoc_push_super(L, 1, cls);
    return 1;
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

static int __tostring(lua_State *L) {
    id* ud = (id*)lua_touserdata(L, 1);
    if (ud)
    {
        lua_pushstring(L, [*ud description].UTF8String);
    }
    else
    {
        lua_pushnil(L);
    }
    return 1;
}

static int __len(lua_State *L) {
    id* ud = (id*)lua_touserdata(L,1);
    LUAOC_ASSERT(ud);
    if ([*ud respondsToSelector: @selector(count)]){
        lua_pushinteger(L, [*ud count]);
    } else if ([*ud respondsToSelector: @selector(length)]) {
        lua_pushinteger(L, [*ud length]);
    } else {
        DLOG("unsupported get length for %s", class_getName([*ud class]));
        lua_pushnil(L);
    }
    return 1;
}
static int __gc(lua_State *L){
  id* ud = luaL_testudata(L, 1, LUAOC_INSTANCE_METATABLE_NAME);
  if (ud) {
      // get lua retain count. release it in gc
      lua_getuservalue(L, 1);
      if (lua_rawgetfield(L, -1, "__retainCount") == LUA_TNUMBER &&
          lua_tointeger(L, -1) > 0)
      {
          /** NOTE: release a already dealloced obj will crash.
           *  though set dealloc callback and clear retainCount, but for async,
           *  also may enter this before clear, and crash */
          [*ud release];

          lua_pushnil(L);
          lua_rawsetfield(L, -3, "__retainCount");
      }
  }

  return 0;
}

static void _lua_release_id_ptr(void* objPtr) {
    if (!gLua_main_state) return;
    lua_State*const L = gLua_main_state;
    int top = lua_gettop(L);
    lua_rawgetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_ENV_TABLE);
    if (lua_rawgetp(L, -1, objPtr) != LUA_TNIL) { // has uservalue
        lua_pushnil(L);
        lua_rawsetfield(L, -2, "__retainCount"); // clear retainCount

        lua_pushnil(L);                         // env uv nil
        lua_rawsetp(L, -3, objPtr);             // clear uservalue strong ref

        lua_rawgetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_TABLE);
        lua_pushnil(L);
        lua_rawsetp(L, -2, objPtr);             // clear loaded cache userdata
    }
    lua_settop(L, top);
}

static inline void lua_release_id_ptr(void* objPtr) {
    if ([NSThread isMainThread]) {
        _lua_release_id_ptr(objPtr);
    } else {
        // FIXME sync may deadlock, async value may be used before call
        dispatch_async(dispatch_get_main_queue(), ^{
            lua_release_id_ptr(objPtr);
        });
    }
}

// TODO: other meta funcs
static const luaL_Reg metaFunctions[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {"__tostring", __tostring},
  {"__len", __len},
  // {"__pairs", __tostring},
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
    lua_newtable(L);

    lua_newtable(L);
    lua_pushstring(L, "__mode");              // use weak table, so loaded value can be recycle
    lua_pushstring(L, "v");
    lua_rawset(L, -3);                        // :meta {} {__mode="v"}

    lua_setmetatable(L, -2);                  // :meta {}

    lua_rawsetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_TABLE); //  :meta

    lua_newtable(L);
    // env table to hold uservalue of instance, and bind life circle to oc
    // object circle
    lua_rawsetfield(L, LUA_REGISTRYINDEX, LOADED_INSTANCE_ENV_TABLE);

    static IMP oldDealloc = NULL;
    if (!oldDealloc) { // replace NSObject dealloc method so when object dealloc, can get notification
        // when sync call other thread, dealloc at other thread and redispatch
        // to main may cause deadlock
        oldDealloc = class_replaceMethod([NSObject class], @selector(dealloc),
                imp_implementationWithBlock(^(id self)
        {
            ((void(*)(id,SEL))oldDealloc)(self, @selector(dealloc));
            lua_release_id_ptr(self);
        }), "v@:");
    }
  }

  lua_pushboolean(L, 1);

  LUA_POP_STACK(L, 1);
  return 1;
}

