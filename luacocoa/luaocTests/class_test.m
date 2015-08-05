//
//  class_test.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

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
  luaL_dostring(gLua_main_state, "a=function (b) end print(a) a.name = 'ss' print(a.name, ' is') return a");
  NSLog(@"%s", lua_tostring(gLua_main_state, -1)); // error, function can't use as table

  Class meta1 = object_getClass([NSObject class]);
  Class meta2 = objc_getMetaClass("NSObject");
  XCTAssertEqual(meta1, meta2);
  XCTAssertNotEqual([NSObject class], meta1);
  Method mtd = class_getClassMethod(meta1, @selector(isSubclassOfClass:));
  Method mtd2 = class_getClassMethod([NSObject class], @selector(isSubclassOfClass:));
  XCTAssertEqual(mtd, mtd2);
  mtd = class_getInstanceMethod(meta1, @selector(class));
  mtd2 = class_getInstanceMethod([NSObject class], @selector(class));
  XCTAssertNotEqual(mtd, mtd2);
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
    IMethod(NSArray, enumerateObjectsUsingBlock:),
  };
  const char * encode = @encode(dispatch_block_t); // @?
  NSLog(@"block encode: %s", encode);
  encode = @encode(id(*)(int, id, double));  // ^?
  NSLog(@"function pointer encode: %s", encode);
  NSMethodSignature* sign = [NSArray instanceMethodSignatureForSelector: @selector(enumerateObjectsUsingBlock:)];
  NSLog(@"sign : %s", [sign getArgumentTypeAtIndex:2]);
  for (int i = 0; i < sizeof(m)/sizeof(Method); ++i) {
    NSLog(@"method %d encode: %s", i, method_getTypeEncoding(m[i]));
  }

  dispatch_block_t b = ^{};
  [b retainCount];
}

@end
