//
//  luaoc_block.h
//  luaoc
//
//  Created by SolaWing on 15/9/7.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "lua.h"

@interface LUAFunction : NSObject

@property (nonatomic, copy) NSString* encoding;

/** associate self with luafunc, which is at the top. will pop the func at top */
- (void)setLuaFuncInState:(lua_State*)L;
/** push associate lua func to lua stack, return push value type */
- (int)pushLuaFuncInState:(lua_State*)L;

@end

/** convert lua function to OC block. and pop the 2 used param
 * @param top: encoding(when nil, default to @@, which is compatible to v@, v)
 * @param top - 1: lua function
 * @return OC block object, alloc on heap. you should release it.
 */
id luaoc_convert_copyto_block(lua_State* L);

int luaopen_luaoc_block(lua_State *L);
