//
//  luaoc_class.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"


#define LUAOC_CLASS_METATABLE_NAME "oc.class"

int luaopen_luaoc_class(lua_State *L);

void luaoc_push_class(lua_State *L, Class cls);
Class luaoc_toclass(lua_State *L, int index);

/** return lua value in cls and super cls,
 * if found, push to stack and return 1
 * else push nothing and return 0 */
int indexValueFromClass(lua_State *L, Class cls, int keyIndex);
