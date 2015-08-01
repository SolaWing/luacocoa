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
