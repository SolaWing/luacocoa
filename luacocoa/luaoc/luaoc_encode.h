//
//  luaoc_encode.h
//  luaoc
//
//  Created by SolaWing on 15/9/14.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "lua.h"

int luaopen_luaoc_encoding(lua_State *L);

/** get encoding for index.
 *
 * if index is table, should be a array of typenames . concat all type encoding and push it
 * if index is string, push it.
 * otherwise, push nil.
 */
void luaoc_push_encoding_for_index(lua_State *L, int index);
