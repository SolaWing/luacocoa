//
//  luaoc_test.m
//  luaoc
//
//  Created by Wangxh on 15/8/1.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "luaoc.h"
#import "lauxlib.h"
#import "luaoc_helper.h"
#import "luaoc_instance.h"
#import "luaoc_class.h"
#import "luaoc_struct.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#define PP_IDENTITY(...) __VA_ARGS__
#define RAW_STR(...) #__VA_ARGS__
#define LUA_CODE RAW_STR
#define RUN_LUA_CODE(...) luaL_dostring(gLua_main_state, LUA_CODE(__VA_ARGS__))
#define RUN_LUA_SAFE_CODE(...) RUN_LUA_SAFE_STR(LUA_CODE(__VA_ARGS__))

// RUN_LUA_SAFE_CODE's code may be convert by macro. so use RUN_LUA_STR to avoid it
#define RUN_LUA_SAFE_STR(str) if (luaL_dostring(gLua_main_state, str)) \
    { printf("%s\n", lua_tostring(gLua_main_state, -1)); lua_pop(gLua_main_state, 1); }

@protocol aTestSuperProtocol <NSObject>

@optional
- (void)proto1;
- (id)proto2:(id)arg;
- (BOOL)proto2:(id)arg arg2:(int)arg2;
- (int)proto3:(id)arg arg2:(int)arg2 arg3:(CGPoint)p;
- (CGFloat)protoFloat:(float)val a2:(double)val2;
- (CGRect)protoRect:(CGRect)rect flt:(float)val dbl:(double)dbl;

@end

@protocol aTestChildProtocol <aTestSuperProtocol>

@optional
- (bool)childProto:(char)ss arg1:(bool)arg1 arg2:(void*)arg2;
+ (int)childProto:(id*)outArg;
+ (CGPoint)childProtoS:(CGPoint)p;
- (float)test:(float)a;

@end

@interface aTestClass : NSMutableArray <aTestChildProtocol>
{
}

@end



@implementation aTestClass

@end

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
  NSObject *view = [[NSObject new] autorelease];
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
  TEST_PUSH_INTEGER(_C_LNG      , long               , -1e9) // 32bit long 4B, 64bit long 8B
  TEST_PUSH_INTEGER(_C_ULNG     , unsigned long      , 1e9)
  TEST_PUSH_INTEGER(_C_LNG_LNG  , long long          , -1e17)
  TEST_PUSH_INTEGER(_C_ULNG_LNG , unsigned long long , 1e17)
  TEST_PUSH_NUMBER (_C_FLT      , float              , 3.14f)
  TEST_PUSH_NUMBER (_C_DBL      , double             , 43.23432e100)
  TEST_PUSH_VALUE  (luaoc_toinstance, _C_ID     , id         , view)
  TEST_PUSH_VALUE  (luaoc_toinstance, _C_ID     , id         , NULL)
  TEST_PUSH_VALUE  (luaoc_toclass   , _C_CLASS  , Class      , [NSArray class])
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
#define TEST_PUSH_AND_COPY_VALUE(type, val, ...) TEST_PUSH_AND_COPY(type, val, 0, \
    XCTAssertEqual(outSize, sizeof(type), #type " size should be equal");         \
    XCTAssertTrue(memcmp(ref, &v, outSize) == 0, #type " value should be equal"); \
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
  TEST_PUSH_AND_WRAP_STRUCT(CGRect, ((CGRect){33,44,37,24}))

  { // auto convert table to NSDictionary
    luaL_dostring(gLua_main_state, LUA_CODE( return {5,6,{a=2,b=3},a=1,b=2,c=3} ));
    ref = luaoc_copy_toobjc(gLua_main_state, -1, "@", &outSize);

    XCTAssertEqual([(*(id*)ref) [@"a"]     intValue], 1);
    XCTAssertEqual([(*(id*)ref) [@"b"]     intValue], 2);
    XCTAssertEqual([(*(id*)ref) [@"c"]     intValue], 3);
    XCTAssertEqual([(*(id*)ref) [@1]       intValue], 5);
    XCTAssertEqual([(*(id*)ref) [@2]       intValue], 6);
    XCTAssertEqual([(*(id*)ref) [@3][@"a"] intValue], 2);
    XCTAssertEqual([(*(id*)ref) [@3][@"b"] intValue], 3);

    lua_pop(gLua_main_state, 1); free(ref);
  }

  { // auto convert table to NSArray
    luaL_dostring(gLua_main_state, LUA_CODE( return {10,11,12, oc.class.NSArray, {1,2}, {a=3}} ));
    ref = luaoc_copy_toobjc(gLua_main_state, -1, "@", &outSize);

    // when auto convert array , begin from 0. in lua, begin from 1
    XCTAssertEqual( [(*(id*)ref) [0]       intValue], 10);
    XCTAssertEqual( [(*(id*)ref) [1]       intValue], 11);
    XCTAssertEqual( [(*(id*)ref) [2]       intValue], 12);
    XCTAssertEqual( [(*(id*)ref) [4][0]    intValue], 1);
    XCTAssertEqual( [(*(id*)ref) [4][1]    intValue], 2);
    XCTAssertEqual( [(*(id*)ref) [5][@"a"] intValue], 3);
    XCTAssertEqual( (*(id*)ref)  [3]                , [NSArray class]);

    lua_pop(gLua_main_state, 1); free(ref);
  }

}

- (void)testClass {
  // print_register_class();
  // need to use class, or link UIKit. or objc_getClass return nil
  XCTAssertEqual(lua_gettop(gLua_main_state), 0);

  /** PUSH CLASS */
  int startIndex = lua_gettop(gLua_main_state);
  luaoc_push_class(gLua_main_state, [NSArray class]);
  XCTAssertEqual(startIndex+1, lua_gettop(gLua_main_state), "stack should only add 1");

  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [NSArray class], "should be NSArray class ptr");

  luaoc_push_class(gLua_main_state, [NSArray class]);
  XCTAssertEqual(startIndex+2, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertTrue(lua_rawequal(gLua_main_state, -1, -2), "some class should have some userdata");

  luaoc_push_class(gLua_main_state, nil);
  XCTAssertEqual(startIndex+3, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertTrue(lua_isnil(gLua_main_state, -1), "nil class should return nil");

  luaoc_push_class(gLua_main_state, [NSObject class]);
  XCTAssertEqual(startIndex+4, lua_gettop(gLua_main_state), "stack should only add 1");
  XCTAssertFalse(lua_rawequal(gLua_main_state, -1, -2), "different class should have different userdata");
  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [NSObject class], "should be NSObject ptr");

  XCTAssertEqual(luaoc_toclass(gLua_main_state, startIndex+1), [NSArray class], "shouldn't break exist stack");

  /** LUA index CLASS */
  luaL_dostring(gLua_main_state, "return oc.class.NSObject");
  XCTAssertEqual(luaoc_toclass(gLua_main_state, -1), [NSObject class], "should return NSObject class userdata");

  luaL_dostring(gLua_main_state, "return oc.class.UnknownClass");
  XCTAssertTrue(lua_isnil(gLua_main_state, -1));

  /** LUA get class name */
  luaL_dostring(gLua_main_state, "return oc.class.name(oc.class.NSArray)");
  XCTAssertTrue(strcmp(lua_tostring(gLua_main_state, -1), "NSArray") == 0);
}

- (void)testMsgSend {
  lua_State* L = gLua_main_state;

  RUN_LUA_SAFE_CODE(return oc.class.NSObject:class());
  XCTAssertEqualObjects(luaoc_toclass(L, -1), [NSObject class]);
  lua_pop(L, 1);

  RUN_LUA_SAFE_CODE(return oc.class.NSObject:description());
  XCTAssertEqualObjects(luaoc_toinstance(L, -1), [NSObject description]);
  lua_pop(L, 1);

  RUN_LUA_SAFE_CODE(return oc.class.NSArray:isSubclassOfClass(oc.class.NSObject));
  // in OSX and 32bit ios, BOOL is signed char type
    XCTAssertEqual(lua_type(L, -1), LUA_TBOOLEAN);
    XCTAssertEqual(lua_toboolean(L, -1), true);
  lua_pop(L, 1);

  RUN_LUA_SAFE_CODE(return oc.class.NSArray:isSubclassOfClass(oc.class.NSDictionary));
  XCTAssertEqual(lua_type(L, -1), LUA_TBOOLEAN);
  XCTAssertEqual(lua_toboolean(L, -1), false);
  lua_pop(L, 1);

  // vararg not support, and may crash.
//  RUN_LUA_SAFE_STR("return oc.class.NSArray:arrayWithObjects(1,2,3,nil)");
//  lua_pop(L, 1);

  RUN_LUA_SAFE_CODE(return oc.class.NSArray:arrayWithArray{1,2,3});
  id val = luaoc_toinstance(L, -1);
  lua_pop(L, 1);
  lua_gc(L, LUA_GCCOLLECT, 0);
  XCTAssertEqual([val retainCount], 1u); // have one autorelease count
  XCTAssertEqualObjects(val[0], @1);
  XCTAssertEqualObjects(val[1], @2);
  XCTAssertEqualObjects(val[2], @3);

  // init obj owned by lua
  RUN_LUA_SAFE_CODE(v = oc.class.NSMutableArray:alloc():init() return v:retainCount());
  XCTAssertEqual(lua_tonumber(L, -1), 1);
  lua_pop(L,1);

  // new obj owned by lua
  RUN_LUA_SAFE_CODE(v = oc.class.NSMutableArray:new() return v:retainCount());
  XCTAssertEqual(lua_tonumber(L, -1), 1);
  lua_pop(L, 1);

  RUN_LUA_SAFE_CODE(v:addObject(1) v:addObject(2) v:addObject(5) return v);
  // in MRC, __weak is no use, so need to use objc_storeWeak
  id weakval; objc_storeWeak(&weakval, luaoc_toinstance(L, -1));
  lua_pop(L, 1);
  XCTAssertEqualObjects(weakval[0], @1);
  XCTAssertEqualObjects(weakval[1], @2);
  XCTAssertEqualObjects(weakval[2], @5);

  RUN_LUA_SAFE_CODE(v:insertObject_atIndex(2, 0));
  XCTAssertEqualObjects(weakval[0], @2);
  XCTAssertEqualObjects(weakval[1], @1);
  XCTAssertEqualObjects(weakval[2], @2);
  XCTAssertEqualObjects(weakval[3], @5);

  RUN_LUA_SAFE_CODE(v:insertObject_atIndex(3)); // if omit, default 0 or NULL
  XCTAssertEqualObjects(weakval[0], @3);
  XCTAssertEqualObjects(weakval[1], @2);

  RUN_LUA_SAFE_CODE(v:removeObjectAtIndex(1));
  RUN_LUA_SAFE_CODE(v:removeObjectAtIndex(1));
  XCTAssertEqual([weakval count], 3);

  RUN_LUA_SAFE_CODE(return oc.class.name(v));
  // 聚合类的实例是该类子类的一个实例
  XCTAssertTrue(strcmp(lua_tostring(L,-1), "__NSArrayM") == 0);
  RUN_LUA_SAFE_CODE(return oc.class.name(v.super));
  // 聚合类的实例是该类子类的一个实例
  XCTAssertTrue(strcmp(lua_tostring(L,-1), "NSMutableArray") == 0);
  lua_pop(L, 2);

  // copy obj retain by lua
  RUN_LUA_SAFE_CODE(v = v:mutableCopy() return v:retainCount());
  XCTAssertEqual(lua_tonumber(L, -1), 1);
  lua_pop(L, 1);

  lua_gc(gLua_main_state, LUA_GCCOLLECT, 0);
  XCTAssertTrue(weakval == NULL, "after reassign v, weakval should be collect");

  /// test error deal
  int ret;
  ret = RUN_LUA_CODE(return oc.class.NSObject:unknownmethod());
  XCTAssertNotEqual(ret, 0);
  printf("%s\n", lua_tostring(L, -1));
  lua_pop(L, 1);

  // should call with receiver as first arguement
  ret = RUN_LUA_CODE(return oc.class.NSObject.class());
  XCTAssertNotEqual(ret, 0);
  printf("%s\n", lua_tostring(L,-1));
  lua_pop(L, 1);

  // wrong receiver type, must be id or class
  ret = RUN_LUA_CODE(return oc.class.NSObject.class(oc));
  XCTAssertNotEqual(ret, 0);
  printf("%s\n", lua_tostring(L,-1));
  lua_pop(L, 1);
}

- (void)testOverride {
  lua_State* L = gLua_main_state;
  RUN_LUA_SAFE_CODE(return oc.class.aTestClass("proto1", function() aret=1 end));
  XCTAssertTrue(lua_toboolean(L, -1));

  aTestClass* obj = [[aTestClass new] autorelease];
  [obj proto1];

  RUN_LUA_SAFE_CODE(return aret);
  XCTAssertEqual(lua_tonumber(L, -1), 1);

  RUN_LUA_SAFE_CODE(return oc.class.aTestClass("proto2:", function(self,obj) return self == obj and self or obj end));
  XCTAssertTrue(lua_toboolean(L, -1));

  XCTAssertEqual([obj proto2:NULL], NULL);
  XCTAssertEqual([obj proto2:obj], obj);
  XCTAssertEqual([obj proto2:[NSArray class]], [NSArray class]);

  RUN_LUA_SAFE_CODE(return oc.class.aTestClass("proto3:arg2:arg3:", function(self, obj, num, p) return num*2 end));
  XCTAssertTrue(lua_toboolean(L, -1));

  // XCTAssertEqual([obj proto3:obj arg2:44 arg3:CGPointMake(33,55)], 88);

  RUN_LUA_SAFE_CODE(oc.class.aTestClass("+ childProtoS:", function(cls, p) return p end));
   CGPoint a = CGPointMake(44,55);
   a = [aTestClass childProtoS:a];
   XCTAssertEqual(a.x, 44);
   XCTAssertEqual(a.y, 55);

  RUN_LUA_SAFE_CODE(oc.class.aTestClass("protoFloat:a2:", function(self, f1, f2) return f1+f2 end));
  XCTAssertEqualWithAccuracy([obj protoFloat:1.2f a2:2], 3.2, 0.001);

  RUN_LUA_SAFE_CODE(oc.class.aTestClass("protoRect:flt:dbl:", function(self, rect, f1, f2) aret=f1*f2  return rect end));
  CGRect b = CGRectMake(3,5,22,33);
  b = [obj protoRect:b flt:22 dbl:4];
  XCTAssertEqual(b.origin.x, 3);
  XCTAssertEqual(b.origin.y, 5);
  XCTAssertEqual(b.size.width, 22);
  XCTAssertEqual(b.size.height, 33);
  RUN_LUA_SAFE_CODE(return aret);
  XCTAssertEqual(lua_tonumber(L, -1), 88);
}

- (void)testStruct {
  // create struct
  RUN_LUA_SAFE_CODE( a = oc.struct.CGRect({33,44}, {55,66}); return a );
  CGRect rect;
  luaoc_tostruct(gLua_main_state, -1, &rect);
  XCTAssertEqual(rect.origin.x, 33);
  XCTAssertEqual(rect.origin.y, 44);
  XCTAssertEqual(rect.size.width, 55);
  XCTAssertEqual(rect.size.height, 66);

  // index struct
  RUN_LUA_SAFE_CODE( return a.x+a.y );
  XCTAssertEqual(77, lua_tonumber(gLua_main_state, -1));

  RUN_LUA_SAFE_CODE( return a.size.width + a.size.height );
  XCTAssertEqual(121, lua_tonumber(gLua_main_state, -1));

  // set struct value
  RUN_LUA_SAFE_CODE( a.x = 10; a.width = 20; return a.x * a.width, a);
  XCTAssertEqual(200, lua_tonumber(gLua_main_state, -2));

  luaoc_tostruct(gLua_main_state, -1, &rect);
  XCTAssertEqual(rect.origin.x, 10);
  XCTAssertEqual(rect.size.width, 20);

  // not work, a.size return a new CGSize struct, not the origin one
  RUN_LUA_SAFE_CODE( a.size.height = 100; return a.size.height );
  XCTAssertNotEqual(100, lua_tonumber(gLua_main_state, -1));

  // index by offset, offset begin at 1
  RUN_LUA_SAFE_CODE(return a[1][2] + a[2][2]);
  XCTAssertEqual(110, lua_tonumber(gLua_main_state, -1));

  RUN_LUA_SAFE_CODE(a[1] = {1,1}; return a[1]);
  CGPoint p;
  luaoc_tostruct(gLua_main_state, -1, &p);
  XCTAssertEqual(1, p.x);
  XCTAssertEqual(1, p.y);

  lua_settop(gLua_main_state, 0);

  /** REG NEW CUSTOM STRUCT, it's a block with given  */
  RUN_LUA_SAFE_CODE( oc.struct.reg('p',
              {'x', oc.encoding.CGFloat}, {'y', oc.encoding.CGFloat}) );
  // RUN_LUA_SAFE_STR(" luaoc.struct.reg('p',"
  //     "{'x', luaoc.encoding.CGFloat}, {'y', luaoc.encoding.CGFloat})");
  RUN_LUA_SAFE_CODE( return oc.struct.p{33,44} );
  luaoc_tostruct(gLua_main_state, -1, &p);
  XCTAssertEqual(33, p.x);
  XCTAssertEqual(44, p.y);
}
@end
