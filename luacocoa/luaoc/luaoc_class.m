//
//  luaoc_class.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "luaoc_class.h"
#import "lua.h"
#import "lauxlib.h"
#import "luaoc_helper.h"

#import <objc/runtime.h>

void luaoc_push_class(lua_State *L, Class cls) {
  PUSH_LUA_STACK(L);
  if (!luaL_getmetatable(L, LUAOC_CLASS_METATABLE_NAME)) {
    // no meta table, there is some wrong , or call this method when not open
    NSLog(@"ERROR: %s: can't get metaTable", __FUNCTION__);
    POP_LUA_STACK(L, 1);
    return;
  }

  lua_pushstring(L, "loaded");
  lua_rawget(L, -2);                                // : meta loaded

  if (lua_rawgetp(L, -1, cls) == LUA_TNIL){ // no obj, bind new
    *(Class*)(lua_newuserdata(L, sizeof(void*))) = cls;
    lua_pushvalue(L, LUA_START_INDEX(L)+1);
    lua_setmetatable(L, -2);                        // + ud ; set ud meta

    lua_newtable(L);
    lua_setuservalue(L, -2);                        // ; set ud uservalue a newtable

    lua_pushvalue(L, -1);
    lua_rawsetp(L, LUA_START_INDEX(L)+2, cls);      // loaded[p] = ud
  }

  POP_LUA_STACK(L, 1);  // keep ud at the top
}

#pragma mark - class search table
static int indexClassByName(lua_State *L){
  const char *className = luaL_checkstring(L, 2);
  Class cls = objc_getClass(className);
  if (cls) {
    luaoc_push_class(L, cls);
  }else {
    lua_pushnil(L);
  }
  return 1;
}

static int newClass(lua_State *L){
  return 1;
}

static int name(lua_State *L){
  if (lua_getmetatable(L, 1)) {
    lua_pushstring(L, "type");
    lua_rawget(L, -2);
    const char* type = lua_tostring(L, -1);
    if (type){
      if (strcmp(type, "class") == 0) {
        lua_pushstring(L, class_getName(*(Class*)(lua_touserdata(L, 1))));
        return 1;
      }
      else if (strcmp(type, "id") == 0) {
        lua_pushstring(L, object_getClassName(*(id*)(lua_touserdata(L,1))));
        return 1;
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
  return 1;
}

static int __newindex(lua_State *L){
  return 1;
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

  lua_pushstring(L, "type");
  lua_pushstring(L, "class");
  lua_rawset(L, -3);                                // classMetaTable.type = "class"

  // a new loaded table hold all class pointer to lua repr
  lua_pushstring(L, "loaded");
  lua_newtable(L);
  lua_rawset(L, -3);                                // classMetaTable.loaded = {}

  lua_pop(L, 1);                                    // : clsTable

  return 1;
}

