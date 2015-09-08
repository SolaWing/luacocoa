//
//  luaoc.h
//  luaoc
//
//  Created by SolaWing on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lua.h"

extern lua_State *gLua_main_state;
/** create a lua state and openLuaOC */
lua_State* luaoc_setup();
void luaoc_close();

int luaopen_luaoc(lua_State *L);
