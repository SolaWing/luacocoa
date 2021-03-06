//
//  luaoc_class.h
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"


#define LUAOC_CLASS_METATABLE_NAME "oc.class"

int luaopen_luaoc_class(lua_State *L);

void luaoc_push_class(lua_State *L, Class cls);
Class luaoc_toclass(lua_State *L, int index);

/** return lua value in cls and super cls by key.
 *
 * @return push founded value and return 1. otherwise push nothing and return 0
 */
int index_value_from_class(lua_State *L, Class cls, int keyIndex);
