//
//  luaoc_var.m
//  luaoc
//
//  Created by SolaWing on 15/8/3.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_var.h"
#import "luaoc_helper.h"
#import "lauxlib.h"
#import "luaoc_struct.h"

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

void luaoc_push_var(lua_State *L, const char* typeDescription, void* initRef) {
  NSCParameterAssert(typeDescription);

  char *structName = NULL;
  const char *endPos;
  NSUInteger size = luaoc_get_one_typesize(typeDescription, &endPos, &structName);

  if ( unlikely( size == 0 )) {
      DLOG( "empty var size!!" );
      lua_pushnil( L );
      return;
  }

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

  free(structName); // : ud
}

static const luaL_Reg varFuncs[] = {
  {NULL, NULL},
};

static int create_var(lua_State *L){
  const char* typeDescription = luaL_checkstring(L, 2);
  if (lua_isnoneornil(L, 3)) luaoc_push_var(L, typeDescription, NULL);
  else {
    void* v = luaoc_copy_toobjc(L, 3, typeDescription, NULL);
    luaoc_push_var(L, typeDescription, v);
    free(v);
  }
  return 1;
}

static const luaL_Reg varMetaFuncs[] = {
  {"__call", create_var},
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
  {"__index",    __index},
  {"__newindex", __newindex},
  {NULL,         NULL},
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

#pragma mark - encoding
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

static const luaL_Reg encodingFuncs[] = {
  {"__index", encoding_of_name},
  {"__call",  encoding_of_types},
  {NULL,      NULL},
};

int luaopen_luaoc_encoding(lua_State *L) {
  luaL_newlib(L, encodingFuncs);
  lua_pushvalue(L, -1);
  lua_setmetatable(L, -2); // set self as metaTable

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

