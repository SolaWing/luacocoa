//
//  luaoc_class.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_class.h"
#import "lua.h"
#import "lauxlib.h"
#import "luaoc_helper.h"

#import <objc/runtime.h>
#import <string.h>

void luaoc_push_class(lua_State *L, Class cls) {
  if (NULL == cls) {
    lua_pushnil(L);
    return;
  }

  LUA_PUSH_STACK(L);
  if (!luaL_getmetatable(L, LUAOC_CLASS_METATABLE_NAME)) {
    // no meta table, there is some wrong , or call this method when not open
    DLOG("ERROR: can't get metaTable, do you open oc lib?");
    LUA_POP_STACK(L, 1);
    return;
  }

  lua_pushstring(L, "loaded");
  lua_rawget(L, -2);                                // : meta loaded

  if (lua_rawgetp(L, -1, cls) == LUA_TNIL){ // no obj, bind new
    *(Class*)(lua_newuserdata(L, sizeof(Class))) = cls;
    lua_pushvalue(L, LUA_START_INDEX(L)+1);
    lua_setmetatable(L, -2);                        // + ud ; set ud meta

    lua_newtable(L);
    lua_setuservalue(L, -2);                        // ; set ud uservalue a newtable

    lua_pushvalue(L, -1);
    lua_rawsetp(L, LUA_START_INDEX(L)+2, cls);      // loaded[p] = ud
  }

  LUA_POP_STACK(L, 1);  // keep ud at the top
}

Class luaoc_toclass(lua_State *L, int index) {
  Class* ud = (Class*)luaL_testudata(L, index, LUAOC_CLASS_METATABLE_NAME);
  if (NULL == ud) return NULL;
  return *ud;
}

#pragma mark - class search table
static int indexClassByName(lua_State *L){
  const char *className = luaL_checkstring(L, 2);
  Class cls = objc_getClass(className);
  if (cls) {
    luaoc_push_class(L, cls);
  }else {
    DLOG("unknown class name: '%s', "
         "did you spell correct or link the relevant framework?", className);
    lua_pushnil(L);
  }
  return 1;
}

static int newClass(lua_State *L){
  // TODO: newClass
  return 1;
}

static int name(lua_State *L){
  if (lua_getmetatable(L, 1)) {
    lua_pushstring(L, "__type");
    if (lua_rawget(L, -2) == LUA_TNUMBER) {
      switch( lua_tointeger(L, -1) ){
        case luaoc_class_type: {
          lua_pushstring(L, class_getName(*(Class*)(lua_touserdata(L, 1))));
          return 1;
        }
        case luaoc_instance_type: { // 对于聚合类, 实例的类可能不是聚合类名
          lua_pushstring(L, object_getClassName(*(id*)(lua_touserdata(L,1))));
          return 1;
        }
        case luaoc_super_type: {
          lua_pushstring(L, class_getName(*(((Class*)lua_touserdata(L, 1)) + 1) ));
          return 1;
        }
        default: {
          break;
        }
      }
    }
  }
  lua_pushnil(L);
  return 1;
}

static const luaL_Reg ClassTableMetaMethods[] = {

  {"__index", indexClassByName},
  {"__call", newClass},
  {NULL, NULL}
};

static const luaL_Reg ClassTableMethods[] = {
  {"name", name},
  {NULL, NULL}
};

#pragma mark - class lua convert
static int __index(lua_State *L){
  luaL_checkudata(L, 1, LUAOC_CLASS_METATABLE_NAME);

  lua_getuservalue(L, 1);
  lua_pushvalue(L, 2); // : ud key udv key
  // is nil and key is string , return message wrapper
  if (lua_rawget(L, -2) == LUA_TNIL && lua_type(L,2) == LUA_TSTRING) {
    lua_pushvalue(L,2);
    lua_pushcclosure(L, luaoc_msg_send, 1);
  }

  return 1;
}

static int __newindex(lua_State *L){
  luaL_checkudata(L, 1, LUAOC_CLASS_METATABLE_NAME);
  if (lua_type(L, 3) == LUA_TFUNCTION){
    // TODO: override func
  }

  lua_getuservalue(L, 1);
  lua_insert(L, 2);
  lua_rawset(L, 2);                         // udv[key] = value

  return 0;
}

static const luaL_Reg metaMethods[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {NULL, NULL}
};

int luaopen_luaoc_class(lua_State *L) {
  luaL_newlib(L, ClassTableMethods);
  luaL_newlib(L, ClassTableMetaMethods);
  lua_setmetatable(L, -2);                          // : clsTable

  // class's meta table
  luaL_newmetatable(L, LUAOC_CLASS_METATABLE_NAME);
  luaL_setfuncs(L, metaMethods, 0);                 // + classMetaTable

  lua_pushstring(L, "__type");
  lua_pushinteger(L, luaoc_class_type);
  lua_rawset(L, -3);                                // classMetaTable.type = "class"

  // a new loaded table hold all class pointer to lua repr
  lua_pushstring(L, "loaded");
  lua_newtable(L);
  lua_rawset(L, -3);                                // classMetaTable.loaded = {}

  lua_pop(L, 1);                                    // : clsTable

  return 1;
}

