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
#import "luaoc_var.h"
#import "luaoc_helper.h"
#import <objc/runtime.h>

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

static void push_instance_tolua(lua_State *L, id val) {
    if ( [val isKindOfClass:[NSString class]] ) {
        lua_pushstring(L, [val UTF8String]);
    } else if ( [val isKindOfClass:[NSNumber class]] ) {
        lua_pushnumber(L, [val doubleValue]);
    } else if ( [val isKindOfClass:[NSArray class]] ) {
        lua_newtable(L);
        for (NSUInteger i = 0; i < [val count]; ) {
            push_instance_tolua(L, val[i]);
            lua_rawseti(L, -2, ++i);
        }
    } else if ( [val isKindOfClass:[NSDictionary class]] ) {
        lua_newtable(L);
        [val enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
            push_instance_tolua(L, key);
            push_instance_tolua(L, obj);
            lua_rawset(L, -3);
        }];
    }
    else if (!val || val == [NSNull null]) {lua_pushnil(L);}
    else { luaoc_push_instance(L, val); } // other instance, can't convert to lua
}

/** push struct and convert to lua table. */
static void push_struct_tolua(lua_State *L, void* structRef, const char* encoding) {
    LUAOC_ASSERT(structRef);
    LUAOC_ASSERT(encoding);

    encoding = strchr(encoding, '=');
    LUAOC_ASSERT(encoding);
    ++encoding;

    lua_newtable(L);

    NSUInteger offset = 0, i = 0;
    NSUInteger size, align;

    while( *encoding != _C_STRUCT_E && *encoding != '\0' ) {
        const char* type = encoding;
        encoding = NSGetSizeAndAlignment(type, &size, &align);
        luaoc_align_offset(&offset, align);
        switch( *type ){
            case _C_ID: {
                push_instance_tolua(L, *(id*)(&structRef[offset]));
                break;
            }
            case _C_STRUCT_B: {
                push_struct_tolua(L, &structRef[offset], type);
                break;
            }
            default: { luaoc_push_obj(L, type, &structRef[offset]); }
        }
        lua_rawseti(L, -2, ++i);
    }
}

/** convert id type to primitive lua type,
 * support multi value and return multi value*/
static int tolua(lua_State *L) {
    int top = lua_gettop(L);
    for (int i = 1; i <= top; ++i) {
        if ( lua_type(L, i) == LUA_TUSERDATA)
        {
            if (luaL_getmetafield(L, i, "__type") != LUA_TNIL)
            {
                LUA_INTEGER tt = lua_tointeger(L, -1); lua_pop(L, 1);
                switch( tt ){
                    case luaoc_super_type:
                    case luaoc_instance_type: {
                        id val = *(id*)lua_touserdata(L, i);
                        push_instance_tolua(L, val);
                        break;
                    }
                    case luaoc_struct_type: {
                        void* structRef = lua_touserdata(L, i);
                        lua_getfield(L, i, "__encoding");
                        const char* encoding = lua_tostring(L, -1);
                        lua_pop(L,1);

                        push_struct_tolua(L, structRef, encoding);
                        break;
                    }
                    // don't convert for other type
                    default: { break; }
                }
            } else { lua_pop(L, 1); } // pop nil
        }
        // if push value, replace to index value
        if (lua_gettop(L) > top) lua_replace(L, i);
    }
    lua_settop(L, top);
    return top;
}

static const luaL_Reg luaoc_funcs[] = {
    {"tolua", tolua },
    // will autoconvert to oc type when needed
    // {"tooc",  tooc  },
    {NULL,    NULL  },
};

int luaopen_luaoc(lua_State *L){
  lua_newtable(L);

  luaopen_luaoc_class(L);
  lua_setfield(L, -2, "class");

  luaopen_luaoc_instance(L);
  lua_pop(L, 1);

  luaopen_luaoc_struct(L);
  lua_setfield(L, -2, "struct");

  luaopen_luaoc_var(L);
  lua_setfield(L, -2, "var");

  luaopen_luaoc_encoding(L);
  lua_setfield(L, -2, "encoding");

  luaL_setfuncs(L, luaoc_funcs, 0);

  return 1;
}

