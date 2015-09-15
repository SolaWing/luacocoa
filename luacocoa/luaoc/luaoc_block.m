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

#import "luaoc_instance.h"

#define LUAFunctionRegistryName "oc.funcMap" // table hold blockpointer to lua func

/** LUA_TFUNCTION, return created block
 *
 * @param 1 : function
 * @param 2 : encoding string, or nil to use default encoding
 */
static int luaoc_block(lua_State *L);

struct OCBlockStruct {
    void* isa;
    int flags;
    int reserved;
    void(*invoke)(void* block);
    void* descriptor;
    LUAFunction* upvalue;
};

/** add ^v to encoding after ret type.
 *
 * @param buffer: out buffer, should larger than strlen(encoding) + 3
 * @param encoding: passin encoding.
 * @param size: strlen(encoding)
 */
static inline void get_block_actual_encoding(char* buffer, const char* encoding, size_t size) {
    size_t offset = NSGetSizeAndAlignment(encoding, NULL, NULL) - encoding;

    memcpy(buffer, encoding, offset);
    memcpy(buffer + offset, "^v", 2);
    memcpy(buffer + (offset+2), encoding+offset, size-offset);
    buffer[size+2] = '\0'; // NULL terminated
}


//#define NO_USE_FFI
#ifndef NO_USE_FFI
#import "ffi.h"
#import "ffi_wrap.h"
static NSMutableDictionary* luaBlockFuncDict; // encoding => blockFunc

static void luaoc_block_from_oc(ffi_cif *cif, void* ret, void** args, void* ud) {
  if (![NSThread isMainThread]) {
      NSLog(@"[WARN] call lua block on non-main thread!!\n"
             "now dispatch to main thread. may deadlock");
      dispatch_sync( dispatch_get_main_queue(), ^{
          luaoc_block_from_oc(cif, ret, args, ud);
      });
      return ;
  }

  struct OCBlockStruct* block = *(void**)args[0];
  LUAFunction* luafunc = block->upvalue;
  lua_State *const L = gLua_main_state;
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
  size_t retLen = luaoc_get_one_typesize(encoding, &args_encoding, NULL);
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
    size_t size = strlen(encoding);
    char* trueEncoding = alloca(size + 3);
    get_block_actual_encoding(trueEncoding, encoding, size);

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


// NOTE when use @ insteadof v, may get garbage value. if use this value, will crash
// 
// for lua created block, oc invoke it as vv, paramter is garbage and return from lua will be convert to NULL
// for lua invoke block, which actually is vv, paramter will be convert to NULL and return value is garbage
//
// so if value get from lua, @ is compatible with v as NULL value.
// but if from oc, it's a garbage value
//
//
//
// recommend pass encoding specifically, except for vv
id luaoc_convert_copyto_block(lua_State* L) {
    luaL_checktype(L, -2, LUA_TFUNCTION);
    LUAFunction* func = [LUAFunction new];
    const char* encoding = lua_tostring(L, -1);
    if (!encoding) {
        // lua block: default return type is @.
        // param type is @, count equal to fixed param count
        lua_Debug ar;
        lua_pushvalue(L, -2);
        lua_getinfo(L, ">u", &ar);
        encoding = alloca( ar.nparams + 2 );
        memset((char*)encoding, '@', ar.nparams+1);
        ((char*)encoding)[ar.nparams+1] = '\0';
    }
    func.encoding = [NSString stringWithUTF8String:encoding];
    lua_pop(L, 1);
    [func setLuaFuncInState:L];

    IMP imp = imp_for_encoding(func.encoding);
    if (!imp) {
        [func release];
        DLOG("can't create IMP for encoding:%s", func.encoding.UTF8String);
        return NULL;
    }

    // return block should be alloc on heap to ensure exist
    dispatch_block_t block = Block_copy(^{
        NSLog(@"use %@ to hold LUAFunction, shouldn't be call", func);
    });

    struct OCBlockStruct* hackblock = (void*)block;
    hackblock->invoke = (void*)imp;

    [func release];
    return block; // MRC should return a heap block
}

int luaoc_call_block(lua_State *L) {
    // first should be a block instance. or will crash
    struct OCBlockStruct* block = *(void**)lua_touserdata(L, 1);
    LUAOC_ASSERT(block);

    // TODO: check if a lua block and call directly
    NSUInteger argNumber;
    const char* encoding = lua_tostring(L, 2);
    if (NULL == encoding) {
        // default return void, args type is @, count equal to passin param count
        argNumber = lua_gettop(L) - 2;
        if ((NSInteger)argNumber < 0) argNumber = 0;

        encoding = alloca(argNumber+2);
        *(char*)encoding = 'v';
        memset((char*)encoding+1, '@', argNumber);
        ((char*)encoding)[argNumber+1] = '\0';
    }

    int status;
    void* rvalue = NULL;
    void** avalue;

    const char* encodingIt;
    NSUInteger retSize = luaoc_get_one_typesize(encoding, &encodingIt, NULL);
    LUAOC_ASSERT( retSize != NSNotFound );
    if (retSize > 0) {
        // ffi call ensure ret buffer at least pointer size
        if (retSize < sizeof(void*)) retSize = sizeof(void*);
        rvalue = alloca(retSize);
    }

    // insert block hid arg to encoding;
    size_t size = strlen(encoding);
    char* trueEncoding = alloca( size + 3 );
    size_t i = encodingIt - encoding;
    memcpy(trueEncoding, encoding, i);
    memcpy(trueEncoding + i, "^v", 2);
    memcpy(trueEncoding + i+2, encodingIt, size-i);
    trueEncoding[size+2] = '\0';        // NULL terminated

    argNumber = luaoc_get_type_number(encodingIt) + 1;
    avalue = alloca(sizeof(void*) * (argNumber) );

    *avalue = &block;       // first arg is the block.
    for (i = 1; i < argNumber; ++i) {
        avalue[i] = luaoc_copy_toobjc(L, (int)i+2, encodingIt, NULL);
        luaoc_get_one_typesize(encodingIt, &encodingIt, NULL);
    }

    NSException* err = nil;
    @try {
        status = objc_ffi_call(trueEncoding, FFI_FN(block->invoke), rvalue, avalue);
    }
    @catch (NSException* exception) {
        err = exception;
    }

    for (i = 1; i < argNumber; ++i) {
        free(avalue[i]);
    }

    LUAOC_ASSERT_MSG(!err, "Error invoking block with encoding '%s'. reason is:\n%s",
            encoding, [[err reason] UTF8String]);
    // when exception, status is garbage value
    LUAOC_ASSERT_MSG(status == 0, "Error invoking block with encoding '%s'. error code: %d",
            encoding, status);

    if (retSize > 0){
        luaoc_push_obj(L, trueEncoding, rvalue); // first type is ret type
    } else{
        lua_pushnil(L);
    }

    return 1;
}

static int luaoc_block(lua_State *L) {
    // only keep 2 value at lua stack, as paramter pass to luaoc_convert_to_block
    lua_settop(L, 2);
    id block = luaoc_convert_copyto_block(L);
    luaoc_push_obj(L, @encode(id), &block);
    // malloc_block is id type, can use retain and release
    [block release];

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

