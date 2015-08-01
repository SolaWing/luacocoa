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
#import <objc/runtime.h>

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

- (void)testpushobj {
  /** push obj */
  UIView *view = [[UIView new] autorelease];
  XCTAssertEqual([view retainCount], 1);

  luaoc_push_obj(gLua_main_state, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua should retain the pushed obj");

  luaoc_push_obj(gLua_main_state, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua should only retain some obj once");

  XCTAssertTrue(lua_rawequal(gLua_main_state, -1, -2), "some obj is some userdata");
  XCTAssertEqual(*(id*)lua_touserdata(gLua_main_state, -1), view, "userdata should ref to pushed obj");

  lua_pop(gLua_main_state, 2);
  lua_gc(gLua_main_state, LUA_GCCOLLECT, 0);
  XCTAssertEqual([view retainCount], 1, "after full gc, lua should release retained obj");

#define TEST_PUSH_VALUE(lua_func, encoding, type, val, ...)                             \
  {                                                                                     \
    char encodingStr[2] = { encoding, 0};                                               \
    type v = val;                                                                       \
    luaoc_push_obj(gLua_main_state, encodingStr, &v);                                   \
    XCTAssertEqual(lua_func(gLua_main_state, -1), val, #type "test push fail");         \
    __VA_ARGS__                                                                         \
  }
#define TEST_PUSH_BOOL(val) TEST_PUSH_VALUE(lua_toboolean, _C_BOOL, bool, val, \
    XCTAssertTrue(lua_isboolean(gLua_main_state, -1), "should push bool type");)
#define TEST_PUSH_INTEGER(encoding, type, val) TEST_PUSH_VALUE(lua_tointeger, encoding, type, val)
#define TEST_PUSH_NUMBER(encoding, type, val) TEST_PUSH_VALUE(lua_tonumber, encoding, type, val)

  TEST_PUSH_BOOL(false)
  TEST_PUSH_BOOL(true)
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
  TEST_PUSH_NUMBER(_C_FLT       , float              , 3.14f)
  TEST_PUSH_NUMBER(_C_DBL       , double             , 43.23432e100)
}

- (void)testMsgSend {

}
- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
