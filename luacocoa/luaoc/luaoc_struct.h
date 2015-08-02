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

/** if the given index is struct userdata, return it in outStructRef
 *
 * @param outStructRef: buffer to hold out struct, it should large enough to
 *                      hold the struct data.
 * @return: true if success, false otherwise.
 */
int luaoc_tostruct(lua_State *L, int index, void* outStructRef);

/** similar to `luaoc_tostruct`, and pass n to show the buffer size.
 *  if buffer not enough to hold, return false */
int luaoc_tostruct_n(lua_State *L, int index, void* outStructRef, size_t n);

/**
 * similar to `luaoc_tostruct`, but return a copyed struct ref.
 *
 * @param outSize: the struct size. can pass NULL
 * @return: copyed struct ref, or NULL in error. you are responsible to free it.
 */
void* luaoc_copystruct(lua_State *L, int index, size_t* outSize);

/** get the lua inner userdata struct ref */
void* luaoc_getstruct(lua_State *L, int index);
