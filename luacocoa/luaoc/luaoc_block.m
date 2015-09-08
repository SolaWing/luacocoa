//
//  luaoc_block.m
//  luaoc
//
//  Created by SolaWing on 15/9/7.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_block.h"
#import "luaoc_helper.h"
#import "luaoc.h"
#import "lauxlib.h"
#import "ffi_wrap.h"
#import "luaoc_instance.h"

#define LUAFunctionRegistryName "oc.funcMap" // table hold blockpointer to lua func

struct OCBlockStruct {
    void* isa;
    int flags;
    int reserved;
    void(*invoke)(void* block);
    void* descriptor;
    LUAFunction* upvalue;
};

// in 32bit iphone_simulator, my libffi can't compile. so disable it.
#if TARGET_IPHONE_SIMULATOR && !defined(__LP64__)
#define NO_USE_FFI
#endif

//#define NO_USE_FFI
#ifndef NO_USE_FFI
#import "ffi.h"
static NSMutableDictionary* luaBlockFuncDict; // encoding => blockFunc

static void luaoc_block_from_oc(ffi_cif *cif, void* ret, void** args, void* ud) {
  if (![NSThread isMainThread]) {
      NSLog(@"[WARN] call lua block on non-main thread!!\n"
             "now dispatch to main thread.");
      dispatch_sync( dispatch_get_main_queue(), ^{
          luaoc_block_from_oc(cif, ret, args, ud);
      });
      return ;
  }

  struct OCBlockStruct* block = *(void**)args[0];
  LUAFunction* luafunc = block->upvalue;
  lua_State *L = gLua_main_state;
  int top = lua_gettop(L);

  if (!luafunc || !luafunc.encoding ||
      [luafunc pushLuaFuncInState:L] != LUA_TFUNCTION)
  {
      lua_settop(L, top);
      DLOG("can't found associate block lua func!!");
      return;
  }

  const char* encoding = luafunc.encoding.UTF8String;
  const char* args_encoding, *stop_pos;
  NSUInteger retLen = luaoc_get_one_typesize(encoding, &args_encoding, NULL);
  int i = 1;
  while (*args_encoding) {
      if (luaoc_get_one_typesize(args_encoding, &stop_pos, NULL) != NSNotFound) {
          luaoc_push_obj(L, args_encoding, args[i]);
          ++i;
      }
      args_encoding = stop_pos;
  }

  if (luaoc_pcall(L, i - 1, retLen>0?1:0) == 0) {
      if (retLen > 0) {
          void* buf = luaoc_copy_toobjc(L, -1, encoding, &retLen);
          memcpy(ret, buf, retLen);
          free(buf);
      }
  } else {
      DLOG("block call lua func error:\n  %s", lua_tostring(L, -1) );
  }
  lua_settop(L, top);
}

static IMP imp_for_encoding(NSString* encodingString) {
    NSValue *impVal = luaBlockFuncDict[encodingString];
    if (impVal) return [impVal pointerValue];

    // block func have block self as first parameter, so add it
    const char* encoding = encodingString.UTF8String;
    size_t size = strlen(encoding) + 3;
    char* trueEncoding = alloca(size);
    size_t offset = NSGetSizeAndAlignment(encoding, NULL, NULL) - encoding;

    memcpy(trueEncoding, encoding, offset);
    memcpy(trueEncoding + offset, "^v", 2);
    // contains NULL terminated
    memcpy(trueEncoding + (offset+2), encoding+offset, size-offset-2);

    IMP imp = create_imp_for_encoding(trueEncoding, luaoc_block_from_oc, NULL);
    if (imp) { // cache IMP func
        luaBlockFuncDict[encodingString] = [NSValue valueWithPointer:imp];
    }
    return imp;
}

#else

#endif

@implementation LUAFunction

- (void)dealloc {
    if (gLua_main_state) {
        dispatch_block_t block = ^{
            lua_pushnil(gLua_main_state);
            [self setLuaFuncInState:gLua_main_state];
        };
        if ([NSThread isMainThread]) block();
        else dispatch_sync(dispatch_get_main_queue(), block);
    }
    [super dealloc];
}

- (void)setLuaFuncInState:(lua_State*)L {
    lua_rawgetfield(L, LUA_REGISTRYINDEX, LUAFunctionRegistryName);
    lua_pushlightuserdata(L, (void*)self);
    lua_rotate(L, -3, -1);          // move func to top
    lua_rawset(L, -3);
    lua_pop(L,1);                   // pop LUAFunctionRegistryName table
}

- (int)pushLuaFuncInState:(lua_State*)L {
    lua_rawgetfield(L, LUA_REGISTRYINDEX, LUAFunctionRegistryName);
    int type = lua_rawgetp(L, -1, (void*)self);
    lua_remove(L, -2);
    return type;
}

@end


id luaoc_convert_copyto_block(lua_State* L) {
    luaL_checktype(L, -2, LUA_TFUNCTION);
    LUAFunction* func = [LUAFunction new];
    const char* encoding = lua_tostring(L, -1);
    if (encoding) {
        func.encoding = [NSString stringWithUTF8String:encoding];
    } else {
        // NOTE default @@, if actually not @@, but other compatible encoding.
        // invoke func may pass garbage value to lua.
        // this garbage can't be use, even in push function.
        // otherwise, may crash.
        //
        // recommend specifiy encoding specifically
        func.encoding = @"@@";
    }
    lua_pop(L, 1);
    [func setLuaFuncInState:L];

    IMP imp = imp_for_encoding(func.encoding);
    if (!imp) {
        [func release];
        DLOG("can't create IMP for encoding:%s", func.encoding.UTF8String);
        return NULL;
    }

    dispatch_block_t block = ^{
        NSLog(@"use %@ to hold LUAFunction, shouldn't be call", func);
    };

    struct OCBlockStruct* hackblock = (void*)block;
    hackblock->invoke = (void*)imp;

    [func release];
    return Block_copy(block); // MRC should return a heap block
}

/** LUA_TFUNCTION, return created block
 *
 * @param 1 : function
 * @param 2 : encoding string, or nil to use default encoding
 */
static int luaoc_block(lua_State *L) {
    // only keep 2 value at lua stack, as paramter pass to luaoc_convert_to_block
    lua_settop(L, 2);
    id block = luaoc_convert_copyto_block(L);
    luaoc_push_obj(L, @encode(id), &block);
    LUAOC_TAKE_OWNERSHIP(L, -1);

    return 1;
}

int luaopen_luaoc_block(lua_State *L) {
    lua_newtable(L);
    lua_rawsetfield(L, LUA_REGISTRYINDEX, LUAFunctionRegistryName);

    lua_pushcfunction(L, luaoc_block);

#ifndef NO_USE_FFI
  if (!luaBlockFuncDict){
    luaBlockFuncDict = [[NSMutableDictionary alloc] init];
  }
#endif
    return 1; // return luaoc_block func
}
