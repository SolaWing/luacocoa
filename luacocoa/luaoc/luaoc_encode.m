//
//  luaoc_encode.m
//  luaoc
//
//  Created by SolaWing on 15/9/14.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_encode.h"
#import "lauxlib.h"
#import <CoreGraphics/CoreGraphics.h>

#import "luaoc_helper.h"

#import "luaoc_struct.h"

#define ENCODING_TABLE "oc.encoding"

#pragma mark - LUA INTERFACE
static int encoding_of_name(lua_State *L){
  lua_pushcfunction(L, luaoc_encoding_of_named_struct);
  lua_pushvalue(L, 2);
  lua_call(L, 1, 1);
  return 1;
}

/** pass in args are type names, concat each type encodings */
static int encoding_of_types(lua_State *L) {
    luaL_Buffer buf;
    luaL_buffinit(L, &buf);
    int top = lua_gettop(L);
    for (int i = 2; i <= top; ++i) {
        lua_pushvalue(L, i);
        if (lua_gettable(L, 1) == LUA_TSTRING) {
            luaL_addvalue(&buf);
        } else {
            LUAOC_ARGERROR(i, "cant found encoding for type at index");
        }
    }
    luaL_pushresult(&buf);
    return 1;
}

void luaoc_push_encoding_for_index(lua_State *L, int index) {
    int type = lua_type(L, index);
    if (type == LUA_TSTRING) { lua_pushvalue(L, index); return; }
    if (type == LUA_TTABLE) {
        luaL_Buffer buf;
        luaL_buffinit(L, &buf);

        index = lua_absindex(L, index);
        size_t len = lua_rawlen(L, index);

        lua_rawgetfield(L, LUA_REGISTRYINDEX, ENCODING_TABLE);
        for (size_t i = 1; i <= len; ++i) {
          lua_geti(L, index, i);
          type = lua_gettable(L, -2);
          LUAOC_ASSERT(type == LUA_TSTRING);
          luaL_addvalue(&buf);
        }
        lua_pop(L,1); // pop ENCODING_TABLE
        luaL_pushresult(&buf);
    } else {
        lua_pushnil(L); return;
    }
}

static const luaL_Reg encodingFuncs[] = {
  {"__index", encoding_of_name},
  {"__call",  encoding_of_types},
  {NULL,      NULL},
};

int luaopen_luaoc_encoding(lua_State *L) {
  luaL_newlib(L, encodingFuncs);
  lua_pushvalue(L, -1);
  lua_setmetatable(L, -2); // set self as metaTable
  lua_pushvalue(L, -1);
  lua_rawsetfield(L, LUA_REGISTRYINDEX, ENCODING_TABLE);

#define SET_ENCODING_OF_TYPE(name, type)                \
  lua_pushstring(L, name);                              \
  lua_pushstring(L, @encode(type));                     \
  lua_rawset(L, -3);                                    \

  SET_ENCODING_OF_TYPE("bool",               bool               );
  SET_ENCODING_OF_TYPE("char",               char               );
  SET_ENCODING_OF_TYPE("unsigned char",      unsigned char      );
  SET_ENCODING_OF_TYPE("short",              short              );
  SET_ENCODING_OF_TYPE("unsigned short",     unsigned short     );
  SET_ENCODING_OF_TYPE("int",                int                );
  SET_ENCODING_OF_TYPE("unsigned int",       unsigned int       );
  SET_ENCODING_OF_TYPE("long",               long               );
  SET_ENCODING_OF_TYPE("unsigned long",      unsigned long      );
  SET_ENCODING_OF_TYPE("long long",          long long          );
  SET_ENCODING_OF_TYPE("unsigned long long", unsigned long long );
  SET_ENCODING_OF_TYPE("float",              float              );
  SET_ENCODING_OF_TYPE("double",             double             );
  SET_ENCODING_OF_TYPE("size_t",             size_t             );
  SET_ENCODING_OF_TYPE("BOOL",               BOOL               );
  SET_ENCODING_OF_TYPE("NSInteger",          NSInteger          );
  SET_ENCODING_OF_TYPE("NSUInteger",         NSUInteger         );
  SET_ENCODING_OF_TYPE("CGFloat",            CGFloat            );
  SET_ENCODING_OF_TYPE("UInt8",              UInt8              );
  SET_ENCODING_OF_TYPE("SInt8",              SInt8              );
  SET_ENCODING_OF_TYPE("UInt16",             UInt16             );
  SET_ENCODING_OF_TYPE("SInt16",             SInt16             );
  SET_ENCODING_OF_TYPE("UInt32",             UInt32             );
  SET_ENCODING_OF_TYPE("SInt32",             SInt32             );
  SET_ENCODING_OF_TYPE("UInt64",             UInt64             );
  SET_ENCODING_OF_TYPE("SInt64",             SInt64             );
  SET_ENCODING_OF_TYPE("id",                 id                 );
  SET_ENCODING_OF_TYPE("Class",              Class              );
  SET_ENCODING_OF_TYPE("SEL",                SEL                );
  SET_ENCODING_OF_TYPE("void",               void               );
  SET_ENCODING_OF_TYPE("pointer",            void*              );
  SET_ENCODING_OF_TYPE("ptr",                void*              );
  SET_ENCODING_OF_TYPE("str",                char*              );
  SET_ENCODING_OF_TYPE("string",             char*              );
  SET_ENCODING_OF_TYPE("Block",              dispatch_block_t   );

  return 1;
}

