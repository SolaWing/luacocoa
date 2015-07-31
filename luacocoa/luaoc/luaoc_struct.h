//
//  luaoc_struct.h
//  luaoc
//
//  Created by Wangxh on 15/7/29.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

#define LUAOC_STRUCT_METATABLE_NAME "oc.struct"

int luaopen_luaoc_struct(lua_State *L);

void luaoc_push_struct(lua_State *L, const char* typeDescription, void* structRef);
