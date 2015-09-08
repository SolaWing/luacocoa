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
#import <CoreGraphics/CoreGraphics.h>

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

/** [blockABI](http://clang.llvm.org/docs/Block-ABI-Apple.html)
 struct Block_literal_1 {
 void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
 int flags;
 int reserved;
 void (*invoke)(void *, ...);
 struct Block_descriptor_1 {
 unsigned long int reserved;         // NULL
 unsigned long int size;         // sizeof(struct Block_literal_1)
 // optional helper functions
 void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
 void (*dispose_helper)(void *src);             // IFF (1<<25)
 // required ABI.2010.3.16
 const char *signature;                         // IFF (1<<30)
 } *descriptor;
 // imported variables
 };

 enum {
 BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
 BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
 BLOCK_IS_GLOBAL =         (1 << 28),
 BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
 BLOCK_HAS_SIGNATURE =     (1 << 30),
 };
 */
struct _blocktype {
    void* isa;
    int flags;
    int reserved;
    void(*invoke)(void* block);
    void* descriptor;
    id upvalue1;
};

void hackFunc(struct _blocktype* block){
    NSLog(@"hack func call %@", block->upvalue1);
}

CGRect hackFuncID2R(struct _blocktype* block, id obj) {
    NSLog(@"hack func call %@:%@", block->upvalue1, obj);
    return CGRectMake(22,33,44,55);
}

id hackFuncDFI2ID(struct _blocktype*block, double a, float b, int c){
    NSLog(@"hack func 3->1: %lf %f %d", a,b,c);
    return block->upvalue1;
}

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



- (void)testBlock {

    NSString* encoding = @"v@@";
    /* block 结构:
     {
        0:  isa
        8:  0xFFFFFFFFC0000000 (flags?)
        12: 0                  (reserved?)
        16: func(block, ...)
        24: ___block_descriptor_tmp*
        32: upvalue 1
        total: 40
     }
     */

    dispatch_block_t block = ^{
        // capture var save in a block_descriptor, which is the first paramter.
        NSLog(@"%@", encoding);
    };
    void (^block2)() = ^{ NSLog(@"global block"); };
    block();    // block self as first c param
    block2();
    block2 = Block_copy(block2);
    block2();
    void (^block3)(id obj) = ^(id obj){NSLog(@"global obj %@", obj);};
    block3(nil);
    id (^block4)(NSUInteger a, NSUInteger b) = ^id(NSUInteger a, NSUInteger b){
        NSLog(@"block %@ %d %d", encoding, (int)a,(int)b);
        return nil;
    };
    block4(1,2);

    CGRect (^block5)(id aa) = ^(id aa){NSLog(@"block %@", encoding); return CGRectMake(1,0,0,0);};
    block5(nil);
    int (^block6)(CGRect aa) = ^(CGRect aa){return 33;};
    block6(CGRectZero);



    struct _blocktype* hackBlock1 = (struct _blocktype*)block;
    hackBlock1->invoke = (void(*)(void*))hackFunc;
    block();

    hackBlock1 = (void*)block5;
    hackBlock1->invoke = (void(*)(void*))hackFuncID2R;
    CGRect rect = block5(@"hack id2r");
    XCTAssertEqual(memcmp(&rect, &((CGRect){22,33,44,55}), sizeof(CGRect)), 0);

    id(^block7)() = ^{ return [encoding stringByAppendingString:@"encoding"]; };
    hackBlock1 = (void*)block7;
    hackBlock1->invoke = (void(*)(void*))hackFuncDFI2ID;
    id ret = ((id(^)(double,float, int))hackBlock1)(3.3, 4.4, 5);
    XCTAssertEqualObjects(ret, encoding);

    hackBlock1 = (void*)Block_copy(block7);
    hackBlock1->invoke = (void(*)(void*))hackFuncDFI2ID;
    ret = ((id(^)(double,float, int))hackBlock1)(3.3, 4.4, 5);
    XCTAssertEqualObjects(ret, encoding);
    Block_release((id)hackBlock1);
}


float floatFunc(id self, SEL _cmd, ...) {
    va_list ap;
    va_start(ap, _cmd);
    double a = va_arg(ap, double);
    double b = va_arg(ap, double);
    for (int i =0; i< 11;++i){
        long c = va_arg(ap, long);
        c=c;
    }
    va_end(ap);
    return a + b ;
}

void asmFunc(){
//    __asm__("popq %rbp\n\t"
//            "jmp _floatFunc");
//    goto floatFunc;
//    ((void(*)(void))floatFunc)();
}

struct atestStructB {
    short a;
    double_t b;
    float c;
};

struct atestStruct {
    bool a;
    struct atestStructB b;
    bool c;
};

- (void)atestGetSizeAndAlignment {
    NSUInteger size, align;
    const char* ret;
    ret = NSGetSizeAndAlignment(@encode(struct atestStruct), &size, &align);
    NSLog(@"atestStruct ret:%s size:%lu, align:%lu", ret, (unsigned long)size, (unsigned long)align);

    ret = "cislqCISLQfdBv*@#:[4c]{rect={point=ff}{size=ff}}{point=ff}^v^{size=ff}(u=cisl)@?{s=@}";
    while (*ret != '\0') {
        NSLog(@"%s", ret);
        // `?b` not support
        ret = NSGetSizeAndAlignment(ret, &size, &align);
        NSLog(@"size:%lu, align:%lu", (unsigned long)size, (unsigned long)align);
    }
    ret = "c";
    NSLog(@"%s", ret);
    ret = NSGetSizeAndAlignment(ret, NULL, NULL);
    NSLog(@"%s", ret);
}

- (void)atestVa_float {
    id obj = [[NSArray new] autorelease];
    SEL sel = sel_getUid("test:");
    float d;
    // in x64, there is a dedicated XMM register, in ios, seem there is none

    // promote rule only for va_func.
    // this not work, float won't promoted, in x64, this even not got pass.
    d = ((float(*)(id,SEL,float, float))floatFunc)(obj, sel, 33.0, 23.0);
    d = ((float(*)(id,SEL,double,float))floatFunc)(obj, sel, 33.0, 23.0);
    d = ((float(*)(id,SEL,float, char, short, int,long, long,long,long,long,long,long))floatFunc)(obj, sel, 33.0,3,4,5,6,7,8,9,0,1,2);

    // work
    d = floatFunc(obj, sel, 33.0, 44.0, 55.0);
    d = floatFunc(obj, sel, 33.0, 44.0, 22l,33l,44l,55l,66l,77l, 88l, 99l, 00l, 10l);
    XCTAssertEqual(d, 77.0);
    // so the compiler need to know it call va_func first, then va_arg will work.
    d = ((float(*)(id,SEL,float, float))asmFunc)(obj, sel, 33.0, 23.0);
}

- (void)atestExample {
  luaL_dostring(gLua_main_state, "a = 123; print(a,_G); _ENV={_G=_G, print=print,a=334}; print(22,a) print(_ENV, _G)");
  luaL_dostring(gLua_main_state, "a=function (b) end print(a) a.name = 'ss' print(a.name, ' is') return a");
  NSLog(@"%s", lua_tostring(gLua_main_state, -1)); // error, function can't use as table

#define LOG_ENCODING(type) \
    NSLog(@"%s encoding is %s", #type, @encode(type))

    LOG_ENCODING(CGRect);
    LOG_ENCODING(CGPoint);
    LOG_ENCODING(CGSize);


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
