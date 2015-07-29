//
//  luaoc_helper.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

/** register start index */
#define LUA_START_INDEX(L) (__startStackIndex)
#define PUSH_LUA_STACK(L) int __startStackIndex = lua_gettop(L);

/** reset to start index and may keep n value at top */
#define POP_LUA_STACK(L, keep)                                        \
   ((keep)>0?lua_rotate((L),                                          \
                        (__startStackIndex)+1,                          \
                        (keep))                                       \
            :(void)0,                                                 \
    lua_settop(L, __startStackIndex+(keep)))                          \

int luaoc_msg_send(lua_State* L);

#pragma mark - DEBUG METHOD
/** generic print method, used for debug */
void luaoc_print(lua_State* L, int index);
/** print table at index, now haven't deal infinite loop */
void luaoc_print_table(lua_State* L, int index);
/** print entire stack */
void luaoc_dump_stack(lua_State* L);
