//
//  luaoc_helper.h
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <stdbool.h>
#import "lua.h"

enum luaoc_userdata_type {
  luaoc_unknown_type  = 0,
  luaoc_class_type    = 1,
  luaoc_instance_type = 2,
  luaoc_super_type    = 3,
  luaoc_struct_type   = 4,
  luaoc_var_type      = 5,
};

#pragma mark - macro and inline method
/** register start index */
#define LUA_START_INDEX(L) (__startStackIndex)
#define LUA_PUSH_STACK(L) int __startStackIndex = lua_gettop(L)

/** reset to start index and may keep n value at top */
static inline void __luaoc_pop_stack(lua_State* L, int start, int keep) {
  if (lua_gettop(L) - start > keep) {
    if (keep > 0) lua_rotate(L, start+1, keep);
    lua_settop(L, start+keep);
  }
}

#define LUA_POP_STACK(L, keep) __luaoc_pop_stack((L), (__startStackIndex), (keep))

#define IS_RELATIVE_INDEX(index) ((index) < 0 && (index) > LUA_REGISTRYINDEX)

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

/** convert give luaName, return a alloc sel name, you should free it */
char* convert_copyto_selName(const char* luaName, bool isAppendColonIfNone);

/** convert luaName to selName, put in buffer. buffer's space should bigger than strlen(luaName) + 2 */
void convert_to_selName( char* buffer, const char* luaName, bool isAppendColonIfNone);

/** find sel by name, if sel not found, and selName not end with :, add : and retry */
SEL luaoc_find_SEL_byname(id target, const char* luaName);

/** first arg is receiver, second is method args. and this method should have a upvalue as method name */
int luaoc_msg_send(lua_State* L);

static inline void luaoc_push_msg_send(lua_State* L, SEL sel) {
  lua_pushlightuserdata(L, sel);
  lua_pushcclosure(L, luaoc_msg_send, 1);
}

/** convert given index lua value to objc value, return alloc address, you must free the return pointer */
void* luaoc_copy_toobjc(lua_State *L, int index, const char *typeDescription, size_t *outSize);

/** push any obj to lua according to typeDescription */
void  luaoc_push_obj(lua_State *L, const char *typeDescription, void* objRef);

/** get one type size from typeDescription
 *
 * @param typeDescription: type encoding str. for encode rule, see @encode()
 * @param stopPos: point to pos after parse a type, can pass NULL
 * @param copyTypeName:
 *      if present, set as the struct name or union name, you must free it.
 *      can pass NULL
 * @return : the typesize
 */
int luaoc_get_one_typesize(const char *typeDescription, const char** stopPos, char** copyTypeName);

#pragma mark - DEBUG METHOD
/** generic print method, used for debug */
void luaoc_print(lua_State* L, int index);
/** print table at index, now haven't deal infinite loop */
void luaoc_print_table(lua_State* L, int index);
/** print entire stack */
void luaoc_dump_stack(lua_State* L);

#ifndef DLOG
  #if defined(DEBUG) && DEBUG != 0
    #define DLOG(fmt, ...) printf("%s[%d]: " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__)
  #else
    #define DLOG(...)
  #endif
#endif

#define PP_STR(str) #str
