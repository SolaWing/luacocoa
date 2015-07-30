//
//  luaoc_helper.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

enum luaoc_userdata_type {
  luaoc_unknown_type  = 0,
  luaoc_class_type    = 1,
  luaoc_instance_type = 2,
  luaoc_super_type    = 3,
  luaoc_struct_type   = 4,
};

#pragma mark - macro and inline method
/** register start index */
#define LUA_START_INDEX(L) (__startStackIndex)
#define LUA_PUSH_STACK(L) int __startStackIndex = lua_gettop(L);

/** reset to start index and may keep n value at top */
#define LUA_POP_STACK(L, keep)                                        \
   ((keep)>0?lua_rotate((L),                                          \
                        (__startStackIndex)+1,                        \
                        (keep))                                       \
            :(void)0,                                                 \
    lua_settop(L, __startStackIndex+(keep)))                          \

#define IS_RELATIVE_INDEX(index) ((index) < 0 && (index) > LUA_REGISTRYINDEX)

/** if minus relative index, convert to absolute index */
static inline int lua_absolute_index(lua_State *L, int index) {
  return IS_RELATIVE_INDEX(index) ? (lua_gettop(L) + index + 1) : index;
}

/** just like `lua_setfield`, but does a raw set */
static inline void lua_rawsetfield(lua_State *L, int index, const char *k){
  lua_pushstring(L, k);
  lua_insert(L, -2);
  lua_rawset(L, IS_RELATIVE_INDEX(index) ? index-1:index);
}

/** just like `lua_getfield`, but does a raw get */
static inline int lua_rawgetfield(lua_State *L, int index, const char *k){
  lua_pushstring(L, k);
  return lua_rawget(L, IS_RELATIVE_INDEX(index) ? index-1:index);
}

#pragma mark - api method
/** first arg is receiver, second is method args */
int luaoc_msg_send(lua_State* L);

#pragma mark - DEBUG METHOD
/** generic print method, used for debug */
void luaoc_print(lua_State* L, int index);
/** print table at index, now haven't deal infinite loop */
void luaoc_print_table(lua_State* L, int index);
/** print entire stack */
void luaoc_dump_stack(lua_State* L);
