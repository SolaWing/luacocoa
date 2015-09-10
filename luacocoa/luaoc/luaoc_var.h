//
//  luaoc_var.h
//  luaoc
//
//  Created by SolaWing on 15/8/3.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

/**
 *  var type is just a container for save a value.
 *  it is a pointer ref to a block of memory.
 *  you can set or get from index 'v'.
 *  when set, it may auto convert to it's created type
 *
 *  if the var type is id, it won't retain the value.
 *  it's your responsiblility to ensure the value is valid.
 *
 *  the var type can be used in following situation:
 *    1) c function need a inout or out parameter(pointer to the type), you can
 *       pass a var userdata as container to hold the out buffer
 *    2) hold a unsafe_unretained ref to id instance.
 *    3) hold a weak ref to id instance, by pass flags luaoc_var_weak.
 *
 *  after create var, the var type shouldn't be change. and all new value set on
 *  it will try to convert to the type when created
 */

#define LUAOC_VAR_METATABLE_NAME "oc.var"

enum luaoc_var_flags {
    luaoc_var_weak = 1 << 0,
};

/** create a var userdata, may have a init value */
void luaoc_push_var(lua_State *L, const char* typeDescription, void* initRef, int flags);

/** get value from var at index */
void luaoc_get_var(lua_State *L, int index);

/** set value from var at index, pop the set value at top */
void luaoc_set_var(lua_State *L, int index);

int luaopen_luaoc_var(lua_State *L);

int luaopen_luaoc_encoding(lua_State *L);
