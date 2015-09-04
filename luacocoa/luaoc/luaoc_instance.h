//
//  luaoc_instance.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"
#import "luaoc_helper.h"

#define LUAOC_INSTANCE_METATABLE_NAME "oc.instance"
#define LUAOC_SUPER_METATABLE_NAME "oc.super"

int luaopen_luaoc_instance(lua_State *L);

void luaoc_push_instance(lua_State *L, id v);

/** push super of value at index, value must be id or super data */
// void luaoc_push_super(lua_State *L, int index);

/** return the ref instance of instance userdata or super userdata */
id luaoc_toinstance(lua_State *L, int index);

/** add the lua_retain_count, if retain_count > 0, gc will release the obj
 *
 * @param index: index of instance obj.
 * @return count after add
 */
LUA_INTEGER luaoc_change_lua_retain_count(lua_State *L, int index, LUA_INTEGER change);

// add retainCount for release in gc, lua will retain instance only once
#define LUAOC_RETAIN(L, index)                                          \
    if (luaoc_change_lua_retain_count(L, index, 1) == 1) {              \
        id* ud = (id*)lua_touserdata(L, index);                         \
        if ( unlikely( !ud ))                                           \
            LUAOC_ARGERROR( index, "passin obj should be instance" );   \
        [*ud retain]; /* retain when first retain */                    \
    }

// minus retainCount
#define LUAOC_RELEASE(L, index)                                         \
    if (luaoc_change_lua_retain_count(L, index, -1) == 0) {             \
        id* ud = (id*)lua_touserdata(L, index);                         \
        if ( unlikely( !ud ))                                           \
            LUAOC_ARGERROR( index, "passin obj should be instance" );   \
        [*ud release]; /* release when reach 0 */                       \
    }

// add retainCount for release in gc,
// pass in should be a +1 obj. so the +1 owned by lua
#define LUAOC_TAKE_OWNERSHIP(L, index)                                  \
    if (luaoc_change_lua_retain_count(L, index, 1) > 1) {               \
        id* ud = (id*)lua_touserdata(L, index);                         \
        if ( unlikely( !ud ))                                           \
            LUAOC_ARGERROR( index, "passin obj should be instance" );   \
        [*ud release]; /* release when not first retain */              \
    }
