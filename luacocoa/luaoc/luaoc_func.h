//
//  luaoc_func.h
//  luaoc
//
//  Created by SolaWing on 15/11/20.
//  Copyright © 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lua.h"

/** reg a c function for lua use
 *
 * @param name: the lua name of c function
 * @param fp: the c function pointer
 * @param encoding: the function encoding according to objc type encoding
 */
void luaoc_reg_cfunc(lua_State* L, const char* name, void* fp, const char* encoding);


int luaopen_luaoc_func(lua_State* L);
