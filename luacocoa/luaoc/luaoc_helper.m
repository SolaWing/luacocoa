//
//  luaoc_helper.m
//  luaoc
//
//  Created by Wangxh on 15/7/28.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "luaoc_helper.h"
#import "luaoc_class.h"
#import "luaoc_instance.h"
#import "luaoc_struct.h"

#import "lauxlib.h"

#import <objc/runtime.h>
#import <Foundation/Foundation.h>

char* convert_copyto_selName(const char* luaName, bool isAppendColonIfNone) {
  NSCParameterAssert(luaName);
  size_t len = strlen(luaName);
  NSCParameterAssert(len);

  char* selName = (char*)malloc(len+2);

  convert_to_selName(selName, luaName, isAppendColonIfNone);

  return selName;
}

void convert_to_selName( char* buffer, const char* luaName, bool isAppendColonIfNone) {
  const char* it = luaName;
  char* it2 = buffer;
  while(*it) {
    if (*it == '_') {
      if (*(it + 1) == '_') {*it2 = '_'; ++it;}             // __ is converted to _
      else {*it2 = ':' ; isAppendColonIfNone = true;}       // _ is converted to :
    }else {*it2 = *it;}

    ++it; ++it2;
  }
  if ( isAppendColonIfNone && *(it2-1) != ':' ) *(it2++) = ':';
  *it2 = '\0';
}

SEL luaoc_find_SEL_byname(id target, const char* luaName) {
  char* selName = (char*)alloca(strlen(luaName) + 2);
  convert_to_selName(selName, luaName, false);
  SEL sel =  sel_getUid(selName);

  if ([target respondsToSelector:sel]){
    return sel;
  } else{
    size_t len = strlen(selName);
    if (selName[len - 1] != ':') {
      selName[len] = ':';
      selName[len+1] = '\0';
      sel = sel_getUid(selName);
      if ([target respondsToSelector:sel]) {
        return sel;
      }
    }
  }
  return NULL;
}

static int _msg_send(lua_State* L, SEL selector) {
  // call intenally, the stack should have and only have receiver and args
  id target = *(id*)lua_touserdata(L, 1);
  // for vararg, the signature only treat it as first arg
  NSMethodSignature* sign = [target methodSignatureForSelector: selector];
  if (!sign){
    LUAOC_ERROR( "'%s' has no method '%s'",
        object_getClassName(target), sel_getName(selector));
  }

  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sign];
  [invocation setTarget:target];
  [invocation setSelector:selector];

  NSUInteger argCount = [sign numberOfArguments];
  void **arguements = (void**)alloca(sizeof(void*) * argCount);
  for (NSUInteger i = 2; i < argCount; ++i) {
    arguements[i] =
      luaoc_copy_toobjc(L, (int)i, [sign getArgumentTypeAtIndex:i], NULL);
    [invocation setArgument:arguements[i] atIndex:i];
  }

  NSException* err = nil;
  @try {
    [invocation invoke];
  }
  @catch (NSException* exception) {
    err = exception;
  }

  for (NSUInteger i = 2; i < argCount; ++i) {
    free(arguements[i]);
  }

  if (err) { // luaL_error will do a long jmp, so do clean up first
    LUAOC_ERROR( "Error invoking '%s''s method '%s'. reason is:\n%s",
        object_getClassName(target),
        sel_getName(selector),
        [[err reason] UTF8String]);
  }

  NSUInteger retLen = [sign methodReturnLength];
  if (retLen > 0){
    void* buf = alloca(retLen);
    [invocation getReturnValue:buf];
    luaoc_push_obj(L, [sign methodReturnType], buf);
    if ( strcmp([sign methodReturnType], "@") == 0) {
      const char * selName = sel_getName(selector);
      int n;
      if ( ((n = 4, strncmp(selName, "init", 4) == 0) ||
                    strncmp(selName, "copy", 4) == 0  ||
            (n = 3, strncmp(selName, "new",  3) == 0) ||
            (n = 11, strncmp(selName, "mutableCopy", n) == 0)) &&
          !islower(selName[n]) ) {
        // according to oc owner rule, this object is owned by caller. so lua
        // own it. push obj already retain, so release it
        [*(id*)buf release];
      }
    }
  } else{
    lua_pushnil(L);
  }

  return 1;
}

/** because super set implementation temporarily, it should restore even in error! */
static int protect_super_call(lua_State* L) {
  SEL selector = (SEL)lua_touserdata(L, lua_upvalueindex(1));
  return _msg_send(L, selector);
}

int luaoc_msg_send(lua_State* L){
  id* ud = (id*)lua_touserdata(L, 1);

  if (!ud) { LUAOC_ARGERROR( 1, "msg receiver must be objc object!"); }

  if (luaL_getmetafield(L, 1, "__type") != LUA_TNUMBER) {
    LUAOC_ERROR( "can't found metaTable!");
  }
  LUA_INTEGER tt = lua_tointeger(L, -1);
  lua_pop(L, 1);

  SEL selector = (SEL)lua_touserdata(L, lua_upvalueindex(1));

  if (tt == luaoc_super_type){
    Method selfMethod = class_getInstanceMethod([*ud class], selector);
    if (NULL == selfMethod)
      LUAOC_ERROR( "unknown selector %s", sel_getName(selector));
    Method superMethod = class_getInstanceMethod(*(ud+1), selector);
    if (superMethod && superMethod != selfMethod){
      IMP selfMethodIMP = method_getImplementation(selfMethod);
      IMP superMethodIMP = method_getImplementation(superMethod);
      method_setImplementation(selfMethod, superMethodIMP);
      // call _msg_send in protect mode
      lua_pushlightuserdata(L, selector);
      lua_pushcclosure(L, protect_super_call, 1);
      lua_insert(L, 1);
      int ret = lua_pcall(L, lua_gettop(L) - 1, LUA_MULTRET, 0);

      method_setImplementation(selfMethod, selfMethodIMP); // restore

      if (ret == 0)          // no error
        ret = lua_gettop(L); // all arg be used and left result
      else
        lua_error(L);        // re throw error;
      return ret;
    } else {
      return _msg_send(L, selector);
    }
  } else if (tt == luaoc_class_type || tt == luaoc_instance_type ||
             tt == luaoc_var_type) { // var type should be the id or class container
    return _msg_send(L, selector);
  } else {
    LUAOC_ERROR( "unsupported msg receiver type");
  }
  return 0;
}

id luaoc_convert_toid(lua_State *L, int index) {
  switch (lua_type(L, index)){
    case LUA_TLIGHTUSERDATA:
      return (id)lua_touserdata(L, index); // assume the ptr is convert from id
    case LUA_TUSERDATA: {
      id value = NULL;
      if (luaL_getmetafield(L, index, "__type") != LUA_TNIL){
        LUA_INTEGER tt = lua_tointeger(L, -1); lua_pop(L, 1);

        if (tt == luaoc_struct_type){ // auto encapsulate struct to NSValue
          void* bytes = lua_touserdata(L,index);
          lua_getfield(L, index, "__encoding");
          value = [NSValue valueWithBytes:bytes
                                 objCType:lua_tostring(L, -1)];
          lua_pop(L, 1); // pop __encoding
        } else if (tt == luaoc_var_type) { // use var type's value
          lua_getfield(L, index, "__encoding");
          if (strcmp(lua_tostring(L, -1), (char[]){_C_ID,0}) == 0){
            // var type store id. don't need to convert to id
            lua_pop(L, 1);

            value = *(id*)lua_touserdata(L, index);
          }else {
            lua_pop(L, 1);

            lua_getfield(L, index, "v");
            value = luaoc_convert_toid(L, -1);
            lua_pop(L, 1);
          }
        } else {
          value = *(id*)lua_touserdata(L, index);
        }
      } else {
        DLOG("unknown userdata type, this shouldn't happen!");
      }
      return value;
    }
    case LUA_TBOOLEAN:
        return [NSNumber numberWithBool:lua_toboolean(L, index)];
    case LUA_TNUMBER:
        return [NSNumber numberWithDouble:lua_tonumber(L, index)];
    case LUA_TSTRING:
        return [NSString stringWithUTF8String:lua_tostring(L, index)];
    case LUA_TTABLE:{
      BOOL dictionary = NO; // has any other method to test dic or array?

      lua_pushvalue(L, index); // Push the table reference on the top
      lua_pushnil(L);  /* first key */
      while (!dictionary && lua_next(L, -2)) {
        if (lua_type(L, -2) != LUA_TNUMBER) {
          dictionary = YES;
          lua_pop(L, 2); // pop key and value off the stack
        }
        else {
          lua_pop(L, 1);
        }
      }

      id value = NULL;
      if (dictionary) {
        value = [NSMutableDictionary dictionary];

        lua_pushnil(L);  /* first key */
        while (lua_next(L, -2)) {
          id *key = (id*)luaoc_copy_toobjc(L, -2, "@", nil);
          id *object = (id*)luaoc_copy_toobjc(L, -1, "@", nil);
          if (*key && *object) // ignore NULL kv
            [value setObject:*object forKey:*key];
          lua_pop(L, 1); // Pop off the value
          free(key);
          free(object);
        }
      } else {
        value = [NSMutableArray array];

        size_t len = lua_rawlen(L, -1);
        for (size_t i = 1; i <= len; ++i) {
          lua_rawgeti(L, -1, i);
          id *object = (id*)luaoc_copy_toobjc(L, -1, "@", nil);
          [value addObject:*object];
          free(object); lua_pop(L,1);
        }
      }

      lua_pop(L, 1); // Pop the table reference off
      return value;
    }
    case LUA_TFUNCTION: // convert lua function to block obj
        DLOG("block now unsupported");
    case LUA_TNIL:
    case LUA_TNONE:
    default: return NULL;
  }
}

void* luaoc_convert_copytostruct(lua_State *L, int index, const char* typeencoding, size_t *outSize) {
  if (!outSize) outSize = alloca(sizeof(size_t));
  void* value;

  switch (lua_type(L, index)) {
    case LUA_TLIGHTUSERDATA: // assume pointer is point to a struct
      *outSize = luaoc_get_one_typesize(typeencoding, NULL, NULL);
      return lua_touserdata(L, index);
    case LUA_TUSERDATA: {
      if (luaL_getmetafield(L, index, "__type") != LUA_TNIL) {
        LUA_INTEGER tt = lua_tointeger(L, -1); lua_pop(L, 1);
        if (tt == luaoc_struct_type){
          // FIXME: may need to check encoding compatible
          return luaoc_copystruct(L, index, outSize);
        } else if (tt == luaoc_var_type) {
          *outSize = luaoc_get_one_typesize(typeencoding, NULL, NULL);
          value = calloc(1, *outSize);

          void* buf = lua_touserdata(L, index);
          lua_getfield(L, index, "__encoding");
          int sizeBuf = luaoc_get_one_typesize(lua_tostring(L, -1), NULL, NULL);
          lua_pop(L, 1);
          if (sizeBuf == *outSize) {
            memcpy(value, buf, sizeBuf);
          } else if (sizeBuf < *outSize){
            DLOG("var type convert to struct with non-enough size!");
            memcpy(value, buf, sizeBuf);
          } else {
            DLOG("var type convert to struct with trailing size!");
            memcpy(value, buf, *outSize);
          }
          return value;
        } else { // id type
          id instance = *(id*)lua_touserdata(L, index);
          if ([instance isKindOfClass:[NSValue class]]) {
            *outSize = luaoc_get_one_typesize(typeencoding, NULL, NULL);
            value = calloc(1, *outSize);
            [instance getValue:value];
            return value;
          } else {
            DLOG("can't convert non value id type to struct!");
          }
        }
      } else {
        DLOG("unknown userdata type, this shouldn't happen!");
      }
      break;
    }
    case LUA_TTABLE: {
      *outSize = luaoc_get_one_typesize(typeencoding, NULL, NULL);
      value = calloc(1, *outSize);

      const char* encodingPointer = strchr(typeencoding, '=');
      if (encodingPointer++ == NULL) return value;

      void* attrPointer = value;

      index = lua_absindex(L, index);
      int i = 1;
      size_t typeSize;
      void* attr;
      while (lua_geti(L, index, i++) != LUA_TNIL &&
             *encodingPointer != _C_STRUCT_E)
      {
        // TODO consider struct align, and flatten primitive table
        attr = luaoc_copy_toobjc(L, -1, encodingPointer, &typeSize);
        if (NULL == attr) LUAOC_ERROR( "invalid typeencoding:%s", typeencoding);
        memcpy(attrPointer, attr, typeSize);

        free(attr);
        attrPointer += typeSize;
        luaoc_get_one_typesize(encodingPointer, &encodingPointer, NULL);
        lua_pop(L, 1); // pop table[i]
      }
      // TODO support key-value assign
      return value;
    }
  }
  return NULL;
}

void* luaoc_copy_toobjc(lua_State *L, int index, const char *typeDescription, size_t *outSize) {
  // return NULL only when invalid typeDescription.
  // invalid lua value will return value ref to zero fill value
  NSCParameterAssert(typeDescription);

  void* value = NULL;
  if (outSize == NULL) outSize = (size_t*)alloca(sizeof(size_t));     // prevent NULL condition in deal

  if (lua_isnoneornil(L, index)) { // if nil, return a pointer ref to NULL pointer, it also can treat as number 0
    *outSize = sizeof(void*); value = calloc(sizeof(void*), 1);
    return value;
  }

  *outSize = 0;

  int i = 0;

#define CONVERT_TO_TYPE( type, lua_func)                 \
  *outSize = sizeof(type); value = malloc(sizeof(type)); \
  *((type *)value) = (type)lua_func(L, index)

#define INTEGER_CASE(encoding, type) case encoding: { CONVERT_TO_TYPE(type, lua_tointeger); return value; }
#define NUMBER_CASE(encoding, type)  case encoding: { CONVERT_TO_TYPE(type, lua_tonumber); return value; }
#define BOOL_CASE(encoding, type)    case encoding: { CONVERT_TO_TYPE(type, lua_toboolean); return value; }

  while ( typeDescription[i] ) {
    switch( typeDescription[i] ){
      INTEGER_CASE(_C_CHR, char)
      INTEGER_CASE(_C_UCHR, unsigned char)
      INTEGER_CASE(_C_SHT, short)
      INTEGER_CASE(_C_USHT, unsigned short)
      INTEGER_CASE(_C_INT, int)
      INTEGER_CASE(_C_UINT, unsigned int)
      INTEGER_CASE(_C_LNG, long)
      INTEGER_CASE(_C_ULNG, unsigned long)
      INTEGER_CASE(_C_LNG_LNG, long long)
      INTEGER_CASE(_C_ULNG_LNG, unsigned long long)
      NUMBER_CASE (_C_FLT, float)
      NUMBER_CASE (_C_DBL, double)
      BOOL_CASE   (_C_BOOL, bool)
      case _C_CHARPTR: { // NOTE: the _C_CHARPTR return a const char*, shouldn't change it
        *outSize = sizeof(char*); value = malloc(sizeof(char*));
        *(const char**)value = lua_tostring(L, index);
        return value;
      }
      case _C_PTR: {
         // FIXME: when convert to ptr, pass the userdata addr, just like pass by ref
         // var type is designed for this purpose, it's store value is safe to change.
         // other type change inner value may unsafe.
        *outSize = sizeof(void*); value = calloc(sizeof(void*), 1);
        switch( lua_type(L, index) ){
          case LUA_TLIGHTUSERDATA:
          case LUA_TUSERDATA: {
            *(void**)value = lua_touserdata(L, index);
            return value;
          }
          case LUA_TNONE:
          case LUA_TNIL:
          default: {
            return value;
          }
        }
      }
      case _C_CLASS:
      case _C_ID: {
        *outSize = sizeof(id); value = calloc(sizeof(id), 1);
        *(id*)value = luaoc_convert_toid(L, index);
        return value;
      }
      case _C_SEL:{ // sel type is binding to str
        *outSize = sizeof(SEL); value = calloc(sizeof(SEL), 1);
        if ((*(const char**)value = lua_tostring(L, index))) {
          *(SEL*)value = sel_getUid(*(char**)value);
        }
        return value;
      }
      case _C_STRUCT_B:{
        value = luaoc_convert_copytostruct(L, index, typeDescription+i, outSize);

        // value = luaoc_copystruct(L, index, outSize);
        if (!value) { // not a struct userdata at index, return a empty struct
          *outSize = luaoc_get_one_typesize(typeDescription+i, NULL, NULL);
          value = calloc(1,*outSize);
        }
        return value;
      }
      case _C_UNION_B:
      case _C_UNDEF: // ^? and @? both have type before, this never enter
      case _C_BFLD:
      case _C_ARY_B:
        LUAOC_ERROR( "unsupported type encoding %c", typeDescription[i]);
        return value;
      default: {
        break;
      }
    }
    ++i;
  }
  DLOG( "undeal encoding: %s", typeDescription);
  return value;
}

void luaoc_push_obj(lua_State *L, const char *typeDescription, void* buffer) {
  NSCParameterAssert(buffer);
  NSCParameterAssert(typeDescription);

#define PUSH_INTEGER(encoding, type) case encoding: lua_pushinteger(L, *(type*)buffer); return;
#define PUSH_NUMBER(encoding, type) case encoding: lua_pushnumber(L, *(type*)buffer); return;
#define PUSH_POINTER(encoding, type, luafunc) \
  case encoding: {if (*(type*)buffer == NULL) lua_pushnil(L); else luafunc(L, *(type*)buffer);} return;

  int i = 0;
  while(typeDescription[i]) {
    switch( typeDescription[i] ){
      case _C_BOOL:
        lua_pushboolean(L, *(bool*)buffer);
        return;
      case _C_CHR: // in osx and 32bit ios, BOOL is char type. so treat char 0,1 as bool
        if (*(char*)buffer == 0 || *(char*)buffer == 1)
          lua_pushboolean(L, *(char*)buffer);
        else
          lua_pushinteger(L, *(char*)buffer);
        return;
      PUSH_INTEGER(_C_UCHR    , unsigned char)
      PUSH_INTEGER(_C_SHT     , short)
      PUSH_INTEGER(_C_USHT    , unsigned short)
      PUSH_INTEGER(_C_INT     , int)
      PUSH_INTEGER(_C_UINT    , unsigned int)
      PUSH_INTEGER(_C_LNG     , long)
      PUSH_INTEGER(_C_ULNG    , unsigned long)
      PUSH_INTEGER(_C_LNG_LNG , long long)
      PUSH_INTEGER(_C_ULNG_LNG, unsigned long long)
      PUSH_NUMBER(_C_FLT , float)
      PUSH_NUMBER(_C_DBL , double)
      PUSH_POINTER(_C_ID, id, luaoc_push_instance)  // FIXME: if need to bind lua types?
      PUSH_POINTER(_C_CLASS, Class, luaoc_push_class)
      PUSH_POINTER(_C_PTR, void*, lua_pushlightuserdata)
      PUSH_POINTER(_C_CHARPTR, char*, lua_pushstring)
      case _C_SEL:
        if (*(SEL*)buffer == NULL) lua_pushnil(L);
        else lua_pushstring(L, sel_getName(*(SEL*)buffer));
        return;
      case _C_VOID:
        DLOG("this shouldn't enter, treat as push nil");
        lua_pushnil(L); return;
      case _C_STRUCT_B:
        luaoc_push_struct(L, typeDescription+i, buffer);
        return;
      case _C_UNDEF: // mainly function or block
      case _C_ARY_B:
      case _C_UNION_B:
        lua_pushnil(L);
        LUAOC_ERROR( "unsupported type encoding %c", typeDescription[i]);
        return;
//#define _C_UNDEF    '?'
//#define _C_ATOM     '%'
//#define _C_VECTOR   '!'
      default: {
        break;
      }
    }
    ++i;
  }
  DLOG("unable convert typeencoding %s", typeDescription);
  lua_pushnil(L);
}

int luaoc_get_one_typesize(const char *typeDescription, const char** stopPos, char** copyTypeName) {

  #define CASE_SIZE(encoding, type) case encoding: ++(*stopPos); return sizeof(type);

  if (NULL == stopPos){
    stopPos = (const char**)alloca(sizeof(const char*));
  }
  *stopPos = typeDescription;
  int size = -1;
  int a; // tmp value
  size_t len;
  do {
    switch( **stopPos ){
      CASE_SIZE(_C_ID      , id)
      CASE_SIZE(_C_CLASS   , Class)
      CASE_SIZE(_C_SEL     , SEL)
      CASE_SIZE(_C_CHARPTR , char*)
      CASE_SIZE(_C_CHR     , char)
      CASE_SIZE(_C_UCHR    , unsigned char)
      CASE_SIZE(_C_SHT     , short)
      CASE_SIZE(_C_USHT    , unsigned short)
      CASE_SIZE(_C_INT     , int)
      CASE_SIZE(_C_UINT    , unsigned int)
      CASE_SIZE(_C_LNG     , long)
      CASE_SIZE(_C_ULNG    , unsigned long)
      CASE_SIZE(_C_LNG_LNG , long long)
      CASE_SIZE(_C_ULNG_LNG, unsigned long long)
      CASE_SIZE(_C_FLT     , float)
      CASE_SIZE(_C_DBL     , double)
      CASE_SIZE(_C_BOOL    , BOOL)
      // FIXME: may need to deal error
      case _C_BFLD: return ((int)strtol(++(*stopPos), (char**)stopPos, 10)+7)/8;
      case _C_VOID: ++(*stopPos); return 0;
      case _C_UNDEF: ++(*stopPos); return 0; // ^? function pointer, @? block, FIXME but @? is one type, there may treat two type
      case _C_PTR: {
        luaoc_get_one_typesize(++(*stopPos), stopPos, NULL); // set stopPos after ptr type
        return sizeof(void*);
      }
      case _C_ARY_B: {
        size = (int)strtol(++(*stopPos), (char**)stopPos, 10); // array count
        size *= luaoc_get_one_typesize(*stopPos, stopPos, NULL);
        // FIXME: may need to check array end
        ++(*stopPos); // skip array end
        return size;
      }
      case _C_STRUCT_B:
      case _C_UNION_B: {
        char* eqpos = strchr(*stopPos, '=');

        if (NULL == eqpos) {
          DLOG("Error: can't find '=' in struct type,"
               "this can happen when use ^^(type), or invalid encoding");
          if (**stopPos == _C_STRUCT_B) *stopPos = strchr(*stopPos, _C_STRUCT_E);
          else *stopPos = strchr(*stopPos, _C_UNION_E);
          ++(*stopPos);
          return 0;
        }
        if (copyTypeName){
          // some struct name actually have _ before, like _NSRange. remove it.
          a = 1;
          while( *((*stopPos)+a) == '_') { ++a; }

          len = eqpos - *stopPos - a;
          *copyTypeName = (char*)malloc(len + 1);
          memcpy(*copyTypeName, (*stopPos)+a, len);
          (*copyTypeName)[len] = '\0';
        }

        if (**stopPos == _C_UNION_B) {
          *stopPos = eqpos+1; // set pos after =, assuming it exist
          while(**stopPos != _C_UNION_E){ // union get the max element size
            a = luaoc_get_one_typesize(*stopPos, stopPos, NULL);
            if (a > size) size = a;
          }
        } else { // struct
          // TODO apply align rule
          *stopPos = eqpos + 1;
          size = 0;
          while (**stopPos != _C_STRUCT_E){ // struct get all element size
            size += luaoc_get_one_typesize(*stopPos, stopPos, NULL);
          }
        }
        ++(*stopPos); // skip end
        return size;
      }
      case '\0': return size; // reach string end
      default: { break; }
    }
    ++(*stopPos);
  } while(true);
  return size;
}

#pragma mark - DEBUG
static void _luaoc_print(lua_State* L, int index) {
  switch( lua_type(L, index) ){
    case LUA_TNIL: {
      printf("nil");
      break;
    }
    case LUA_TNUMBER: {
      printf("%lf", lua_tonumber(L, index));
      break;
    }
    case LUA_TBOOLEAN: {
      printf(lua_toboolean(L, index) ? "true":"false");
      break;
    }
    case LUA_TSTRING: {
      printf("%s", lua_tostring(L, index));
      break;
    }
    case LUA_TTABLE: {
      luaoc_print_table(L, index);
      break;
    }
    case LUA_TFUNCTION: {
      printf("function(%p)", lua_topointer(L, index));
      break;
    }
    case LUA_TUSERDATA: {
      printf("userdata(%p)", lua_touserdata(L, index));
      break;
    }
    case LUA_TLIGHTUSERDATA: {
      printf("pointer(%p)", lua_touserdata(L, index));
      break;
    }
    case LUA_TTHREAD: {
      printf("thread(%p)", lua_topointer(L, index));
      break;
    }
    case LUA_TNONE:
    default: {
      printf("invalid index\n");
      break;
    }
  }
}

void luaoc_print(lua_State *L, int index) {
  _luaoc_print(L, index);
  printf("\n"); // when not print \n, print will not flush
}


void luaoc_print_table(lua_State* L, int index) {
  if (lua_type(L, index) == LUA_TTABLE) {
    int top = lua_gettop(L);
    if (index < 0) index = top + index + 1;

    printf("table(%p):{\n", lua_topointer(L, index));
    lua_pushnil(L);
    while(lua_next(L, index) != 0) {
      printf("\t");
      _luaoc_print(L, -2);
      printf("\t:\t");
      _luaoc_print(L, -1);
      printf("\n");

      lua_pop(L, 1);
    }
    printf("}");

  } else{
    printf("print not table\n");
  }
}

void luaoc_dump_stack(lua_State* L) {
  int top = lua_gettop(L);
  for (int i = 1; i<=top; ++i){
    printf("stack %d:\n", i);
    _luaoc_print(L, i);
    printf("\n");
  }
}

