//
//  ffi_wrap.m
//  luaoc
//
//  Created by SolaWing on 15/9/8.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import "ffi_wrap.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "luaoc_helper.h"

static NSMutableDictionary* luaStructFFIType; // encoding => ffi_type

static ffi_type* ffi_type_for_one_encoding(const char* encoding, const char** stopPos) {
  if (NULL == stopPos) stopPos = (const char**)alloca(sizeof(const char*));
  *stopPos = encoding;
  int size;

#define ADVANCE_AND_RETURN(type) ++(*stopPos); return &type

  do {
    switch( **stopPos ){
      case _C_BOOL:
      case _C_CHR: ADVANCE_AND_RETURN(ffi_type_sint8);
      case _C_UCHR: ADVANCE_AND_RETURN(ffi_type_uint8);
      case _C_SHT: ADVANCE_AND_RETURN(ffi_type_sint16);
      case _C_USHT: ADVANCE_AND_RETURN(ffi_type_uint16);
      case _C_INT: ADVANCE_AND_RETURN(ffi_type_sint32);
      case _C_UINT: ADVANCE_AND_RETURN(ffi_type_uint32);
      case _C_LNG: ADVANCE_AND_RETURN(ffi_type_slong);
      case _C_ULNG: ADVANCE_AND_RETURN(ffi_type_ulong);
      case _C_LNG_LNG: ADVANCE_AND_RETURN(ffi_type_sint64);
      case _C_ULNG_LNG: ADVANCE_AND_RETURN(ffi_type_uint64);
      case _C_FLT: ADVANCE_AND_RETURN(ffi_type_float);
      case _C_DBL: ADVANCE_AND_RETURN(ffi_type_double);
      case _C_VOID: ADVANCE_AND_RETURN(ffi_type_void);
      case _C_CHARPTR: ADVANCE_AND_RETURN(ffi_type_pointer);

      case _C_ID:
      case _C_CLASS:
      case _C_SEL:
      case _C_PTR: // ptr have one type following
      case _C_ARY_B:
        *stopPos = NSGetSizeAndAlignment(*stopPos, NULL, NULL);
        return &ffi_type_pointer;
      case _C_STRUCT_B: {
        char* eqpos = strchr(*stopPos, '=');
        if (NULL == eqpos){
          DLOG("can't find = in struct!!"); return NULL;
        }

        *stopPos = eqpos + 1;
        // cal struct arg number
        size = 0;
        while (**stopPos != _C_STRUCT_E){ // struct get all element size
          luaoc_get_one_typesize(*stopPos, stopPos, NULL);
          ++size;
        }
        NSString* structEncoding = [[[NSString alloc] initWithBytes:eqpos+1
            length:*stopPos-eqpos-1 encoding:NSUTF8StringEncoding] autorelease];
        NSValue* structEncodingType = luaStructFFIType[structEncoding];
        if (structEncodingType){
          ++(*stopPos); // skip end;
          return [structEncodingType pointerValue];
        }

        ffi_type** elements = calloc(size+1, sizeof(ffi_type*)); // NULL terminated
        ffi_type* struct_type = calloc(1, sizeof(ffi_type));
        struct_type->type = FFI_TYPE_STRUCT;
        struct_type->elements = elements;

        *stopPos = eqpos + 1;
        while (**stopPos != _C_STRUCT_E){
          *(elements++) = ffi_type_for_one_encoding(*stopPos, stopPos);
        }

        structEncodingType = [NSValue valueWithPointer:struct_type];
        luaStructFFIType[structEncoding] = structEncodingType;

        ++(*stopPos); // skip _C_STRUCT_E

        return struct_type;
      }
      case _C_UNION_B: DLOG("union type is unsupported!"); return NULL;
      case '\0': DLOG("reach encoding end, unsupported type!"); return NULL;
      default: break;
    }

    ++(*stopPos);
  } while( true );

  return NULL;
}

#pragma mark - API
IMP create_imp_for_encoding(const char* encoding,
        void (*function)(ffi_cif*,void* ret,void** args,void* ud),
        ffi_closure** outClosure)
{
  // get type count in encoding
  int typeNumber = 0;
  const char* stopPos = encoding;
  while (*stopPos) {
    // skip one type, encoding like v16@0:8, which have offset in encoding,
    // may not end with \0, so need to judge it
    if (luaoc_get_one_typesize(stopPos, &stopPos, NULL) != NSNotFound)
      ++typeNumber;
  }

  stopPos = encoding;
  ffi_type* ret_type = ffi_type_for_one_encoding(stopPos, &stopPos);
  if (NULL == ret_type) {
      DLOG("can't find ret type for encoding %s", encoding);
      return NULL; // ERROR occur;
  }

  ffi_type** args = NULL;
  if (typeNumber > 1) {             // fill arg types
    args = calloc(typeNumber - 1, sizeof(ffi_type*)); // minus return type
    ffi_type** args_it = args;
    do{
      if (!( *(args_it++) = ffi_type_for_one_encoding(stopPos, &stopPos) )){
        free(args); return NULL;
      }
    }while (args_it - args < typeNumber - 1);
  }

  void* code_ptr = NULL;
  ffi_closure* closure = ffi_closure_alloc(sizeof(ffi_closure), &code_ptr);
  if (closure) {
    ffi_cif* cif = malloc(sizeof(ffi_cif));
    if (ffi_prep_cif(cif, FFI_DEFAULT_ABI, typeNumber-1,
          ret_type, args) == FFI_OK) {
      if (ffi_prep_closure_loc(closure, cif, function,
            NULL, code_ptr) == FFI_OK)
      {
          if (outClosure) *outClosure = closure;
          return (IMP)code_ptr;
      }
    }
    free(cif);
    ffi_closure_free(closure);
  }
  free(args);
  return NULL;
}

void free_FFI_closure(ffi_closure* closure) {
    if (closure){
        ffi_cif* cif = closure->cif;
        if (cif){
            if (cif->arg_types) {
                free(cif->arg_types);
            }
            free(cif);
        }
        ffi_closure_free(closure);
    }
}

void ffi_initialize() {
    if (!luaStructFFIType) {
        luaStructFFIType = [NSMutableDictionary new];
    }
}

