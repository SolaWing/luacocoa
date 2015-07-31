//
//  luaoc.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc.h"
#import "luaoc_class.h"
#import "lualib.h"
#import "lauxlib.h"
#import "luaoc_instance.h"
#import "luaoc_struct.h"

lua_State *gLua_main_state = NULL;

lua_State* luaoc_setup(){
  lua_State *L = luaL_newstate();
  gLua_main_state = L;

  luaL_openlibs(L);

  luaL_requiref(L, "oc", luaopen_luaoc, true);

  lua_settop(L, 0);

  // TODO: create a dedicated queue, to prevent lua code run at other thread

  return L;
}

void luaoc_close() {
  if (gLua_main_state) {
    lua_close(gLua_main_state);
    gLua_main_state = NULL;
  }
}

int luaopen_luaoc(lua_State *L){
  lua_newtable(L);

  luaopen_luaoc_class(L);
  lua_setfield(L, -2, "class");

  luaopen_luaoc_instance(L);
  lua_pop(L, 1);

  luaopen_luaoc_struct(L);
  lua_setfield(L, -2, "struct");

  return 1;
}
