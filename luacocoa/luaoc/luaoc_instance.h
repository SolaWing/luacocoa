//
//  luaoc_instance.h
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lua.h"

#define LUAOC_INSTANCE_METATABLE_NAME "oc.instance"
#define LUAOC_SUPER_METATABLE_NAME "oc.super"

int luaopen_luaoc_instance(lua_State *L);

void luaoc_push_instance(lua_State *L, id v);

/** push super of value at index, value must be id or super data */
void luaoc_push_super(lua_State *L, int index, Class cls);

/** return the ref instance of instance userdata or super userdata */
id luaoc_toinstance(lua_State *L, int index);

/** add the lua_retain_count, if retain_count > 0, gc will release the obj
 *
 * @param index: index of instance obj.
 * @return count after add
 */
LUA_INTEGER luaoc_change_lua_retain_count(lua_State *L, int index, LUA_INTEGER change);

/** add 1 retainCount by lua, compare to objc retain, the retainCount add by
 * this method will autorelease when gc.
 *
 * NOTE: if retain a dealloc obj, autorelease in gc may crash. */
#define LUAOC_RETAIN(L, index)                                          \
{                                                                       \
    id* ud = (id*)lua_touserdata(L, index);                             \
    if (ud && luaoc_change_lua_retain_count(L, index, 1) == 1) {        \
        [*ud retain]; /* retain when first retain */                    \
    }                                                                   \
}

/** release obj immediately, transfer out ownership */
#define LUAOC_RELEASE(L, index)                                         \
{                                                                       \
    id* ud = (id*)lua_touserdata(L, index);                             \
    if (ud && luaoc_change_lua_retain_count(L, index, -1) == 0) {       \
        [*ud release]; /* release when reach 0 */                       \
    }                                                                   \
}

/** take ownership of a +1 obj. */
#define LUAOC_TAKE_OWNERSHIP(L, index)                                  \
{                                                                       \
    id* ud = (id*)lua_touserdata(L, index);                             \
    if (ud && luaoc_change_lua_retain_count(L, index, 1) > 1) {         \
        [*ud release]; /* release when not first retain */              \
    }                                                                   \
}

#pragma mark - LUA_TFUNCTION

/** lua retain obj, return self */
int luaoc_retain(lua_State *L);
int luaoc_release(lua_State *L);

/** get instance super.
 *
 * @param 1: instance or super userdata.
 * @param 2: class userdata or class name. or nil to use param 1's class

             recommend specify it in method which may be override.
             or you may repeat get super userdata, can't get super's super userdata

 * @return   super userdata, or nil when not get or fail
 * */
int luaoc_super(lua_State *L);
