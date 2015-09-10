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
#import "luaoc_class.h"

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "objc/runtime.h"

static inline char get_encoding_type(const char* encoding) {
    do {
        switch( *encoding ){
            case _C_ID:
            case _C_CLASS:
            case _C_SEL:
            case _C_CHR:
            case _C_UCHR:
            case _C_SHT:
            case _C_USHT:
            case _C_INT:
            case _C_UINT:
            case _C_LNG:
            case _C_ULNG:
            case _C_LNG_LNG:
            case _C_ULNG_LNG:
            case _C_FLT:
            case _C_DBL:
            case _C_BFLD:
            case _C_BOOL:
            case _C_VOID:
            case _C_UNDEF:
            case _C_PTR:
            case _C_CHARPTR:
            case _C_ATOM:
            case _C_ARY_B:
            case _C_UNION_B:
            case _C_STRUCT_B:
            case _C_VECTOR:
            case '\0':
                return *encoding;
            default: break;
        }
        ++encoding;
    } while(true);
}

void luaoc_push_var(lua_State *L, const char* typeDescription, void* initRef, int flags) {
  NSCParameterAssert(typeDescription);

  char *structName = NULL;
  const char *endPos;
  NSUInteger size = luaoc_get_one_typesize(typeDescription, &endPos, &structName);

  if ( unlikely( size == 0 )) {
      DLOG( "empty var size!!" );
      lua_pushnil( L );
      return;
  }

  char simpleType = get_encoding_type(typeDescription);
  void* ud = lua_newuserdata(L, size);
  if ( ( flags & luaoc_var_weak && simpleType == _C_ID) ) {
      objc_storeWeak(ud, *(id*)initRef);
  } else {
      if (initRef) memcpy(ud, initRef, size);
      else memset(ud, 0, size);
  }

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

    lua_pushinteger(L, flags);
    lua_rawsetfield(L, -2, "__flags");

    lua_pushinteger(L, simpleType);
    lua_rawsetfield(L, -2, "__type");

    lua_setuservalue(L, -2);
  }



  free(structName); // : ud
}

void luaoc_get_var(lua_State *L, int index) {
    void* ud = luaL_checkudata(L, index, LUAOC_VAR_METATABLE_NAME);

    LUA_PUSH_STACK(L);

    lua_getuservalue(L, index);
    lua_rawgetfield(L, -1, "__encoding");
    luaoc_push_obj(L, lua_tostring(L, -1), ud);

    LUA_POP_STACK(L, 1);
}

void luaoc_set_var(lua_State *L, int index) {
    void* ud = luaL_checkudata(L, index, LUAOC_VAR_METATABLE_NAME);

    int top = lua_gettop(L);

    lua_getuservalue(L, index);
    lua_rawgetfield(L, -1, "__encoding");

    size_t outSize;
    void* v = luaoc_copy_toobjc(L, -3, lua_tostring(L, -1), &outSize);

    lua_rawgetfield(L, -2, "__flags");
    LUA_INTEGER flags = lua_tointeger(L, -1);
    if ( ( flags & luaoc_var_weak ) &&
         lua_rawgetfield(L, -3, "__type") == LUA_TNUMBER &&
         lua_tointeger(L, -1) == _C_ID )
    {
        objc_storeWeak(ud, *(id*)v);
    } else {
        memcpy(ud, v, outSize);
    }

    free(v);

    lua_settop(L, top - 1); // pop value at top
}

static const luaL_Reg varFuncs[] = {
  {NULL, NULL},
};

static int create_var(lua_State *L){
  const char* typeDescription = luaL_checkstring(L, 2);
  if (lua_isnoneornil(L, 3)) luaoc_push_var(L, typeDescription, NULL, 0);
  else {
    void* v = luaoc_copy_toobjc(L, 3, typeDescription, NULL);
    luaoc_push_var(L, typeDescription, v, 0);
    free(v);
  }
  return 1;
}

static const luaL_Reg varMetaFuncs[] = {
  {"__call", create_var},
  {NULL, NULL},
};

static int __gc(lua_State *L){
    lua_getuservalue(L, 1);
    if (lua_rawgetfield(L, -1, "__retainCount") == LUA_TNUMBER &&
            lua_tointeger(L, -1) > 0)
    {
        // call lua retain on var type. should release it
        [*(id*)lua_touserdata(L, 1) release];
    }
    if (lua_rawgetfield(L, -2, "__flags") == LUA_TNUMBER &&
        (lua_tointeger(L, -1) & luaoc_var_weak) &&
        lua_rawlen(L, 1) == sizeof(id))
    {
        objc_storeWeak(lua_touserdata(L, 1), nil); // clear weak var when dealloc
    }
    return 0;
}

static int __index(lua_State *L) {
  void* ud = luaL_checkudata(L, 1, LUAOC_VAR_METATABLE_NAME);

  lua_getuservalue(L,1);
  lua_pushvalue(L, 2);
  if (lua_rawget(L, -2) == LUA_TNIL){
      lua_rawgetfield(L, -2, "__type");
      char type = lua_tointeger(L, -1);
      if ((type == _C_ID || type == _C_CLASS) && lua_type(L, 2) == LUA_TSTRING
          && *(id*)ud != nil)
      {
          const char* key = lua_tostring(L, 2);
          SEL sel = luaoc_find_SEL_byname(*(id*)ud, key);
          if (sel){
              luaoc_push_msg_send(L, sel);
          }
          if (lua_isnil(L, -1)){ // still nil index class to try find a value
              // when not a oc msg, try to find lua value in cls
              if (type == _C_ID) {
                  index_value_from_class(L, [*(id*)ud class], 2);
              } else {
                  index_value_from_class(L, [*(Class*)ud superclass], 2);
              }
          }
      }
      else if (type == _C_STRUCT_B) { // struct type
          const char* encoding;
          int attrOffset;
          if ( lua_isinteger(L, 2) ) {
              LUA_INTEGER index = lua_tointeger(L, 2); // begin from 1
              lua_rawgetfield(L, -3, "__encoding");
              encoding = lua_tostring(L, -1);

              attrOffset = luaoc_struct_offset_by_index(
                      encoding, (int)index-1, &encoding);
              if (attrOffset < 0) {
                  LUAOC_ERROR("invalid struct index or encoding");
              } else {
                  luaoc_push_obj(L, encoding, lua_touserdata(L, 1) + attrOffset);
              }
          } else { // index by keyname
              lua_rawgetfield(L, -3, "__name");     // uv[__name]
              lua_pushvalue(L, 2);

              attrOffset = luaoc_struct_offset_by_key(L, &encoding);
              if (attrOffset < 0) {
                  lua_pushnil(L);
              } else {
                  luaoc_push_obj(L, encoding, lua_touserdata(L, 1) + attrOffset);
              }
          }
          
      }
  }

  return 1;
}

static int __newindex(lua_State *L) {
  void* ud = luaL_checkudata(L, 1, LUAOC_VAR_METATABLE_NAME);

  lua_getuservalue(L, 1);
  lua_rawgetfield(L, -1, "__type");
  char type = lua_tointeger(L, -1);
  if (type == _C_STRUCT_B) {
      const char * encoding;
      int attrOffset;
      if ( lua_isinteger(L, 2) ) {
          LUA_INTEGER index = lua_tointeger(L, 2); // begin from 1
          lua_rawgetfield(L, -2, "__encoding");
          encoding = lua_tostring(L, -1);

          attrOffset =
              luaoc_struct_offset_by_index(encoding, (int)index-1, &encoding);
          if (attrOffset < 0) {
              LUAOC_ERROR("invalid struct index or encoding");
          }
      } else {
          lua_rawgetfield(L, -2, "__name");     // uv[__name]
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
  }

  lua_settop(L, 4); // ud key val uv
  lua_insert(L, 2);
  lua_rawset(L, 2);                         // udv[key] = value

  return 0;
}

static const luaL_Reg metaFuncs[] = {
  {"__index",    __index},
  {"__newindex", __newindex},
  {"__gc",       __gc},
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

