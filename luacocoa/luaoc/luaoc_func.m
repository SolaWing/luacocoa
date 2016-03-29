//
//  luaoc_func.m
//  luaoc
//
//  Created by SolaWing on 15/11/20.
//  Copyright © 2015年 sw. All rights reserved.
//

#import "luaoc_func.h"
#import "lauxlib.h"
#import "luaoc_helper.h"

#define LUAOC_REG_FUNC_TABLE "oc.func"

#ifndef NO_USE_FFI
#import "ffi_wrap.h"

static int call_function(lua_State *L) {
    void (*fp)(void) = lua_touserdata(L, lua_upvalueindex(1));
    LUAOC_ASSERT(fp);
    const char* encoding = luaL_checkstring(L, lua_upvalueindex(2));


    int status;
    void* rvalue = NULL;
    void** avalue = NULL;
    const char* encodingIt;

    // alloc ret value space
    NSUInteger retSize = luaoc_get_one_typesize(encoding, &encodingIt, NULL);
    LUAOC_ASSERT( retSize != NSNotFound );
    if (retSize > 0) {
        // ffi call ensure ret buffer at least pointer size
        if (retSize < sizeof(void*)) retSize = sizeof(void*);
        rvalue = alloca(retSize);
    }

    // alloc and set args
    NSUInteger argNumber = luaoc_get_type_number(encodingIt);
    if (argNumber > 0) {
        avalue = alloca(sizeof(void*) * (argNumber) );
        for (NSUInteger i = 0; i < argNumber; ++i) {
            avalue[i] = luaoc_copy_toobjc(L, (int)i+1, encodingIt, NULL);
            luaoc_get_one_typesize(encodingIt, &encodingIt, NULL);
        }
    }

    // call function
    NSException* err = nil;
    @try {
        status = objc_ffi_call(encoding, fp, rvalue, avalue);
    }
    @catch (NSException* exception) {
        err = exception;
    }

    for (NSUInteger i = 0; i < argNumber; ++i) {
        free(avalue[i]);
    }

    LUAOC_ASSERT_MSG(!err, "Error invoking func with encoding '%s'. reason is:\n%s",
            encoding, [[err reason] UTF8String]);
    // when exception, status is garbage value
    LUAOC_ASSERT_MSG(status == 0, "Error invoking func with encoding '%s'. error code: %d",
            encoding, status);

    // push return value
    if (retSize > 0){
        luaoc_push_obj(L, encoding, rvalue); // first type is ret type
    } else{
        lua_pushnil(L);
    }

    return 1;
}

#else
static int call_function(lua_State *L) {
    NSCAssert(false, @"no implement!");
    return 0;
}

#endif

void luaoc_reg_cfunc(lua_State* L, const char* name, void* fp, const char* encoding) {
    NSCParameterAssert(name);
    NSCParameterAssert(fp);
    NSCParameterAssert(encoding);

    lua_rawgetfield(L, LUA_REGISTRYINDEX, LUAOC_REG_FUNC_TABLE);

    lua_pushlightuserdata(L, fp);
    lua_pushstring(L, encoding);
    lua_pushcclosure(L, call_function, 2);

    lua_rawsetfield(L, -2, name);
}

void luaoc_reg_cfunc_with_types(lua_State* L, const char* name, void* fp, const char** encodings, int n) {
    char buf[0xffff];
    char* buf_it = buf;
    for(const char **it=encodings, **ite=encodings+n; it < ite; ++it ) {
        size_t len = strlen(*it);
        memcpy(buf_it, *it, len);
        buf_it+=len;
    }
    *buf_it = '\0'; // NULL terminated
    luaoc_reg_cfunc(L, name, fp, buf);
}

int luaopen_luaoc_func(lua_State* L) {
    lua_newtable(L);
    lua_pushvalue(L, -1);
    lua_rawsetfield(L, LUA_REGISTRYINDEX, LUAOC_REG_FUNC_TABLE); // save in LUA_REGISTRYINDEX

    return 1;
}

