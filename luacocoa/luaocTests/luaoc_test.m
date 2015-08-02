//
//  luaoc_test.m
//  luaoc
//
//  Created by Wangxh on 15/8/1.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "luaoc.h"
#import "lauxlib.h"
#import "luaoc_helper.h"
#import "luaoc_instance.h"
#import "luaoc_class.h"
#import "luaoc_struct.h"
#import <objc/runtime.h>

#define PP_IDENTITY(...) __VA_ARGS__
#define RAW_STR(...) #__VA_ARGS__

@interface luaoc_test : XCTestCase

@end

@implementation luaoc_test

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    luaoc_setup();
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    luaoc_close();
}

- (void)testPushobj {
  /** push obj */
  UIView *view = [[UIView new] autorelease];
  XCTAssertEqual([view retainCount], 1);

  luaoc_push_obj(gLua_main_state, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua should retain the pushed obj");

  luaoc_push_obj(gLua_main_state, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua should only retain same obj once");

  XCTAssertTrue(lua_rawequal(gLua_main_state, -1, -2), "same obj is same userdata");
  XCTAssertEqual(*(id*)lua_touserdata(gLua_main_state, -1), view, "userdata should ref to pushed obj");

  lua_pop(gLua_main_state, 2);
  lua_gc(gLua_main_state, LUA_GCCOLLECT, 0);
  XCTAssertEqual([view retainCount], 1, "after full gc, lua should release retained obj");

#define TEST_PUSH(encoding, type, val, ...)                             \
  {                                                                     \
    char encodingStr[] = encoding;                                      \
    type v = val;                                                       \
    luaoc_push_obj(gLua_main_state, encodingStr, &v);                   \
    __VA_ARGS__                                                         \
    lua_pop(gLua_main_state, 1);                                        \
  }

#define TEST_PUSH_SINGLE(encoding, ...) TEST_PUSH(PP_IDENTITY({encoding, 0}), __VA_ARGS__)
#define TEST_PUSH_VALUE(lua_func, encoding, type, val, ...)                       \
  TEST_PUSH_SINGLE(encoding, type, val,                                           \
      XCTAssertEqual(lua_func(gLua_main_state, -1), val, #type "test push fail"); \
      __VA_ARGS__ )

#define TEST_PUSH_BOOL(val) TEST_PUSH_VALUE(lua_toboolean, _C_BOOL, bool, val, \
    XCTAssertTrue(lua_isboolean(gLua_main_state, -1), "should push bool type"); )
#define TEST_PUSH_INTEGER(encoding, type, val) TEST_PUSH_VALUE(lua_tointeger, encoding, type, val)
#define TEST_PUSH_NUMBER(encoding, type, val) TEST_PUSH_VALUE(lua_tonumber, encoding, type, val)
#define TEST_PUSH_CHARPTR(val) TEST_PUSH_SINGLE(_C_CHARPTR, const char*, val, \
    XCTAssertTrue(strcmp(lua_tostring(gLua_main_state,-1), val) == 0); )
#define TEST_PUSH_SEL(val) TEST_PUSH_SINGLE(_C_SEL, SEL, @selector(val), \
    XCTAssertTrue(strcmp(lua_tostring(gLua_main_state, -1), #val) == 0); )
#define TEST_PUSH_STRUCT(type, val) TEST_PUSH(@encode(type), type, val,   \
    XCTAssertTrue(memcmp(luaoc_getstruct(gLua_main_state, -1), (void*)&v, sizeof(type)) == 0 ); )

  TEST_PUSH_BOOL   (false)
  TEST_PUSH_BOOL   (true)
  TEST_PUSH_INTEGER(_C_CHR      , char               , -1)
  TEST_PUSH_INTEGER(_C_UCHR     , unsigned char      , 22)
  TEST_PUSH_INTEGER(_C_SHT      , short              , -1000)
  TEST_PUSH_INTEGER(_C_USHT     , unsigned short     , 1000)
  TEST_PUSH_INTEGER(_C_INT      , int                , (int)0xffffffff)
  TEST_PUSH_INTEGER(_C_UINT     , unsigned int       , 0xffffffff)
  TEST_PUSH_INTEGER(_C_LNG      , long               , -1e15)
  TEST_PUSH_INTEGER(_C_ULNG     , unsigned long      , 1e15)
  TEST_PUSH_INTEGER(_C_LNG_LNG  , long long          , -1e17)
  TEST_PUSH_INTEGER(_C_ULNG_LNG , unsigned long long , 1e17)
  TEST_PUSH_NUMBER (_C_FLT      , float              , 3.14f)
  TEST_PUSH_NUMBER (_C_DBL      , double             , 43.23432e100)
  TEST_PUSH_VALUE  (luaoc_toinstance, _C_ID     , id         , view)
  TEST_PUSH_VALUE  (luaoc_toinstance, _C_ID     , id         , NULL)
  TEST_PUSH_VALUE  (luaoc_toclass   , _C_CLASS  , Class      , [UIView class])
  TEST_PUSH_VALUE  (luaoc_toclass   , _C_CLASS  , Class      , NULL)
  TEST_PUSH_VALUE  (lua_touserdata  , _C_PTR    , void*      , &view)
  TEST_PUSH_VALUE  (lua_touserdata  , _C_PTR    , void*      , NULL)
  TEST_PUSH_VALUE  (lua_tostring    , _C_CHARPTR, const char*, NULL)
  TEST_PUSH_CHARPTR("hello")
  TEST_PUSH_CHARPTR("world")
  TEST_PUSH_SEL    (testMsgSend)
  TEST_PUSH_SEL    (isEqual:)
  TEST_PUSH_SEL    (performSelector:withObject:)
  TEST_PUSH_STRUCT (CGRect, ((CGRect){2,3,4,5}))
  TEST_PUSH_STRUCT (CGSize, ((CGSize){2,3}))
  TEST_PUSH_STRUCT (CGPoint, ((CGPoint){.x=0, .y=0}))
}

- (void)testFromLuaObj {
  size_t outSize;
  void* ref;
  NSObject *obj = [[NSObject new] autorelease];

#define TEST_PUSH_AND_COPY(type, val, copy2ID, ...)                              \
  {                                                                              \
    char encoding[] = @encode(type);                                             \
    type v = val;                                                                \
    luaoc_push_obj(gLua_main_state, encoding, &v);                               \
    ref = luaoc_copy_toobjc(gLua_main_state, -1, copy2ID?"@":encoding,&outSize); \
    __VA_ARGS__                                                                  \
    free(ref);                                                                   \
    lua_pop(gLua_main_state, 1);                                                 \
  }
#define TEST_PUSH_AND_COPY_VALUE(type, val, ...) TEST_PUSH_AND_COPY(type, val, 0,   \
    XCTAssertEqual(outSize, sizeof(type), #type " size should be equal");         \
    XCTAssertTrue(memcmp(ref, &v, outSize) == 0, #type "value should be equal");  \
    __VA_ARGS__)

#define TEST_PUSH_AND_COPY_STR(val) TEST_PUSH_AND_COPY(const char*, val, 0, \
    XCTAssertEqual(outSize, sizeof(const char*));                           \
    XCTAssertTrue(strcmp(v, *(char**)ref) == 0); )

  /// push val equal to out val

  TEST_PUSH_AND_COPY_VALUE(bool               , false)
  TEST_PUSH_AND_COPY_VALUE(bool               , true)
  TEST_PUSH_AND_COPY_VALUE(char               , -1)
  TEST_PUSH_AND_COPY_VALUE(unsigned char      , 22)
  TEST_PUSH_AND_COPY_VALUE(short              , -1000)
  TEST_PUSH_AND_COPY_VALUE(unsigned short     , 1000)
  TEST_PUSH_AND_COPY_VALUE(int                , (int)0xffffffff)
  TEST_PUSH_AND_COPY_VALUE(unsigned int       , 0xffffffff)
  TEST_PUSH_AND_COPY_VALUE(long               , -1e15)
  TEST_PUSH_AND_COPY_VALUE(unsigned long      , 1e15)
  TEST_PUSH_AND_COPY_VALUE(long long          , -1e17)
  TEST_PUSH_AND_COPY_VALUE(unsigned long long , 1e17)
  TEST_PUSH_AND_COPY_VALUE(float              , 3.14f)
  TEST_PUSH_AND_COPY_VALUE(double             , 43.23432e100)
  TEST_PUSH_AND_COPY_VALUE(NSObject*          , obj);
  TEST_PUSH_AND_COPY_VALUE(NSObject*          , NULL);
  TEST_PUSH_AND_COPY_VALUE(Class              , [NSObject class])
  TEST_PUSH_AND_COPY_VALUE(SEL                , @selector(value:withObjCType:))
  TEST_PUSH_AND_COPY_VALUE(CGRect             , ((CGRect){0,0,320,160}))
  TEST_PUSH_AND_COPY_VALUE(id*                , &obj)
  TEST_PUSH_AND_COPY_STR("hello");          // alloc a new string

  /// test auto convert to id type
#define TEST_PUSH_AND_COPY_TOID(type, val, ...) TEST_PUSH_AND_COPY(type, val, 1, \
    XCTAssertEqual(outSize, sizeof(id), "return size should be sizeof(id)");     \
    __VA_ARGS__)

#define TEST_PUSH_AND_WRAP_VALUE(type, val, sel) TEST_PUSH_AND_COPY_TOID(type, val, \
    XCTAssertEqual([*(id*)ref sel], v);  )

#define TEST_PUSH_AND_WRAP_STR(val) TEST_PUSH_AND_COPY_TOID(const char*, val, \
    XCTAssertEqualObjects(*(id*)ref, @val);  )

#define TEST_PUSH_AND_WRAP_STRUCT(type, val) TEST_PUSH_AND_COPY_TOID(type, val, \
    {type buf; [*(id*)ref getValue:&buf];                                       \
     XCTAssertTrue(memcmp(&buf, &v, sizeof(type)) == 0); })

  TEST_PUSH_AND_WRAP_VALUE(bool, false, boolValue)
  TEST_PUSH_AND_WRAP_VALUE(bool, true, boolValue)
  TEST_PUSH_AND_WRAP_VALUE(char               , -1,         charValue)
  TEST_PUSH_AND_WRAP_VALUE(unsigned char      , 22,         unsignedCharValue)
  TEST_PUSH_AND_WRAP_VALUE(short              , -1000,      shortValue)
  TEST_PUSH_AND_WRAP_VALUE(unsigned short     , 1000,       unsignedShortValue)
  TEST_PUSH_AND_WRAP_VALUE(int                , (int)0xffffffff, intValue)
  TEST_PUSH_AND_WRAP_VALUE(unsigned int       , 0xffffffff,      unsignedIntValue)
  TEST_PUSH_AND_WRAP_VALUE(long               , -1e15,      longValue)
  TEST_PUSH_AND_WRAP_VALUE(unsigned long      , 1e15 ,      unsignedLongValue)
  TEST_PUSH_AND_WRAP_VALUE(long long          , -1e17,      longLongValue)
  TEST_PUSH_AND_WRAP_VALUE(unsigned long long , 1e17,       unsignedLongLongValue)
  TEST_PUSH_AND_WRAP_VALUE(float              , 3.14f,      floatValue)
  TEST_PUSH_AND_WRAP_VALUE(double             , 43.234e100, doubleValue)
  TEST_PUSH_AND_WRAP_STR("hello")
  TEST_PUSH_AND_WRAP_STR("world")
  TEST_PUSH_AND_WRAP_STRUCT(CGPoint, ((CGPoint){33,44}))
  TEST_PUSH_AND_WRAP_STRUCT(UIEdgeInsets, ((UIEdgeInsets){33,44,37,24}))

  {
    luaL_dostring(gLua_main_state, RAW_STR( return {5,6,{a=2,b=3},a=1,b=2,c=3} ));
    ref = luaoc_copy_toobjc(gLua_main_state, -1, "@", &outSize);

    XCTAssertEqual([(*(id*)ref)[@"a"]     intValue], 1);
    XCTAssertEqual([(*(id*)ref)[@"b"]     intValue], 2);
    XCTAssertEqual([(*(id*)ref)[@"c"]     intValue], 3);
    XCTAssertEqual([(*(id*)ref)[@1]       intValue], 5);
    XCTAssertEqual([(*(id*)ref)[@2]       intValue], 6);
    XCTAssertEqual([(*(id*)ref)[@3][@"a"] intValue], 2);
    XCTAssertEqual([(*(id*)ref)[@3][@"b"] intValue], 3);

    lua_pop(gLua_main_state, 1); free(ref);
  }

  {
    luaL_dostring(gLua_main_state, RAW_STR( return {10,11,12, oc.class.UIView, {1,2}, {a=3}} ));
    ref = luaoc_copy_toobjc(gLua_main_state, -1, "@", &outSize);

    // when auto convert array , begin from 0. in lua, begin from 1
    XCTAssertEqual( [(*(id*)ref)[0]       intValue], 10);
    XCTAssertEqual( [(*(id*)ref)[1]       intValue], 11);
    XCTAssertEqual( [(*(id*)ref)[2]       intValue], 12);
    XCTAssertEqual( [(*(id*)ref)[4][0]    intValue], 1);
    XCTAssertEqual( [(*(id*)ref)[4][1]    intValue], 2);
    XCTAssertEqual( [(*(id*)ref)[5][@"a"] intValue], 3);
    XCTAssertEqual( (*(id*)ref)[3]                 , [UIView class]);

    lua_pop(gLua_main_state, 1); free(ref);
  }

}

- (void)testClass {
  // print_register_class();
  // need to use class, or link UIKit. or objc_getClass return nil
  XCTAssertEqual(lua_gettop(gLua_main_state), 0);

  /** PUSH CLASS */
  int startIndex = lua_gettop(gLua_main_state);
  luaoc_push_class(gLua_main_state, [UIView class]);
  XCTAssertEqual(startIndex+1, lua_gettop(gLua_main_state), "stack should only add 1");

  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [UIView class], "should be UIView class ptr");

  luaoc_push_class(gLua_main_state, [UIView class]);
  XCTAssertEqual(startIndex+2, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertTrue(lua_rawequal(gLua_main_state, -1, -2), "some class should have some userdata");

  luaoc_push_class(gLua_main_state, nil);
  XCTAssertEqual(startIndex+3, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertTrue(lua_isnil(gLua_main_state, -1), "nil class should return nil");

  luaoc_push_class(gLua_main_state, [NSObject class]);
  XCTAssertEqual(startIndex+4, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertFalse(lua_rawequal(gLua_main_state, -1, -2), "different class should have different userdata");
  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [NSObject class], "should be NSObject ptr");

  XCTAssertEqual(luaoc_toclass(gLua_main_state, startIndex+1), [UIView class], "shouldn't break exist stack");

  /** LUA index CLASS */
  luaL_dostring(gLua_main_state, "return oc.class.NSObject");
  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [NSObject class], "should return NSObject class userdata");

  luaL_dostring(gLua_main_state, "return oc.class.UnknownClass");
  XCTAssertTrue(lua_isnil(gLua_main_state, -1));

  /** LUA get class name */
  luaL_dostring(gLua_main_state, "return oc.class.name(oc.class.UIView)");
  XCTAssertTrue(strcmp(lua_tostring(gLua_main_state, -1), "UIView") == 0);
}

- (void)testMsgSend {

}

@end
