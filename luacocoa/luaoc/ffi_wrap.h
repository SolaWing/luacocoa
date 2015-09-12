//
//  ffi_wrap.h
//  luaoc
//
//  Created by SolaWing on 15/9/8.
//  Copyright (c) 2015年 sw. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ffi.h"

/** create and return a IMP pointer
 *
 * @param encoding: IMP encoding
 * @param function: ffi_call function
 * @param outClosure: out closure, can pass NULL. if not cache IMP, you should
 *                    get and free the closure.
 */
IMP create_imp_for_encoding(const char* encoding,
        void (*function)(ffi_cif*,void* ret,void** args,void* ud),
        ffi_closure** outClosure);

void free_FFI_closure(ffi_closure* closure);

/** call a c function use objc encoding pattern
 *
 * @param encoding: objc method encoding
 * @param fn:       calling c function
 * @param rvalue:   return value, should be large to hold return value and
 *                  at least equal to sizeof(void*)
 * @param avalue:   argments. a array of ptr, point to the arg.
 * @return          0:success -1:encoding error -2:ffi error
 */
int objc_ffi_call(const char* encoding, void(*fn)(void), void* rvalue, void** avalue);

void ffi_initialize();
