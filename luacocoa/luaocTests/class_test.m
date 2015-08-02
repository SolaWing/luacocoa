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

@end
