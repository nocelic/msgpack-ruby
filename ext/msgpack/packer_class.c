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

#include "compat.h"
#include "ruby.h"
#include "packer.h"
#include "packer_class.h"
#include "buffer_class.h"
#include "exttype_class.h"

VALUE cMessagePack_Packer;

static ID s_to_msgpack;
static ID s_to_exttype;
static ID s_write;
static ID s_instance_method;
static VALUE v_to_exttype;
static ID s_call;

//static VALUE s_packer_value;
//static msgpack_packer_t* s_packer;

#define PACKER(from, name) \
    msgpack_packer_t* name; \
    Data_Get_Struct(from, msgpack_packer_t, name); \
    if(name == NULL) { \
        rb_raise(rb_eArgError, "NULL found for " # name " when shouldn't be."); \
    }

static bool _packer_check_exttype_handler(VALUE arg, VALUE klass)
{
    switch(rb_type(arg)) {
    case T_NIL:
    case T_FALSE:
        // no-op, always valid targets
        break;
    case T_CLASS:
        rb_funcall(arg, s_instance_method, 1, v_to_exttype);  // make sure 'to_exttype' is defined
        break;
    case T_SYMBOL:
        rb_funcall(klass, s_instance_method, 1, arg);  // make sure the indicated method is defined
        break;
    case T_OBJECT:
    case T_DATA:  // incl. Proc
        if(!rb_respond_to(arg, s_call)) {
            rb_raise(rb_eArgError, "'call' method missing");
        }
        break;
    default:
        rb_raise(rb_eTypeError, "expected nil, false, a Class, or a callable object, got %s", rb_class2name(rb_obj_class(arg)));
    }
    return true;
}

static VALUE _packer_check_exttype_set_args(int argc, VALUE klass, VALUE handler, VALUE block) {
    if(block == Qnil) {
        if(argc == 2) {
            return klass;
        }
    } else {
        if(argc == 3) {
            rb_raise(rb_eArgError, "cannot take target argument and a block");
        } else {
            return block;
        }
    }
    return handler;
}

static void Packer_free(msgpack_packer_t* pk)
{
    if(pk == NULL) {
        return;
    }
    msgpack_packer_destroy(pk);
    free(pk);
}

static VALUE Packer_alloc(VALUE klass)
{
    msgpack_packer_t* pk = ALLOC_N(msgpack_packer_t, 1);
    msgpack_packer_init(pk);

    VALUE self = Data_Wrap_Struct(klass, msgpack_packer_mark, Packer_free, pk);

    msgpack_packer_set_to_msgpack_method(pk, s_to_msgpack, self);
    pk->buffer_ref = MessagePack_Buffer_wrap(PACKER_BUFFER_(pk), self);

    pk->to_exttype_method = s_to_exttype;

    return self;
}

static VALUE Packer_initialize(int argc, VALUE* argv, VALUE self)
{
    VALUE io = Qnil;
    VALUE options = Qnil;

    if(argc == 0 || (argc == 1 && argv[0] == Qnil)) {
        /* Qnil */

    } else if(argc == 1) {
        VALUE v = argv[0];
        if(rb_type(v) == T_HASH) {
            options = v;
        } else {
            io = v;
        }

    } else if(argc == 2) {
        io = argv[0];
        options = argv[1];
        if(rb_type(options) != T_HASH) {
            rb_raise(rb_eArgError, "expected Hash but found %s.", rb_obj_classname(options));
        }

    } else {
        rb_raise(rb_eArgError, "wrong number of arguments (%d for 0..2)", argc);
    }

    PACKER(self, pk);
    MessagePack_Buffer_initialize(PACKER_BUFFER_(pk), io, options);


    if(options != Qnil) {
        VALUE v;

        v = rb_hash_aref(options, ID2SYM(rb_intern("unknown_class")));
        if(RTEST(v)) {
            rb_raise(rb_eArgError, "nil or false expected for :unknown_class option");
        } else {
            msgpack_packer_set_default_extended_type(pk, v);
        }
    }

    // TODO MessagePack_Unpacker_initialize and options

    return self;
}

static VALUE Packer_buffer(VALUE self)
{
    PACKER(self, pk);
    return pk->buffer_ref;
}

static VALUE Packer_write(VALUE self, VALUE v)
{
    PACKER(self, pk);
    msgpack_packer_write_value(pk, v);
    return self;
}

static VALUE Packer_write_nil(VALUE self)
{
    PACKER(self, pk);
    msgpack_packer_write_nil(pk);
    return self;
}

static VALUE Packer_write_array_header(VALUE self, VALUE n)
{
    PACKER(self, pk);
    msgpack_packer_write_array_header(pk, NUM2UINT(n));
    return self;
}

static VALUE Packer_write_map_header(VALUE self, VALUE n)
{
    PACKER(self, pk);
    msgpack_packer_write_map_header(pk, NUM2UINT(n));
    return self;
}

static VALUE Packer_write_exttype_header(VALUE self, VALUE n, VALUE type)
{
    PACKER(self, pk);
    int8_t typenr = _exttype_check_typecode(type);
    msgpack_packer_write_exttype_header(pk, NUM2UINT(n), typenr);
    return self;
}

static VALUE Packer_flush(VALUE self)
{
    PACKER(self, pk);
    msgpack_buffer_flush(PACKER_BUFFER_(pk));
    return self;
}

static VALUE Packer_register_exttype(int argc, VALUE* argv, VALUE self)
{
    // args: class, typenr [, symbol | callable_object] [ &block ]
    VALUE klass, typenr, handler, block;
    rb_scan_args(argc, argv, "21&", &klass, &typenr, &handler, &block);
    if(typenr != Qnil) {
        _exttype_check_typecode(typenr);
    }
    handler = _packer_check_exttype_set_args(argc, klass, handler, block);
    _packer_check_exttype_handler(handler, klass);
    PACKER(self, pk);
    msgpack_packer_set_extended_type(pk, klass, typenr, handler);
    return handler;
}

static VALUE Packer_register_lowlevel(int argc, VALUE* argv, VALUE self)
{
    // args: class [, symbol | callable_object] [ &block ]
    VALUE argv2[argc+1];
    argv2[0] = argv[0];
    argv2[1] = Qnil;
    if(argc > 1) { argv2[2] = argv[1]; }
    return Packer_register_exttype(argc+1, argv2, self);
}

static VALUE Packer_unregister_exttype(VALUE self, VALUE klass)
{
    VALUE argv2[3] = { klass, Qnil, Qnil };
    return Packer_register_exttype(3, argv2, self);
}

static VALUE Packer_exttype(VALUE self, VALUE klass)
{
    PACKER(self, pk);
    return msgpack_packer_get_registered_type(pk, klass);
}

static VALUE Packer_resolve_exttype(VALUE self, VALUE klass)
{
    PACKER(self, pk);
    return msgpack_packer_resolve_registered_type(pk, klass);
}

static VALUE Packer_clear(VALUE self)
{
    PACKER(self, pk);
    msgpack_buffer_clear(PACKER_BUFFER_(pk));
    return Qnil;
}

static VALUE Packer_size(VALUE self)
{
    PACKER(self, pk);
    size_t size = msgpack_buffer_all_readable_size(PACKER_BUFFER_(pk));
    return SIZET2NUM(size);
}

static VALUE Packer_empty_p(VALUE self)
{
    PACKER(self, pk);
    if(msgpack_buffer_top_readable_size(PACKER_BUFFER_(pk)) == 0) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}

static VALUE Packer_to_str(VALUE self)
{
    PACKER(self, pk);
    return msgpack_buffer_all_as_string(PACKER_BUFFER_(pk));
}

static VALUE Packer_to_a(VALUE self)
{
    PACKER(self, pk);
    return msgpack_buffer_all_as_string_array(PACKER_BUFFER_(pk));
}

static VALUE Packer_write_to(VALUE self, VALUE io)
{
    PACKER(self, pk);
    size_t sz = msgpack_buffer_flush_to_io(PACKER_BUFFER_(pk), io, s_write, true);
    return ULONG2NUM(sz);
}

//static VALUE Packer_append(VALUE self, VALUE string_or_buffer)
//{
//    PACKER(self, pk);
//
//    // TODO if string_or_buffer is a Buffer
//    VALUE string = string_or_buffer;
//
//    msgpack_buffer_append_string(PACKER_BUFFER_(pk), string);
//
//    return self;
//}

VALUE MessagePack_pack(int argc, VALUE* argv)
{
    VALUE v;
    VALUE io = Qnil;
    VALUE options = Qnil;

    if(argc == 1) {
        v = argv[0];

    } else if(argc == 2) {
        v = argv[0];
        if(rb_type(argv[1]) == T_HASH) {
            options = argv[1];
        } else {
            io = argv[1];
        }

    } else if(argc == 3) {
        v = argv[0];
        io = argv[1];
        options = argv[2];
        if(rb_type(options) != T_HASH) {
            rb_raise(rb_eArgError, "expected Hash but found %s.", rb_obj_classname(options));
        }

    } else {
        rb_raise(rb_eArgError, "wrong number of arguments (%d for 1..3)", argc);
    }

    VALUE self = Packer_alloc(cMessagePack_Packer);
    PACKER(self, pk);
    //msgpack_packer_reset(s_packer);
    //msgpack_buffer_reset_io(PACKER_BUFFER_(s_packer));

    MessagePack_Buffer_initialize(PACKER_BUFFER_(pk), io, options);
    // TODO MessagePack_Unpacker_initialize and options

    msgpack_packer_write_value(pk, v);

    VALUE retval;
    if(io != Qnil) {
        msgpack_buffer_flush(PACKER_BUFFER_(pk));
        retval = Qnil;
    } else {
        retval = msgpack_buffer_all_as_string(PACKER_BUFFER_(pk));
    }

    msgpack_buffer_clear(PACKER_BUFFER_(pk)); /* to free rmem before GC */

#ifdef RB_GC_GUARD
    /* This prevents compilers from optimizing out the `self` variable
     * from stack. Otherwise GC free()s it. */
    RB_GC_GUARD(self);
#endif

    return retval;
}

static VALUE MessagePack_dump_module_method(int argc, VALUE* argv, VALUE mod)
{
    UNUSED(mod);
    return MessagePack_pack(argc, argv);
}

static VALUE MessagePack_pack_module_method(int argc, VALUE* argv, VALUE mod)
{
    UNUSED(mod);
    return MessagePack_pack(argc, argv);
}

void MessagePack_Packer_module_init(VALUE mMessagePack)
{
    s_to_msgpack = rb_intern("to_msgpack");
    s_to_exttype = rb_intern("to_exttype");
    s_write = rb_intern("write");
    s_call = rb_intern("call");
    s_instance_method = rb_intern("instance_method");
    v_to_exttype = rb_str_new2("to_exttype");
    rb_gc_register_address(&v_to_exttype);

    msgpack_packer_static_init();

    cMessagePack_Packer = rb_define_class_under(mMessagePack, "Packer", rb_cObject);

    rb_define_alloc_func(cMessagePack_Packer, Packer_alloc);

    rb_define_method(cMessagePack_Packer, "initialize", Packer_initialize, -1);
    rb_define_method(cMessagePack_Packer, "buffer", Packer_buffer, 0);
    rb_define_method(cMessagePack_Packer, "write", Packer_write, 1);
    rb_define_alias(cMessagePack_Packer, "pack", "write");
    rb_define_method(cMessagePack_Packer, "write_nil", Packer_write_nil, 0);
    rb_define_method(cMessagePack_Packer, "write_array_header", Packer_write_array_header, 1);
    rb_define_method(cMessagePack_Packer, "write_map_header", Packer_write_map_header, 1);
    rb_define_method(cMessagePack_Packer, "write_exttype_header", Packer_write_exttype_header, 2);
    rb_define_method(cMessagePack_Packer, "flush", Packer_flush, 0);
    rb_define_method(cMessagePack_Packer, "register_exttype", Packer_register_exttype, -1);
    rb_define_method(cMessagePack_Packer, "register_lowlevel", Packer_register_lowlevel, -1);
    rb_define_method(cMessagePack_Packer, "unregister_exttype", Packer_unregister_exttype, 1);
    rb_define_method(cMessagePack_Packer, "exttype", Packer_exttype, 1);
    rb_define_method(cMessagePack_Packer, "resolve_exttype", Packer_resolve_exttype, 1);


    /* delegation methods */
    rb_define_method(cMessagePack_Packer, "clear", Packer_clear, 0);
    rb_define_method(cMessagePack_Packer, "size", Packer_size, 0);
    rb_define_method(cMessagePack_Packer, "empty?", Packer_empty_p, 0);
    rb_define_method(cMessagePack_Packer, "write_to", Packer_write_to, 1);
    rb_define_method(cMessagePack_Packer, "to_str", Packer_to_str, 0);
    rb_define_alias(cMessagePack_Packer, "to_s", "to_str");
    rb_define_method(cMessagePack_Packer, "to_a", Packer_to_a, 0);
    //rb_define_method(cMessagePack_Packer, "append", Packer_append, 1);
    //rb_define_alias(cMessagePack_Packer, "<<", "append");

    //s_packer_value = Packer_alloc(cMessagePack_Packer);
    //rb_gc_register_address(&s_packer_value);
    //Data_Get_Struct(s_packer_value, msgpack_packer_t, s_packer);

    /* MessagePack.pack(x) */
    rb_define_module_function(mMessagePack, "pack", MessagePack_pack_module_method, -1);
    rb_define_module_function(mMessagePack, "dump", MessagePack_dump_module_method, -1);
}

