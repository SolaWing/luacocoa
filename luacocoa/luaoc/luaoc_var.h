//
//  luaoc_var.h
//  luaoc
//
//  Created by Wangxh on 15/8/3.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

/**
 *  var type is just a container for save a value.
 *  it is a pointer ref to a block of memory.
 *  you can set or get from index 'v'.
 *  when set, it may auto convert to it's created type
 */

#define LUAOC_VAR_METATABLE_NAME "oc.var"

/** create a var userdata, may have a init value */
void luaoc_push_var(lua_State *L, const char* typeDescription, void* initRef);

int luaopen_luaoc_var(lua_State *L);
