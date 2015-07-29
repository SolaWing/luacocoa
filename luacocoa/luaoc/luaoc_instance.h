//
//  luaoc_instance.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

struct lua_State;

#define LUAOC_INSTANCE_METATABLE_NAME "oc.instance"

int luaopen_luaoc_instance(struct lua_State *L);
