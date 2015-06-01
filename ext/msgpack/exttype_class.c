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

#include "exttype_class.h"
#include "unpacker_class.h"
#include "packer.h"
#include "packer_class.h"
#include "packer_common.h"


VALUE cMessagePack_ExtType;

static VALUE ExtType_set_as_global_default_class_method(VALUE self)
{
    return rb_funcall(cMessagePack_Unpacker, rb_intern("default_exttype="), 1, self);
}

static VALUE ExtType_from_exttype_class_method(VALUE self, VALUE type, VALUE data, VALUE unpacker)
{
    VALUE argv[2] = {type, data};
    return rb_class_new_instance(2, argv, self);
}

static VALUE ExtType_pack_class_method(int argc, VALUE *argv, VALUE self)
{
    if(argc < 2 || argc > 3) {
        rb_raise(rb_eArgError, "wrong number of arguments (%d for 2..3)", argc);
    }
    if(argc == 3 && rb_class_of(argv[0]) == cMessagePack_Packer) {  // take the direct route
        VALUE type = argv[1];
        _exttype_check_typecode(type);
        VALUE data = argv[2];
        if(rb_type(data) != T_STRING) {
            rb_raise(rb_eTypeError, "exttype data is not a String");
        }
        PACKER_STRUCT(argv[0], pk);
        msgpack_packer_write_exttype_header(pk, RSTRING_LEN(data), FIX2INT(type));
        msgpack_buffer_append_string(PACKER_BUFFER_(pk), data);
        return argv[0];

    } else {  // Create an ExtType proxy object and pack it
        VALUE *argv2 = argv;
        if(argc == 3) ++argv2;  // skip io/Packer
        VALUE exttype_obj = rb_class_new_instance( 2, argv2, self);
        int argc3 = argc - 1;
        VALUE argv3[2] = { exttype_obj, exttype_obj };
        if(argc3 == 2) { argv3[0] = argv[0]; }
        return delegete_to_pack(argc3, argv3, exttype_obj);
    }
}

static VALUE ExtType_initialize(VALUE self, VALUE type, VALUE data)
{
    _exttype_check_typecode(type);
    rb_iv_set(self, "@type", type);

    if(rb_type(data) != T_STRING) {
        rb_raise(rb_eTypeError, "String expected for exttype data");
    }
    rb_iv_set(self, "@data", data);
    return self;
}

static VALUE ExtType_type(VALUE self)
{
    return rb_iv_get(self, "@type");
}

static VALUE ExtType_data(VALUE self)
{
    return rb_iv_get(self, "@data");
}

static VALUE ExtType_to_msgpack(int argc, VALUE* argv, VALUE self)
{
    ENSURE_PACKER(argc, argv, packer, pk);
    VALUE type = rb_iv_get(self, "@type");
    VALUE data = rb_iv_get(self, "@data");
    msgpack_packer_write_exttype_header(pk, RSTRING_LEN(data), FIX2INT(type));
    msgpack_buffer_append_string(PACKER_BUFFER_(pk), data);
    return packer;
}

static VALUE ExtType_to_exttype(VALUE self, VALUE type, VALUE packer)
{
    return rb_iv_get(self, "@data");
}

void MessagePack_ExtType_module_init(VALUE mMessagePack)
{
    cMessagePack_ExtType = rb_define_class_under(mMessagePack, "ExtType", rb_cObject);

    /* make this class the global default for exttype unpacking. Also works for subclasses. */
    rb_define_singleton_method(cMessagePack_ExtType, "set_as_global_default", ExtType_set_as_global_default_class_method, 0);

    /* unpacking of exttypes: */
    rb_define_singleton_method(cMessagePack_ExtType, "from_exttype", ExtType_from_exttype_class_method, 3);

    /* high-level packing of exttypes (use Packer.write_exttype_header and Packer.buffer for low-level packing): */
    rb_define_singleton_method(cMessagePack_ExtType, "pack", ExtType_pack_class_method, -1);  // write raw data

    rb_define_method(cMessagePack_ExtType, "initialize", ExtType_initialize, 2);
    rb_define_method(cMessagePack_ExtType, "type", ExtType_type, 0);
    rb_define_method(cMessagePack_ExtType, "data", ExtType_data, 0);
    rb_define_method(cMessagePack_ExtType, "to_exttype", ExtType_to_exttype, 2);
    rb_define_method(cMessagePack_ExtType, "to_msgpack", ExtType_to_msgpack, -1);

    /* Compatibility classes */
    rb_define_class_under(mMessagePack, "Extended", cMessagePack_ExtType);  // msgpack spec
    rb_define_class_under(mMessagePack, "ExtendedValue", cMessagePack_ExtType);  // Java
    rb_define_class_under(mMessagePack, "ExtensionValue", cMessagePack_ExtType);  // JRuby
}
