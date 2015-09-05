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

/** add 1 retainCount by lua, compare to objc retain, the retainCount add by
 * this method will autorelease when gc
 *
 * @param 1: instance object
 */
static int lua_retain(lua_State *L) {
    LUAOC_RETAIN(L, 1);
    lua_pushvalue(L, 1);

    return 1; // return pass in obj
}

/** release obj immediately, transfer out ownership */
static int lua_release(lua_State *L) {
    LUAOC_RELEASE(L, 1);
    return 0;
}

/** get instance super.
 *
 * @param 1: instance or super userdata.
 * @param 2: class userdata or class name. or nil to use param 1's class
 * @return   super userdata, or nil when not get or fail
 * */
static int get_super(lua_State *L) {
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

static const luaL_Reg luaoc_funcs[] = {
    {"tolua",       tolua },
    // will autoconvert to oc type when needed
    // {"tooc",  tooc  },
    {"retain",      lua_retain},
    {"release",     lua_release},
    {"super",       get_super},
    {NULL,          NULL  },
};

static int __index(lua_State *L) {
    // index class
    lua_rawgetfield(L, 1, "class");
    lua_pushvalue(L, 2);
    if ( lua_gettable(L, -2) != LUA_TNIL ) return 1;
    lua_pop(L, 2);

    // index struct
    lua_rawgetfield(L, 1, "struct");
    lua_pushvalue(L, 2);
    if ( lua_gettable(L, -2) != LUA_TNIL ) return 1;
    lua_pop(L, 2);

    lua_pushnil(L);
    return 1;
}

static const luaL_Reg luaoc_metafuncs[] = {
    {"__index", __index},
    {NULL, NULL},
};

int luaopen_luaoc(lua_State *L){
  luaL_newlib(L, luaoc_funcs);
  luaL_newlib(L, luaoc_metafuncs);
  lua_setmetatable(L, -2);

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

  return 1;
}

