//
//  luaoc_helper.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_helper.h"
#import "luaoc_class.h"
#import "luaoc_instance.h"
#import "luaoc_struct.h"

#import "lauxlib.h"

int luaoc_msg_send(lua_State* L){
  int top = lua_gettop(L);

  id* ud = (id*)lua_touserdata(L, 1);

  if (!ud) { luaL_argerror(L, 1, "msg send must be objc object!"); }
  if (luaL_getmetafield(L, 1, "__type") != LUA_TNUMBER) {
    luaL_error(L, "can't found metaTable!");
  }


  const char* msg = lua_tostring(L, lua_upvalueindex(1));
  return 1;
}

#pragma mark - DEBUG
void luaoc_print(lua_State* L, int index) {
  switch( lua_type(L, index) ){
    case LUA_TNIL: {
      printf("nil");
      break;
    }
    case LUA_TNUMBER: {
      printf("%lf", lua_tonumber(L, index));
      break;
    }
    case LUA_TBOOLEAN: {
      printf(lua_toboolean(L, index) ? "true":"false");
      break;
    }
    case LUA_TSTRING: {
      printf("%s", lua_tostring(L, index));
      break;
    }
    case LUA_TTABLE: {
      luaoc_print_table(L, index);
      break;
    }
    case LUA_TFUNCTION: {
      printf("function(%p)", lua_topointer(L, index));
      break;
    }
    case LUA_TUSERDATA: {
      printf("userdata(%p)", lua_touserdata(L, index));
      break;
    }
    case LUA_TLIGHTUSERDATA: {
      printf("pointer(%p)", lua_touserdata(L, index));
      break;
    }
    case LUA_TTHREAD: {
      printf("thread(%p)", lua_topointer(L, index));
      break;
    }
    case LUA_TNONE:
    default: {
      printf("invalid index\n");
      break;
    }
  }
}

void luaoc_print_table(lua_State* L, int index) {
  if (lua_type(L, index) == LUA_TTABLE) {
    int top = lua_gettop(L);
    if (index < 0) index = top + index + 1;

    printf("table(%p):{\n", lua_topointer(L, index));
    lua_pushnil(L);
    while(lua_next(L, index) != 0) {
      printf("\t");
      luaoc_print(L, -2);
      printf("\t:\t");
      luaoc_print(L, -1);
      printf("\n");

      lua_pop(L, 1);
    }
    printf("}");

  } else{
    printf("print not table\n");
  }
}

void luaoc_dump_stack(lua_State* L) {
  int top = lua_gettop(L);
  for (int i = 1; i<=top; ++i){
    printf("stack %d:\n", i);
    luaoc_print(L, i);
    printf("\n");
  }
}

