/*
 * MessagePack for Ruby
 *
 * Copyright (C) 2008-2013 Sadayuki Furuhashi
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#ifndef MSGPACK_RUBY_EXTTYPE_CLASS_H__
#define MSGPACK_RUBY_EXTTYPE_CLASS_H__

#include "packer.h"

extern VALUE cMessagePack_ExtType;

void MessagePack_ExtType_module_init(VALUE mMessagePack);

static inline int8_t _exttype_check_typecode(VALUE arg)
{
    if(rb_type(arg) == T_FIXNUM) {
        int nr = FIX2INT(arg);
        if(nr >= 0 && nr <= 127) {
            return nr;
        } else {
            rb_raise(rb_eArgError, "expected integer value 0..127 for exttype typecode");
        }
    }
    rb_raise(rb_eTypeError, "expected Integer for exttype typecode");
}

#endif
