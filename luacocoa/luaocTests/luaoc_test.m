//
//  luaoc_test.m
//  luaoc
//
//  Created by SolaWing on 15/8/1.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "luaoc.h"
#import "lauxlib.h"
#import "luaoc_helper.h"
#import "luaoc_instance.h"
#import "luaoc_class.h"
#import "luaoc_struct.h"
#import "luaoc_block.h"
#import "luaoc_func.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreData/CoreData.h>

#define PP_IDENTITY(...) __VA_ARGS__
#define RAW_STR(...) #__VA_ARGS__
#define LUA_CODE RAW_STR
#define RUN_LUA_CODE(...) luaL_dostring(gLua_main_state, LUA_CODE(__VA_ARGS__))
#define RUN_LUA_SAFE_CODE(...) RUN_LUA_SAFE_STR(LUA_CODE(__VA_ARGS__))

// RUN_LUA_SAFE_CODE's code may be convert by macro. so use str to avoid it
#define RUN_LUA_SAFE_STR(str) if (luaL_dostring(gLua_main_state, str) != 0) \
    { printf("%s\n", lua_tostring(gLua_main_state, -1)); lua_pop(gLua_main_state, 1); }

@protocol aTestSuperProtocol <NSObject>

@optional
- (void)proto_void;
- (id)id_proto2_id:(id)arg;
- (BOOL)BOOL_proto2_id:(id)arg arg_int:(int)arg2;
- (int)int_proto3_id:(id)arg arg_int:(int)arg2 arg_point:(CGPoint)p;
- (CGFloat)flt_proto_flt:(float)val dbl:(double)val2;
- (CGRect)rect_proto_rect:(CGRect)rect flt:(float)val dbl:(double)dbl;

@end

@protocol aTestChildProtocol <aTestSuperProtocol>

@optional
- (bool)bool_childProto_char:(char)ss bool:(bool)arg1 ptr:(void*)arg2;
+ (int)int_childProto_idPtr:(id*)outArg;
+ (CGPoint)point_childProto_point:(CGPoint)p;

@end

@interface aTestClass : NSMutableArray <aTestChildProtocol>
{
}


@end



@implementation aTestClass

- (void)dealloc {
    // autorelease deallocing obj will cause crash. the same as lua gc and
    // release obj
    // [[self retain] autorelease];
    [super dealloc];
}

- (instancetype)init {
    // NSLog(@"init %p count:%zu", self, (size_t)[self retainCount]);
    return [super init];
}


+ (void)testPassBlock:(void(^)(void))block {
    block();
}

+ (id)testPassBlock:(id(^)(id))block ID:(id)obj  {
    return block(obj);
}

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

#pragma mark - test begin
- (void)testPushobj {
  lua_State *L = gLua_main_state;
  /** push obj */
  NSObject *view = [NSObject new];
  XCTAssertEqual([view retainCount], 1);

  luaoc_push_obj(L, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua retain the pushed obj");

  luaoc_push_obj(L, "@", &view);
  XCTAssertEqual([view retainCount], 2, "lua retain the pushed obj once");

  LUAOC_RETAIN(L, -1);
  LUAOC_RELEASE(L, -1);
  LUAOC_RELEASE(L, -1);
  XCTAssertEqual([view retainCount], 1, "lua only has one autoretain, should release the obj after call LUAOC_RELEASE");

  LUAOC_TAKE_OWNERSHIP(L, -1);
  XCTAssertEqual([view retainCount], 1, "lua will release the obj in gc after call LUAOC_TAKE_OWNERSHIP");

  luaoc_push_obj(L, "@", &view);
  XCTAssertTrue(lua_rawequal(L, -1, -2), "same obj is same userdata");
  XCTAssertEqual(*(id*)lua_touserdata(L, -1), view, "userdata should ref to pushed obj");

  [view retain]; LUAOC_TAKE_OWNERSHIP(L, -2);
  [[view retain] autorelease];
  lua_settop(L, 0);
  lua_gc(L, LUA_GCCOLLECT, 0);
  XCTAssertEqual([view retainCount], 1, "after full gc, lua should release retained obj");

#define TEST_PUSH(encoding, type, val, ...)                             \
  {                                                                     \
    char encodingStr[] = encoding;                                      \
    type v = val;                                                       \
    luaoc_push_obj(L, encodingStr, &v);                   \
    __VA_ARGS__                                                         \
    lua_pop(L, 1);                                        \
  }

#define TEST_PUSH_SINGLE(encoding, ...) TEST_PUSH(PP_IDENTITY({encoding, 0}), __VA_ARGS__)
#define TEST_PUSH_VALUE(lua_func, encoding, type, val, ...)                       \
  TEST_PUSH_SINGLE(encoding, type, val,                                           \
      XCTAssertEqual(lua_func(L, -1), val, #type "test push fail"); \
      __VA_ARGS__ )

#define TEST_PUSH_BOOL(val) TEST_PUSH_VALUE(lua_toboolean, _C_BOOL, bool, val, \
    XCTAssertTrue(lua_isboolean(L, -1), "should push bool type"); )
#define TEST_PUSH_INTEGER(encoding, type, val) TEST_PUSH_VALUE(lua_tointeger, encoding, type, val)
#define TEST_PUSH_NUMBER(encoding, type, val) TEST_PUSH_VALUE(lua_tonumber, encoding, type, val)
#define TEST_PUSH_CHARPTR(val) TEST_PUSH_SINGLE(_C_CHARPTR, const char*, val, \
    XCTAssertTrue(strcmp(lua_tostring(L,-1), val) == 0); )
#define TEST_PUSH_SEL(val) TEST_PUSH_SINGLE(_C_SEL, SEL, @selector(val), \
    XCTAssertTrue(strcmp(lua_tostring(L, -1), #val) == 0); )
#define TEST_PUSH_STRUCT(type, val) TEST_PUSH(@encode(type), type, val,   \
    XCTAssertTrue(memcmp(luaoc_getstruct(L, -1), (void*)&v, sizeof(type)) == 0 ); )

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
  TEST_PUSH_VALUE  (luaoc_toinstance, _C_ID     , id         , [NSArray class]) // sometimes class is used as id
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

  // test tolua func
  lua_settop(L, 0);
  RUN_LUA_SAFE_CODE( return oc.tolua( oc.var('@', 'abc'), oc.var('@', 1),
              oc.var('@', {1}), oc.var('@', {a=2}), oc.var('@'), oc.var(oc.encode.CGPoint),
              oc.CGSize(32,23), oc.CGRect({11,22}, {33,44})) )
  XCTAssertTrue(strcmp(lua_tostring(L,1), "abc") == 0);
  XCTAssertEqual(lua_tointeger(L, 2), 1);
  XCTAssertTrue(lua_type(L,3) == LUA_TTABLE && (lua_rawgeti(L, 3, 1), lua_tointeger(L, -1) == 1));
  XCTAssertTrue(lua_type(L,4) == LUA_TTABLE && (lua_rawgetfield(L, 4, "a"), lua_tointeger(L, -1) == 2));
  XCTAssertTrue(lua_isnil(L,5));
  XCTAssertTrue(lua_type(L,6) == LUA_TTABLE &&
          (lua_rawgeti(L, 6, 1), lua_tonumber(L, -1) == 0) &&
          (lua_rawgeti(L, 6, 2), lua_tonumber(L, -1) == 0) );
  XCTAssertTrue(lua_type(L,7) == LUA_TTABLE &&
          (lua_rawgeti(L, 7, 1), lua_tonumber(L, -1) == 32) &&
          (lua_rawgeti(L, 7, 2), lua_tonumber(L, -1) == 23) );
  XCTAssertTrue(lua_type(L,8) == LUA_TTABLE &&
          (lua_rawgeti(L, 8, 1), lua_rawgeti(L, -1, 1), lua_tonumber(L, -1) == 11) &&
                                (lua_rawgeti(L, -2, 2), lua_tonumber(L, -1) == 22) &&
          (lua_rawgeti(L, 8, 2), lua_rawgeti(L, -1, 1), lua_tonumber(L, -1) == 33) &&
                                (lua_rawgeti(L, -2, 2), lua_tonumber(L, -1) == 44));

    lua_settop(L, 0);
}

- (void)testFromLuaObj {
  lua_State *L = gLua_main_state;
  size_t outSize;
  void* ref;
  NSObject *obj = [[NSObject new] autorelease];

#define TEST_PUSH_AND_COPY(type, val, copy2ID, ...)                              \
  {                                                                              \
    char encoding[] = @encode(type);                                             \
    type v = val;                                                                \
    luaoc_push_obj(L, encoding, &v);                               \
    ref = luaoc_copy_toobjc(L, -1, copy2ID?"@":encoding,&outSize); \
    __VA_ARGS__                                                                  \
    free(ref);                                                                   \
    lua_pop(L, 1);                                                 \
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

  // a table which has both key and num index will be converted to
  // array or dict is undefined
  // empty table will convert to nil obj
  //
  { // auto convert table to NSDictionary
    RUN_LUA_SAFE_CODE( return {a=1,b=2,c=3, d={1,2,3,{33,44}},
            e=oc.NSRange{3,5}, f=oc.var('@',{3}), g=oc.var('i', 22) } );
    ref = luaoc_copy_toobjc(L, -1, "@", &outSize);

    XCTAssertEqual([(*(id*)ref) [@"a"]     intValue], 1);
    XCTAssertEqual([(*(id*)ref) [@"b"]     intValue], 2);
    XCTAssertEqual([(*(id*)ref) [@"c"]     intValue], 3);
    XCTAssertEqual([(*(id*)ref) [@"d"][0]  intValue], 1);
    XCTAssertEqual([(*(id*)ref) [@"d"][1]  intValue], 2);
    XCTAssertEqual([(*(id*)ref) [@"d"][2]  intValue], 3);
    XCTAssertEqual([(*(id*)ref) [@"d"][3][1] intValue], 44);
    XCTAssertEqualObjects( (*(id*)ref)[@"e"], [NSValue valueWithRange:NSMakeRange(3,5)]);
    XCTAssertTrue( [@[@3] isEqualToArray:(*(id*)ref)[@"f"]] );
    XCTAssertEqual([(*(id*)ref) [@"g"]     intValue], 22);

    lua_pop(L, 1); free(ref);
  }

  { // auto convert table to NSArray
    RUN_LUA_SAFE_CODE( return {10,11,12, oc.class.NSArray, {1,2}, {a=3}, {}, 'abc'} );
    ref = luaoc_copy_toobjc(L, -1, "@", &outSize);

    // when auto convert array , begin from 0. in lua, begin from 1
    XCTAssertEqual( [(*(id*)ref) [0]       intValue], 10);
    XCTAssertEqual( [(*(id*)ref) [1]       intValue], 11);
    XCTAssertEqual( [(*(id*)ref) [2]       intValue], 12);
    XCTAssertEqual( [(*(id*)ref) [4][0]    intValue], 1);
    XCTAssertEqual( [(*(id*)ref) [4][1]    intValue], 2);
    XCTAssertEqual( [(*(id*)ref) [5][@"a"] intValue], 3);
    XCTAssertEqual( (*(id*)ref)  [3]                , [NSArray class]);
    XCTAssertEqual( (*(id*)ref)  [6]       , [NSNull null]);
    XCTAssertEqualObjects( (*(id*)ref)[7], @"abc" );

    lua_pop(L, 1); free(ref);
  }

  { // empty table will convert to nil
      RUN_LUA_SAFE_CODE( return {} );
      ref = luaoc_copy_toobjc(L, -1, "@", &outSize);
      XCTAssertNil(*(id*)ref);
      free(ref);
  }

  { // auto convert table to struct
    RUN_LUA_SAFE_CODE( return {{30, 40}, oc.var(oc.encode.CGPoint, {50,60})} );
    ref = luaoc_copy_toobjc(L, -1, @encode(CGRect), &outSize);
    CGRect rect = {30,40,50,60};
    XCTAssertTrue( memcmp(ref, &rect, sizeof(CGRect)) == 0 );
    lua_settop(L, 0); free(ref);
  }

  { // auto convert to ptr
      RUN_LUA_SAFE_CODE( return oc.NSObject );
      ref = luaoc_copy_toobjc(L, -1, @encode(void*), &outSize);
      XCTAssertEqual(*(Class*)ref, [NSObject class]);
      lua_settop(L, 0); free(ref);

      RUN_LUA_SAFE_CODE( return oc.aTestClass );
      ref = luaoc_copy_toobjc(L, -1, @encode(void*), &outSize);
      XCTAssertEqual([*(id*)ref class], [aTestClass class]);
      lua_settop(L, 0); free(ref);

      RUN_LUA_SAFE_CODE( return oc.var("#", "NSArray") ); // NSArray autoconvert to class
      ref = luaoc_copy_toobjc(L, -1, @encode(void*), &outSize);
      XCTAssertEqual(**(Class**)ref, [NSArray class]);
      lua_settop(L, 0); free(ref);

      {
          RUN_LUA_SAFE_CODE( a = oc.var("@", 1) return a );
          ref = luaoc_copy_toobjc(L, -1, @encode(void*), &outSize);
          XCTAssertEqual([**(id**)ref intValue], 1);
          **(id**)ref = NULL;

          RUN_LUA_SAFE_CODE( return oc.getvar(a) );
          XCTAssertTrue( lua_isnil(L, -1) ); // value already set NULL;
          **(id**)ref = [NSArray class];

          RUN_LUA_SAFE_CODE( return oc.getvar(a) ); // value be set to [NSArray class];
          XCTAssertEqual( luaoc_toinstance(L, -1), [NSArray class]);

          lua_settop(L, 0); free(ref);
      }

      // autoconvert string to ptr
      lua_pushstring(L, "hello");
      ref = luaoc_copy_toobjc(L, -1, @encode(void*), &outSize);
      XCTAssertEqual(0, strcmp("hello", *(const char**)ref));
      lua_settop(L, 0); free(ref);
  }

}

- (void)testClass {
  lua_State *L = gLua_main_state;
  // print_register_class();
  // need to use class, or link UIKit. or objc_getClass return nil
  XCTAssertEqual(lua_gettop(L), 0);

  /** PUSH CLASS */
  int startIndex = lua_gettop(L);
  luaoc_push_class(L, [NSArray class]);
  XCTAssertEqual(startIndex+1, lua_gettop(L), "stack should only add 1");

  XCTAssertEqual(luaoc_toclass(L, -1), [NSArray class], "should be NSArray class ptr");

  luaoc_push_class(L, [NSArray class]);
  XCTAssertEqual(startIndex+2, lua_gettop(L), "stack should only add 1");
  XCTAssertTrue(lua_rawequal(L, -1, -2), "some class should have some userdata");

  luaoc_push_class(L, nil);
  XCTAssertEqual(startIndex+3, lua_gettop(L), "stack should only add 1");
  XCTAssertTrue(lua_isnil(L, -1), "nil class should return nil");

  luaoc_push_class(L, [NSObject class]);
  XCTAssertEqual(startIndex+4, lua_gettop(L), "stack should only add 1");
  XCTAssertFalse(lua_rawequal(L, -1, -2), "different class should have different userdata");
  XCTAssertEqual(luaoc_toclass(L, -1), [NSObject class], "should be NSObject ptr");

  XCTAssertEqual(luaoc_toclass(L, startIndex+1), [NSArray class], "shouldn't break exist stack");

  /** LUA index CLASS */
  RUN_LUA_SAFE_STR( "return oc.class.NSObject");
  XCTAssertEqual(luaoc_toclass(L, -1), [NSObject class], "should return NSObject class userdata");

  RUN_LUA_SAFE_STR( "return oc.class.UnknownClass");
  XCTAssertTrue(lua_isnil(L, -1));

  /** LUA get class name */
  RUN_LUA_SAFE_STR( "return oc.class.name(oc.class.NSArray)");
  XCTAssertTrue(strcmp(lua_tostring(L, -1), "NSArray") == 0);
  lua_settop(L, 0);
}

- (void)testOverride {
  lua_State* L = gLua_main_state;
  id obj;
  char buf[32];
  { // override protocol
      RUN_LUA_SAFE_CODE(return oc.class.aTestClass("proto_void", function() aret=1 end));
      XCTAssertTrue(lua_toboolean(L, -1));

      obj = [[aTestClass new] autorelease];
      [obj proto_void];

      RUN_LUA_SAFE_CODE(return aret);
      XCTAssertEqual(lua_tonumber(L, -1), 1);
  }

  { // override protocol and have param
      RUN_LUA_SAFE_CODE(return oc.class.aTestClass("id_proto2_id:", function(self,obj) return self == obj and self or obj end));
      XCTAssertTrue(lua_toboolean(L, -1));

      XCTAssertEqual([obj id_proto2_id:NULL], NULL);
      XCTAssertEqual([obj id_proto2_id:obj], obj);
      XCTAssertEqual([obj id_proto2_id:[NSArray class]], [NSArray class]);
  }

  { // override protocol and have struct param
      RUN_LUA_SAFE_CODE(return oc.class.aTestClass("int_proto3_id:arg_int:arg_point:", function(self, obj, num, p) return num*2 + p.x-p.y end));
      XCTAssertTrue(lua_toboolean(L, -1));

      XCTAssertEqual([obj int_proto3_id:obj arg_int:44 arg_point:CGPointMake(33,55)], 66);
  }

  { // override protocol and return struct
      RUN_LUA_SAFE_CODE(oc.class.aTestClass("+ point_childProto_point:", function(cls, p) return p end));
      CGPoint a = CGPointMake(44,55);
      a = [aTestClass point_childProto_point:a];
      XCTAssertEqual(a.x, 44);
      XCTAssertEqual(a.y, 55);
  }

  { // override protocol and have float and double param, return float
      RUN_LUA_SAFE_CODE(oc.class.aTestClass("flt_proto_flt:dbl:", function(self, f1, f2) return f1+f2 end));
      XCTAssertEqualWithAccuracy([obj flt_proto_flt:1.2f dbl:2], 3.2, 0.001);
  }

  { // override protocol, use struct float param, return struct
      RUN_LUA_SAFE_CODE(oc.class.aTestClass("rect_proto_rect:flt:dbl:", function(self, rect, f1, f2) aret=f1*f2  return rect end));
      CGRect b = CGRectMake(3,5,22,33);
      b = [obj rect_proto_rect:b flt:22 dbl:4];
      XCTAssertEqual(b.origin.x, 3);
      XCTAssertEqual(b.origin.y, 5);
      XCTAssertEqual(b.size.width, 22);
      XCTAssertEqual(b.size.height, 33);
      RUN_LUA_SAFE_CODE(return aret);
      XCTAssertEqual(lua_tonumber(L, -1), 88);
  }
  { /// add method to exist class
      // override SEL can be any valid C functionName! not limit to Objc name
      // style. but for compatible, recommand use : to mark param
      RUN_LUA_SAFE_CODE( oc.class.aTestClass("abcd",
                  function(self, rect, f1, f2) aret = f1*f2 rect.x=33 rect.y=44 return rect end,
                  {'CGRect', 'id', 'SEL', 'CGRect', 'NSInteger', 'CGFloat'}));
      RUN_LUA_SAFE_CODE( a = oc.aTestClass:new() a = a:abcd({{22,33},{11,12}}, 3.3, 2.2) return a, aret );
      luaoc_tostruct(L, -2, buf);
      XCTAssertEqual( 33, ((CGRect*)buf)->origin.x );
      XCTAssertEqual( 44, ((CGRect*)buf)->origin.y );
      XCTAssertEqual( 11, ((CGRect*)buf)->size.width);
      XCTAssertEqual( 12, ((CGRect*)buf)->size.height);
      XCTAssertEqualWithAccuracy( 6.6, lua_tonumber(L, -1), 0.001); // int(3.3) * 2.2

      RUN_LUA_SAFE_CODE( oc.class.aTestClass("allIDFunc",
            function(self, obj) return obj; end) );
      RUN_LUA_SAFE_CODE( a = oc.class.aTestClass:new(); return a:allIDFunc( oc.class.NSArray ) );
      XCTAssertEqual( luaoc_toinstance(L, -1), [NSArray class] );
  }
  lua_settop(L, 0);

  { /// create new class
      RUN_LUA_SAFE_CODE( return oc.class("luaClass") );
      Class cls = luaoc_toclass(L, -1);
      XCTAssertEqualObjects(NSStringFromClass(cls), @"luaClass");
      XCTAssertEqualObjects([cls superclass], [NSObject class]);

      /// override super method
      RUN_LUA_SAFE_CODE( oc.class.luaClass("setValue:forUndefinedKey:",
                  function(self, val, key) self[oc.tolua(key)] = val end));
      RUN_LUA_SAFE_CODE( oc.class.luaClass("valueForUndefinedKey:",
                  function(self, key) return self[oc.tolua(key)] end));
      RUN_LUA_SAFE_CODE(return oc.class.luaClass:new());
      obj = luaoc_toinstance(L, -1);
      [obj setValue:@3 forKey:@"attr1"];
      XCTAssertEqualObjects(@3, [obj valueForKey:@"attr1"]);

      /// add protocol
      RUN_LUA_SAFE_CODE(oc.class.addProtocol("luaClass", "aTestChildProtocol", "aTestSuperProtocol"));
      RUN_LUA_SAFE_CODE(oc.class.luaClass("BOOL_proto2_id:arg_int:",
              function(self, arg, val) return (val%2)==0 end));
      XCTAssertTrue([obj
              respondsToSelector: @selector(BOOL_proto2_id:arg_int:)]);
      XCTAssertTrue([obj BOOL_proto2_id:nil arg_int:2]);
  }
  lua_settop(L, 0);

  { /// create new class and add protocols
      RUN_LUA_SAFE_STR( "return oc.class('derivedClass1', nil,"
                  "'aTestSuperProtocol')");
      XCTAssertNotNil( luaoc_toclass(L, -1) );
      XCTAssertFalse( [luaoc_toclass(L, -1)
              conformsToProtocol: @protocol(aTestChildProtocol)] );

      // create same name class should return same class, but add protocols
      RUN_LUA_SAFE_STR( "return oc.class('derivedClass1', nil,"
                  "'aTestChildProtocol', 'aTestSuperProtocol')" );
      XCTAssertTrue( lua_rawequal(L, -1, -2) );
      XCTAssertTrue( [luaoc_toclass(L, -1)
              conformsToProtocol: @protocol(aTestChildProtocol)] );

      RUN_LUA_SAFE_CODE( return oc.class("derivedClass", "aTestClass",
                                         "aTestChildProtocol", "aTestSuperProtocol") );
      XCTAssertNotNil( luaoc_toclass(L, -1) );
      /// test create rule msg. eg: init
      RUN_LUA_SAFE_CODE( oc.class.derivedClass("init",
                  function(self) a = 1; return oc.super(self, 'derivedClass'):init() end) );
      RUN_LUA_SAFE_CODE( return oc.class.derivedClass:new() );
      obj = luaoc_toinstance(L, -1);
      // super will have one retainCount. use gc to release it.
      lua_gc(L, LUA_GCCOLLECT, 0);
      XCTAssertEqual([obj retainCount], 1, "should have one retainCount hold by lua");

      obj = [NSClassFromString(@"derivedClass") new];
      // super and lua retained self will be gc and release.
      lua_gc(L, LUA_GCCOLLECT, 0);
      XCTAssertEqual([obj retainCount], 1, "oc call should have 1 retainCount. owned by caller.");

      // multi super override, can call correctly
      RUN_LUA_SAFE_CODE( return oc.class('derivedClass2', 'derivedClass') );
      RUN_LUA_SAFE_CODE( oc.class.derivedClass2('init', function(self) a = 2 return oc.super(self, 'derivedClass2'):init() end) );
      RUN_LUA_SAFE_CODE( return oc.class('derivedClass3', 'derivedClass2') );
      RUN_LUA_SAFE_CODE( oc.class.derivedClass3('init', function(self) a = 3 return oc.super(self, 'derivedClass3'):init() end) );
      RUN_LUA_SAFE_CODE( a=6 oc.class.derivedClass3:new() return a);
      XCTAssertEqual(lua_tointeger(L, -1), 1);
      RUN_LUA_SAFE_CODE( a=5 oc.class.derivedClass3:new() return a);
      XCTAssertEqual(lua_tointeger(L, -1), 1);
  }
  lua_settop(L, 0);
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
  RUN_LUA_SAFE_CODE(return oc.class.name(oc.super(v)));
  // 聚合类的实例是该类子类的一个实例
  XCTAssertTrue(strcmp(lua_tostring(L,-1), "NSMutableArray") == 0);
  lua_pop(L, 2);

  // copy obj retain by lua
  RUN_LUA_SAFE_CODE(v = v:mutableCopy() return v:retainCount());
  XCTAssertEqual(lua_tonumber(L, -1), 1);
  lua_pop(L, 1);

  lua_gc(L, LUA_GCCOLLECT, 0);
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

- (void)testStruct {
  lua_State* L = gLua_main_state;
  // create struct
  RUN_LUA_SAFE_CODE( a = oc.struct.CGRect({33,44}, {55,66}); return a );
  CGRect rect;
  luaoc_tostruct(L, -1, &rect);
  XCTAssertEqual(rect.origin.x, 33);
  XCTAssertEqual(rect.origin.y, 44);
  XCTAssertEqual(rect.size.width, 55);
  XCTAssertEqual(rect.size.height, 66);

  // index struct
  RUN_LUA_SAFE_CODE( return a.x+a.y );
  XCTAssertEqual(77, lua_tonumber(L, -1));

  RUN_LUA_SAFE_CODE( return a.size.width + a.size.height );
  XCTAssertEqual(121, lua_tonumber(L, -1));

  // set struct value
  RUN_LUA_SAFE_CODE( a.x = 10; a.width = 20; return a.x * a.width, a);
  XCTAssertEqual(200, lua_tonumber(L, -2));

  luaoc_tostruct(L, -1, &rect);
  XCTAssertEqual(rect.origin.x, 10);
  XCTAssertEqual(rect.size.width, 20);

  // not work, a.size return a new CGSize struct, not the origin one
  RUN_LUA_SAFE_CODE( a.size.height = 100; return a.size.height );
  XCTAssertNotEqual(100, lua_tonumber(L, -1));

  // index by offset, offset begin at 1
  RUN_LUA_SAFE_CODE(return a[1][2] + a[2][2]);
  XCTAssertEqual(110, lua_tonumber(L, -1));

  RUN_LUA_SAFE_CODE(a[1] = {1,1}; return a[1]);
  CGPoint p;
  luaoc_tostruct(L, -1, &p);
  XCTAssertEqual(1, p.x);
  XCTAssertEqual(1, p.y);

  RUN_LUA_SAFE_CODE(return a[1].y);
  XCTAssertEqual(1, lua_tonumber(L, -1));

  lua_settop(L, 0);

  /** REG NEW CUSTOM STRUCT, it's a block with given  */
  RUN_LUA_SAFE_CODE( oc.struct.reg('p',
              {'x', oc.encode.CGFloat}, {'y', oc.encode.CGFloat}) );
  RUN_LUA_SAFE_CODE( return oc.struct.p{33,44} );
  luaoc_tostruct(L, -1, &p);
  XCTAssertEqual(33, p.x);
  XCTAssertEqual(44, p.y);

  /** REG NEW CUSTOM STRUCT WITH NEED ALIGN DATA */
  RUN_LUA_SAFE_STR( "oc.struct.reg('s1',"
     "{'a', oc.encode.bool},  "
     "{'b', oc.encode.double},"
     "{'c', oc.encode.bool} ) ");
  RUN_LUA_SAFE_STR( "a = oc.struct.s1 {true, 33.3, false} return a" );
  size_t size;
  void* structRef = luaoc_copystruct(L, -1, &size);
#if __LP64__
  XCTAssertEqual(size, sizeof(double)*3); // after align size; 0 8 16
#else
  XCTAssertEqual(size, sizeof(double)*2); // after align size; 0 4 12
#endif
  XCTAssertEqual(33.3, *(double*)&structRef[sizeof(void*)]);
  XCTAssertEqual(true, *(bool*)&structRef[0]);
  XCTAssertEqual(false, *(bool*)&structRef[sizeof(double)+sizeof(void*)]);
  free(structRef);
  RUN_LUA_SAFE_CODE( return a.b );
  XCTAssertEqual(33.3, lua_tonumber(L, -1));
  RUN_LUA_SAFE_CODE( a.b = 20 return a.b );
  XCTAssertEqual(20, lua_tonumber(L, -1));
}

- (void)testDealloc {
    lua_State* L = gLua_main_state;
    RUN_LUA_SAFE_CODE( return oc.class("derivedClass", "aTestClass") );
    // here dealloc should directly set to class
    RUN_LUA_SAFE_CODE( function oc.class.derivedClass:dealloc() a = 22 self:class() end);
    RUN_LUA_SAFE_CODE( return oc.class.derivedClass:new() ); // return +0 obj. hold by lua
    aTestClass* weakval; objc_storeWeak(&weakval, luaoc_toinstance(L, -1));

    lua_gc(L, LUA_GCCOLLECT, 0);
    XCTAssertEqual( [weakval retainCount], 1 ); // one retain by lua.
    lua_settop(L, 0);
    lua_gc(L, LUA_GCCOLLECT, 0);
    XCTAssertNil(weakval);
    RUN_LUA_SAFE_CODE( return a );
    XCTAssertEqual(lua_tointeger(L, -1), 22);
}

- (void)testBlock {
    lua_State* L = gLua_main_state;

    // test oc call vv
    RUN_LUA_SAFE_CODE( return oc.block( function() a=33 end ) );
    dispatch_block_t block; objc_storeWeak((id*)&block, luaoc_toinstance(L, -1));
    block();
    RUN_LUA_SAFE_CODE( return a );
    XCTAssertEqual(33, lua_tointeger(L, -1));
    [block retain];
    // retainCount seem always retain 1. it's no use.
    // XCTAssertEqual([block retainCount], 2); // lua hold one, retain one.
    @autoreleasepool {
        [block autorelease];
    }

    lua_settop(L, 0);
    lua_gc(L, LUA_GCCOLLECT, 0);
    XCTAssertEqual(NULL, block); // retain, autorelease, release work on malloc_block

    // test @@
    RUN_LUA_SAFE_CODE( return oc.block( function(obj) return obj:objectAtIndex(0) end) );
    objc_storeWeak((id*)&block, luaoc_toinstance(L, -1));
    id obj = ((id(^)(id))block)(@[@"123"]);
    XCTAssertEqualObjects(@"123", obj);

    // test @...
    RUN_LUA_SAFE_CODE( return oc.block( function(a,b,c,d)
                a,b,c,d = oc.tolua(a,b,c,d) return a+b+c+d
    end) );
    objc_storeWeak((id*)&block, luaoc_toinstance(L, -1));
    obj = ((id(^)(id,id,id,id))block)(@1,@2,@3,@4);
    XCTAssertEqualObjects(@10, obj);

    // test {rect}{rect}df
    RUN_LUA_SAFE_CODE( return oc.block( function(rect, dbl, flt)
                rect.width = dbl rect.height=flt return rect
                end, {'CGRect','CGRect','double','float'} ) )
    objc_storeWeak((id*)&block, luaoc_toinstance(L, -1));
    CGRect rect = ((CGRect(^)(CGRect,double,float))block)(CGRectMake(1,2,3,4), 20,30);
    XCTAssertTrue(memcmp(&rect, &((CGRect){1,2,20,30}), sizeof(CGRect)) == 0);

    // test autoconvert to default block type
    RUN_LUA_SAFE_CODE( return oc.aTestClass:testPassBlock( function() a=33 end ) );
    XCTAssertTrue( lua_isnil(L, -1) );
    lua_getglobal(L, "a");
    XCTAssertEqual(lua_tointeger(L, -1), 33);

    RUN_LUA_SAFE_CODE( return oc.aTestClass:testPassBlock_ID( function(obj)
                if obj then return obj end return oc.NSObject end, 1) );
    XCTAssertEqualObjects(@1, luaoc_toinstance(L, -1));
    RUN_LUA_SAFE_STR( "return oc.aTestClass:testPassBlock_ID( function(obj)"
                "if obj then return obj end return oc.NSObject end, nil) ");
    XCTAssertEqualObjects([NSObject class], luaoc_toinstance(L, -1));

    // weak var will auto zero when obj dealloc.
    // but when exit weak var life scope before dealloc, need to cleanup.
    objc_storeWeak((id*)&block, nil);
}

- (void)testVar {
    lua_State *L = gLua_main_state;
    RUN_LUA_SAFE_CODE( a = oc.var(oc.encode.char) return oc.getvar(a) );
    XCTAssertEqual( lua_tointeger(L, -1), 0 );
    RUN_LUA_SAFE_CODE( return oc.getvar( oc.setvar( a, 33.3 )) );
    XCTAssertEqual( lua_tointeger(L, -1), 33 );

    // weak var
    id obj = [aTestClass new];
    luaoc_push_instance(L, obj);
    lua_setglobal(L, "obj");
    RUN_LUA_SAFE_CODE( a = oc.weakvar(obj) obj = 0 return a );
    XCTAssertEqual( ( *( id* )lua_touserdata( L, -1 )), obj );
    RUN_LUA_SAFE_CODE( return a:class() );      // call msg like instance
    XCTAssertEqualObjects( luaoc_toclass(L, -1), [aTestClass class] );
    [obj release];
    lua_gc(L, LUA_GCCOLLECT, 0);
    // release when store obj dealloc
    XCTAssertEqual( ( *( id* )lua_touserdata( L, -2 )), nil );

    // obj already dealloc. call on the weak val return nil
    RUN_LUA_SAFE_CODE( return a:class() );
    XCTAssertTrue( lua_isnil(L, -1) );

    // change var in weak var type. new weak var can zero when dealloc
    obj = [aTestClass new];
    luaoc_push_instance(L, obj);
    lua_setglobal(L, "obj");
    RUN_LUA_SAFE_CODE( oc.setvar(a, obj) obj = 0 return a );
    XCTAssertEqual( ( *(id*)lua_touserdata(L, -1) ), obj );
    lua_gc(L, LUA_GCCOLLECT, 0);
    [obj release];
    XCTAssertEqual( ( *(id*)lua_touserdata(L, -1) ), nil );

    // change var store a retain obj, autorelease the retained obj
    obj = [aTestClass new];
    luaoc_push_instance(L, obj);
    lua_setglobal(L, "obj");
    RUN_LUA_SAFE_CODE( oc.setvar(a, obj) obj = 0 oc.retain(a));
    lua_gc(L, LUA_GCCOLLECT, 0);
    XCTAssertEqual([obj retainCount], 2); // new own one, var own one.
    RUN_LUA_SAFE_CODE( oc.setvar(a, 'hello') return a );
    XCTAssertEqual([obj retainCount], 1); // var set to new value, release old var if retain
    [obj release];
    
    // var change to other val. old var dealloc not clear it. still equal to new value
    XCTAssertEqualObjects( ( *(id*)lua_touserdata(L, -1) ), @"hello" );


    // struct var
    RUN_LUA_SAFE_CODE( a = oc.var(oc.encode.CGPoint, {22,33}) return oc.getvar(a) );
    void* v = luaoc_getstruct(L, -1);
    XCTAssertNotNil(v);
    XCTAssertTrue(memcmp(v, &((CGPoint){22,33}), sizeof(CGPoint)) == 0);
    // index struct var like struct userdata
    RUN_LUA_SAFE_CODE( a.x = 11; a.y = 12 return oc.getvar(a) );
    v = luaoc_getstruct(L, -1);
    XCTAssertNotNil(v);
    XCTAssertTrue(memcmp(v, &((CGPoint){11,12}), sizeof(CGPoint)) == 0);
    RUN_LUA_SAFE_CODE( a[1] = 5; a[2] = 6 return oc.getvar(a) );
    v = luaoc_getstruct(L, -1);
    XCTAssertNotNil(v);
    XCTAssertTrue(memcmp(v, &((CGPoint){5,6}), sizeof(CGPoint)) == 0);
}

- (void)testInvoke {
    lua_State *const L = gLua_main_state;

    lua_settop(L, 0);
    id block = ^{NSLog(@"call empty block");};
    luaoc_push_instance(L, block);
    luaoc_call_block(L);            // use default v... encoding

    lua_settop(L,1);
    lua_pushvalue(L, 1);
    lua_call(L, 0, 1);             // block instance can be called

    lua_settop(L, 1);
    lua_pushstring(L, "v");         // recall with explicit encoding
    luaoc_call_block(L);
    XCTAssertTrue( lua_isnil(L, -1) );          // return nil for void invoke

    lua_settop(L, 1);
    lua_pushstring(L, "!!!");       // pass invalid encoding cause lua error
    lua_pushcfunction(L, luaoc_call_block);
    lua_insert(L, 1);
    XCTAssertTrue( lua_pcall(L, lua_gettop(L) -1, 0, 0) != 0 );

    lua_settop(L, 0);
    lua_pushcfunction(L, luaoc_call_block);
    luaoc_push_instance(L, block);
    lua_pushstring(L, "{CGRect=}");       // pass invalid encoding cause lua error
    XCTAssertTrue( lua_pcall(L, lua_gettop(L) -1, 0, 0) != 0 );

    lua_settop(L, 0);
    luaoc_push_instance(L, ^{
        NSLog(@"call return obj block"); return [NSNull null];
    });
    luaoc_call_block(L); // default lua call return type is void
    XCTAssertTrue( lua_isnil(L, -1) );

    lua_settop(L, 1);
    lua_pushstring(L, "@");
    luaoc_call_block(L); // call with explicit encoding
    XCTAssertEqual( luaoc_toinstance(L, -1), [NSNull null] );

    lua_settop(L, 0);
    luaoc_push_instance(L, ^(id obj){
        NSLog(@"call pass obj and return obj block"); return [obj description];
    });
    lua_pushnil(L); // nil default to v@ encoding
    luaoc_push_instance(L, @"abc");
    luaoc_call_block(L);
    XCTAssertTrue( lua_isnil(L, -1) );

    lua_settop(L, 3);
    lua_pushstring(L, "@@");
    lua_replace(L, 2); //  call with explicit encoding
    luaoc_call_block(L);
    XCTAssertEqual( luaoc_toinstance(L, 4), [@"abc" description] );

    lua_settop(L,1);
    lua_pushvalue(L, 1);
    lua_pushstring(L, "bcd");
    lua_call(L, 1, 1);             // block instance can be called with default encoding
    XCTAssertTrue( lua_isnil(L, -1) );

    lua_settop(L, 0);
    luaoc_push_instance(L, Block_copy(^(id a,id b, id c){
        NSLog(@"call pass multi obj, %@ %@ %@ %p", a,b,c,L);
        RUN_LUA_SAFE_CODE( a = 33 );
    }));
    lua_pushnil(L);
    luaoc_push_instance(L, @1);
    luaoc_push_instance(L, @2);
    luaoc_push_instance(L, @3);
    luaoc_push_instance(L, @4);
    luaoc_call_block(L); // 4 params, default to v@@@@, last not use
    lua_getglobal(L, "a");
    XCTAssertEqual( lua_tointeger(L, -1), 33 );

    lua_pushnumber(L, 22);
    lua_setglobal(L, "a"); // change a's value
    lua_settop(L, 6); lua_copy(L, 1, 2);
    lua_call(L, 4, 1);      // call __NSMallocBlock__
    lua_getglobal(L, "a");
    XCTAssertEqual( lua_tointeger(L, -1), 33 );

    lua_settop(L, 0);
    luaoc_push_instance(L, ^CGRect(CGFloat x, CGFloat y, float width, double height){
        NSLog(@"Call rect create block"); return CGRectMake(x,y,width,height);
    });
    RUN_LUA_SAFE_CODE( return {"CGRect", "CGFloat", "CGFloat", "float", "double"} );
    lua_pushnumber(L, 22);
    lua_pushnumber(L, 23);
    lua_pushnumber(L, 24);
    lua_pushnumber(L, 25);
    luaoc_call_block(L);
    XCTAssertTrue( CGRectEqualToRect( *(CGRect*)luaoc_getstruct(L, -1), (CGRect){22,23,24,25} ) );

    lua_settop(L, 0);
    luaoc_push_instance(L, ^bool(NSInteger x){ NSLog(@"call if >0"); return x > 0; });
    RUN_LUA_SAFE_CODE( return oc.encode("bool", "NSInteger") );
    lua_pushinteger(L, 25);
    luaoc_call_block(L);
    XCTAssertTrue( lua_isboolean(L, -1) && lua_toboolean(L, -1) );

    lua_settop(L, 2);
    lua_pushinteger(L, -2);
    luaoc_call_block(L);
    XCTAssertTrue( lua_isboolean(L, -1) && !lua_toboolean(L, -1) );

    lua_settop(L, 0);
}

- (void)testEnum {
    lua_State *const L = gLua_main_state;
    RUN_LUA_SAFE_CODE( return oc.enum.NSOperationQueuePriorityNormal );
    XCTAssertEqual(lua_tointeger(L, -1), NSOperationQueuePriorityNormal);

    RUN_LUA_SAFE_CODE( return oc.enum.NSMainQueueConcurrencyType );
    XCTAssertEqual(lua_tointeger(L, -1), NSMainQueueConcurrencyType);
}

static void cfunc1() {
    RUN_LUA_SAFE_CODE( aa = 1234 );
}

static int cfunc2(int a) {
    return a + 55;
}

static id cfuncSelf(id self) {
    return self;
}

static CGPoint cfuncStruct(CGPoint p){
    return (CGPoint){p.x + 3, p.y + 4};
}

- (void)testFunc {
    lua_State* L = gLua_main_state;
    luaoc_reg_cfunc(L, "cfunc1", cfunc1, "v");
    luaoc_reg_cfunc(L, "cfunc2", cfunc2, "ii");
    luaoc_reg_cfunc(L, "cfuncSelf", cfuncSelf, "@@");

    const char* encodings[] = {@encode(CGPoint), @encode(CGPoint)};
    luaoc_reg_cfunc_with_types(L, "cfuncStruct", cfuncStruct, encodings, sizeof(encodings)/sizeof(char*));

    RUN_LUA_SAFE_CODE( oc.func.cfunc1(); return aa );
    XCTAssertEqual(lua_tointeger(L, -1), 1234);

    RUN_LUA_SAFE_CODE( return oc.func.cfunc2(33) );
    XCTAssertEqual(lua_tointeger(L, -1), 88);

    RUN_LUA_SAFE_CODE( return oc.func.cfuncSelf(oc.NSArray) );
    XCTAssertEqual( luaoc_toinstance(L, -1), [NSArray class] );

    RUN_LUA_SAFE_CODE( return oc.func.cfuncStruct( {33.3, 44} ) );
    XCTAssertTrue(memcmp(luaoc_getstruct(L, -1), &((CGPoint){36.3, 48}), sizeof(CGPoint)) == 0 );
}

@end
