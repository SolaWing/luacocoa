//
//  class_test.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "luaoc.h"
#import "luaoc_class.h"
#import "lauxlib.h"

#import <objc/runtime.h>

#define RAW_STR(...) #__VA_ARGS__

void print_register_class(){
  unsigned int c;
  Class* p = objc_copyClassList(&c);
  for (int i = 0; i<c; ++i){
    printf("%s\n", class_getName(*(p+i)));
  }
  free(p);
}

@interface class_test : XCTestCase

@end

@implementation class_test

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

- (void)testExample {
  // luaL_dostring(gLua_main_state, "a = 123; print(a); _ENV={print=print,a=333}; print(22,a)");

    // This is an example of a functional test case.
#define CMethod(cls, name) class_getClassMethod([cls class], @selector(name))
#define IMethod(cls, name) class_getInstanceMethod([cls class], @selector(name))
  Method m[] = {
    CMethod(NSObject, class),
    IMethod(NSObject, class),
    CMethod(NSObject, isSubclassOfClass:),
    IMethod(NSObject, methodForSelector:),
    IMethod(NSObject, init),
    CMethod(NSObject, copyWithZone:),
    IMethod(NSObject, dealloc),
    CMethod(NSObject, conformsToProtocol:),
    CMethod(NSObject, description),
  };
  for (int i = 0; i < sizeof(m)/sizeof(Method); ++i) {
    NSLog(@"method %d encode: %s", i, method_getTypeEncoding(m[i]));
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

@end
