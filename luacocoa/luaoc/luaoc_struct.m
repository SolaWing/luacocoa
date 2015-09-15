//
//  luaoc_struct.m
//  luaoc
//
//  Created by SolaWing on 15/7/29.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_struct.h"
#import "lauxlib.h"

#import <stdlib.h>
#import <string.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    #import <UIKit/UIKit.h>
#else
#endif

#import "luaoc_helper.h"

/// table use to find offset by name {struct_name = {name = offset, ...}, ...}
#define NAMED_STRUCT_TABLE_NAME "named_struct"
typedef struct struct_attr_info {
  int offset;
  const char* encoding;
}struct_attr_info;

void luaoc_push_struct(lua_State *L, const char* typeDescription, void* structRef) {
  char *structName = NULL;
  const char *endPos;
  NSUInteger size = luaoc_get_one_typesize(typeDescription, &endPos, &structName);

  if ( unlikely( size == 0 )) {
      DLOG( "empty struct size!!" );
      lua_pushnil( L );
      return;
  }

  void* ud = lua_newuserdata(L, size);
  if (structRef) memcpy(ud, structRef, size);
  else memset(ud, 0, size);

  luaL_getmetatable(L, LUAOC_STRUCT_METATABLE_NAME);
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

  free(structName);
}

int luaoc_tostruct(lua_State *L, int index, void* outStructRef) {
  return luaoc_tostruct_n(L, index, outStructRef, INT_MAX);
}

int luaoc_tostruct_n(lua_State *L, int index, void* outStructRef, size_t n) {
  NSCParameterAssert(outStructRef);

  void* ud = luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
  if (NULL == ud) return false;

  size_t size = lua_rawlen(L, index);
  if (n < size) return false;

  memcpy(outStructRef, ud, size);
  return true;
}

void* luaoc_copystruct(lua_State *L, int index, size_t* outSize) {
  void* ud = luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
  if (NULL == ud) return false;

  size_t size = lua_rawlen(L, index);
  if (outSize) *outSize = size;

  void* ret = malloc(size);
  memcpy(ret, ud, size);

  return ret;
}

void* luaoc_getstruct(lua_State *L, int index) {
  return luaL_testudata(L, index, LUAOC_STRUCT_METATABLE_NAME);
}

int luaoc_struct_offset_by_index(const char* encoding, int index, const char** outEncoding) {
    // here not check struct encoding has {} pair
    encoding = strchr(encoding, '=');
    if (unlikely(!encoding)) return -2;
    ++encoding;

    if (index == 0) {
        if (outEncoding) *outEncoding = encoding;
        return 0; // offset 0 don't need to compute
    }


    NSUInteger attrOffset = 0;
    NSUInteger align;
    NSUInteger typesize;
    const char* nextEncoding;
    while (*encoding) {
        nextEncoding = NSGetSizeAndAlignment(encoding, &typesize, &align);

        luaoc_align_offset(&attrOffset, align);

        if (index > 0) {
            attrOffset += typesize;
            encoding = nextEncoding;
            --index;
        } else {
            if (outEncoding) *outEncoding = encoding;
            return (int)attrOffset;
        }
    }
    DLOG("get struct offset overflow!");
    return -1; // overflow!
}

int luaoc_struct_offset_by_key(lua_State *L, const char** outEncoding) {
    int top = lua_gettop(L);
    luaL_getmetatable(L, NAMED_STRUCT_TABLE_NAME);
    lua_pushvalue(L, -3);
    if (lua_rawget(L, -2) == LUA_TNIL) { // named_struct[name]
        DLOG("index unreg struct");
        lua_settop(L, top -2);
        return -2;
    }

    lua_pushvalue(L, -3); // push key
    if (lua_rawget(L, -2) == LUA_TUSERDATA) {
        struct_attr_info* info = lua_touserdata(L, -1);
        lua_settop(L, top-2);
        if (outEncoding) {
            *outEncoding = info->encoding;
        }
        return info->offset;
    }
    DLOG("invalid struct key");
    lua_settop(L, top-2);
    return -1;
}

int luaoc_encoding_of_named_struct(lua_State *L) {
  luaL_getmetatable(L, NAMED_STRUCT_TABLE_NAME);
  lua_pushvalue(L, 1); // structName
  if (lua_rawget(L, -2) != LUA_TNIL){
    lua_rawgetfield(L, -1, "__encoding");
  }
  return 1;
}

static int __index(lua_State *L){
  luaL_checktype(L, 1, LUA_TUSERDATA);

  lua_getuservalue(L, 1);       // uv
  lua_pushvalue(L, 2);
  if (lua_rawget(L, -2) == LUA_TNIL) { // uv nil
    const char* encoding;
    int attrOffset;
    if ( lua_isinteger(L, 2) ) {
      LUA_INTEGER index = lua_tointeger(L, 2); // begin from 1
      lua_rawgetfield(L, -2, "__encoding");
      encoding = lua_tostring(L, -1);

      attrOffset = luaoc_struct_offset_by_index(
              encoding, (int)index-1, &encoding);
      if (attrOffset < 0) {
          LUAOC_ERROR("invalid struct index or encoding");
      } else {
          luaoc_push_obj(L, encoding, lua_touserdata(L, 1) + attrOffset);
      }
    } else { // index by keyname
      lua_rawgetfield(L, -2, "__name");     // uv[__name]
      lua_pushvalue(L, 2);

      attrOffset = luaoc_struct_offset_by_key(L, &encoding);
      if (attrOffset < 0) {
          lua_pushnil(L);
      } else {
          luaoc_push_obj(L, encoding, lua_touserdata(L, 1) + attrOffset);
      }
    }
  }

  return 1;
}

static int __newindex(lua_State *L){
  luaL_checktype(L, 1, LUA_TUSERDATA);
  lua_getuservalue(L, 1);

  const char * encoding;
  int attrOffset;
  if ( lua_isinteger(L, 2) ) {
      LUA_INTEGER index = lua_tointeger(L, 2); // begin from 1
      lua_rawgetfield(L, -1, "__encoding");
      encoding = lua_tostring(L, -1);

      attrOffset =
          luaoc_struct_offset_by_index(encoding, (int)index-1, &encoding);
      if (attrOffset < 0) {
          LUAOC_ERROR("invalid struct index or encoding");
      }
  } else {
      lua_rawgetfield(L, -1, "__name");     // uv[__name]
      lua_pushvalue(L, 2);

      attrOffset = luaoc_struct_offset_by_key(L, &encoding);
  }
  if (attrOffset >= 0) {
      size_t outSize;
      void* v = luaoc_copy_toobjc(L, 3, encoding, &outSize);
      memcpy(lua_touserdata(L,1)+attrOffset, v, outSize);
      free(v);
      return 0;
  }

  // otherwise, set key in uservalue
  lua_settop(L, 4); // ud key val uv
  lua_insert(L, 2);
  lua_rawset(L, 2);                         // udv[key] = value

  return 0;
}

static int __len(lua_State *L){
  lua_pushinteger(L, lua_rawlen(L, 1));
  return 1;
}

/** first is name, after is {name, type} pair ... */
static int reg_struct(lua_State *L){
  size_t structNameLen;
  const char* structName = luaL_checklstring(L, 1, &structNameLen);
  int top = lua_gettop(L);

  luaL_getmetatable(L, NAMED_STRUCT_TABLE_NAME);
  lua_pushvalue(L, 1); // structName
  if (lua_rawget(L, -2) == LUA_TNIL){
    lua_pop(L, 1);
    lua_newtable(L);

    lua_pushvalue(L, 1);
    lua_pushvalue(L, -2);
    lua_rawset(L, -4); // mt[name] = structTable
  }
  // : mt structTable
  luaL_Buffer encodingBuf;
  luaL_buffinit(L, &encodingBuf);
  luaL_addchar(&encodingBuf, '{');
  luaL_addlstring(&encodingBuf, structName, structNameLen);
  luaL_addchar(&encodingBuf, '='); {
    NSUInteger offset = 0;
    for (int i = 2; i <= top; ++i){
      lua_geti(L, i, 2); // type encoding
      lua_geti(L, i, 1); // name
      struct_attr_info* sai = lua_newuserdata(L, sizeof(struct_attr_info));

      size_t encodingLen;
      sai->encoding = luaL_checklstring(L, -3, &encodingLen);

      NSUInteger typesize, align;
      // TODO user invalid encoding may cause error, catch and convert to lua error
      NSGetSizeAndAlignment(sai->encoding, &typesize, &align);
      luaoc_align_offset(&offset, align);
      sai->offset = (int)offset;

      offset += typesize;
      lua_rawset(L, -4); // structTable[name] = struct_attr_info
      lua_pop(L, 1);     // pop type encoding
      luaL_addlstring(&encodingBuf, sai->encoding, encodingLen);
    }
  } luaL_addchar(&encodingBuf, '}');

  luaL_pushresult(&encodingBuf);
  lua_rawsetfield(L, -2, "__encoding");

  return 0;
}

/** lua_func, return a struct userdata
 *
 *  if call with 0 arg, create a empty struct.
 *  if call with 1 arg, it should be table array, contain each struct member
 *  init value.
 *  if call with more than 1 arg, it will pack to a table array, deal just like
 *  1 arg
 *
 *  @param upvalue 1: named_struct type
 */
static int create_struct(lua_State *L){
  int structInfoTableIndex = lua_upvalueindex(1);
  int top = lua_gettop(L);
  lua_rawgetfield(L, structInfoTableIndex, "__encoding");
  const char* encoding = lua_tostring(L, -1);
  LUAOC_ASSERT(encoding);

  void* value;
  if (top == 0) luaoc_push_struct(L, encoding, NULL); // empty struct
  else {
    // if construct struct with method call, it's parameter count must >=2
    if ( 1==top )
    {
      value = luaoc_copy_toobjc(L, 1, encoding, NULL);
    }
    else
    {
      lua_newtable(L); // array of all parameter
      for (int i = 1; i <= top; ++i) {
        lua_pushvalue(L, i);
        lua_rawseti(L, -2, i);
      }

      value = luaoc_copy_toobjc(L, -1, encoding, NULL);
    }
    luaoc_push_struct(L, encoding, value);
    free(value);
  }

  return 1;
}

static int index_struct_by_name(lua_State *L){
  luaL_getmetatable(L, NAMED_STRUCT_TABLE_NAME);
  lua_pushvalue(L, 2);
  if (lua_rawget(L, -2) != LUA_TNIL){ // push `named_struct[name]` to upvalue
    lua_pushcclosure(L, create_struct, 1);
  }
  return 1;
}

/** reg named struct into table at stack top */
static void reg_default_struct(lua_State *L){
  LUA_PUSH_STACK(L);
  char buf[256]; // used for get compiler struct info
  struct_attr_info* sai;

#define DEF_NAMED_STRUCT(...) _DEF_NAMED_STRUCT(CUR_NAME, __VA_ARGS__)
#define _DEF_NAMED_STRUCT(...) __DEF_NAMED_STRUCT(__VA_ARGS__)
// #name = {__encoding=(encode), __VA_ARGS__(pair of `name = struct_attr_info`) }
#define __DEF_NAMED_STRUCT(name, ...)                            \
  lua_newtable(L);                                              \
  lua_pushstring(L, @encode(name));                             \
  lua_rawsetfield(L, -2, "__encoding");                         \
  __VA_ARGS__                                                   \
  lua_rawsetfield(L, -2, #name);                                \

#define RAW_STRUCT_ATTR(name, type, path) _RAW_STRUCT_ATTR(name, type, path, CUR_NAME)
// {name = struct_attr_info}
#define _RAW_STRUCT_ATTR(name, type, path, parent)              \
  lua_pushstring(L, #name);                                     \
  sai = lua_newuserdata(L, sizeof(struct_attr_info));           \
  sai->offset = (char*)&(((parent*)buf)-> path ) - buf;         \
  sai->encoding = @encode( type );                              \
  lua_rawset(L, -3);                                            \

#define STRUCT_ATTR(name, type) RAW_STRUCT_ATTR(name, type, name)


#undef  CUR_NAME
#define CUR_NAME CGRect
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(origin    , CGPoint)
      STRUCT_ATTR(size      , CGSize )
      RAW_STRUCT_ATTR(x     , CGFloat  , origin.x)
      RAW_STRUCT_ATTR(y     , CGFloat  , origin.y)
      RAW_STRUCT_ATTR(width , CGFloat  , size.width)
      RAW_STRUCT_ATTR(height, CGFloat  , size.height)
  );

#undef CUR_NAME
#define CUR_NAME CGPoint
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(x, CGFloat)
      STRUCT_ATTR(y, CGFloat)
  )

#undef CUR_NAME
#define CUR_NAME CGSize
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(width, CGFloat)
      STRUCT_ATTR(height, CGFloat)
  )

#undef CUR_NAME
#define CUR_NAME NSRange
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(location, NSUInteger)
      STRUCT_ATTR(length, NSUInteger)
  )

#undef CUR_NAME
#define CUR_NAME CGAffineTransform
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(a, CGFloat)
      STRUCT_ATTR(b, CGFloat)
      STRUCT_ATTR(c, CGFloat)
      STRUCT_ATTR(d, CGFloat)
      STRUCT_ATTR(tx, CGFloat)
      STRUCT_ATTR(ty, CGFloat)
  )

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR

#undef CUR_NAME
#define CUR_NAME UIEdgeInsets
  DEF_NAMED_STRUCT(
      STRUCT_ATTR(top, CGFloat)
      STRUCT_ATTR(left, CGFloat)
      STRUCT_ATTR(bottom, CGFloat)
      STRUCT_ATTR(right, CGFloat)
  )

#endif

  LUA_POP_STACK(L,0);
}

static const luaL_Reg metaMethods[] = {
  {"__index", __index},
  {"__newindex", __newindex},
  {"__len", __len},
  {NULL, NULL},
};

static const luaL_Reg structFunctions[] = {
  {"reg", reg_struct},
  {"__index", index_struct_by_name},
  {NULL, NULL},
};

int luaopen_luaoc_struct(lua_State *L) {
  luaL_newlib(L, structFunctions);
  lua_pushvalue(L, -1);
  lua_setmetatable(L, -2); // set self as metaTable

  luaL_newmetatable(L, LUAOC_STRUCT_METATABLE_NAME);
  luaL_setfuncs(L, metaMethods, 0);

  lua_pushstring(L, "__type");
  lua_pushinteger(L, luaoc_struct_type);
  lua_rawset(L, -3);

  luaL_newmetatable(L, NAMED_STRUCT_TABLE_NAME);    // use to save named struct info
  reg_default_struct(L);

  lua_pop(L, 2);                                    // pop 2 metaTable

  return 1; // :structFunctions;
}

