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

#include "packer.h"

#ifdef RUBINIUS
static ID s_to_iter;
static ID s_next;
static ID s_key;
static ID s_value;
#endif
static ID s_call;

void msgpack_packer_static_init()
{
#ifdef RUBINIUS
    s_to_iter = rb_intern("to_iter");
    s_next = rb_intern("next");
    s_key = rb_intern("key");
    s_value = rb_intern("value");
#endif
    s_call = rb_intern("call");
}

void msgpack_packer_static_destroy()
{ }

void msgpack_packer_init(msgpack_packer_t* pk)
{
    memset(pk, 0, sizeof(msgpack_packer_t));

    msgpack_buffer_init(PACKER_BUFFER_(pk));

    pk->io = Qnil;

    pk->extended_types = Qnil;
}

void msgpack_packer_destroy(msgpack_packer_t* pk)
{
    msgpack_buffer_destroy(PACKER_BUFFER_(pk));
}

void msgpack_packer_mark(msgpack_packer_t* pk)
{
    rb_gc_mark(pk->io);

    /* See MessagePack_Buffer_wrap */
    /* msgpack_buffer_mark(PACKER_BUFFER_(pk)); */
    rb_gc_mark(pk->buffer_ref);
    rb_gc_mark(pk->extended_types);
}

void msgpack_packer_reset(msgpack_packer_t* pk)
{
    msgpack_buffer_clear(PACKER_BUFFER_(pk));

    pk->io = Qnil;
    pk->io_write_all_method = 0;
    pk->buffer_ref = Qnil;
}

static inline void _msgpack_packer_make_extended_hash(VALUE *extended_types) {
    VALUE ev = *extended_types;
    if(!RTEST(ev)) {
      VALUE h = rb_hash_new();
      rb_hash_set_ifnone(h, ev);
      *extended_types = h;
    }
}

void msgpack_packer_set_default_extended_type(msgpack_packer_t* pk, VALUE val)
{
    if(RTEST(val) || RTEST(pk->extended_types)) {
        _msgpack_packer_make_extended_hash(&pk->extended_types);
        rb_hash_set_ifnone(pk->extended_types, val);
    } else {
        pk->extended_types = val;
    }
}

void msgpack_packer_set_extended_type(msgpack_packer_t* pk, VALUE klass, VALUE typenr, VALUE handler)
{
    _msgpack_packer_make_extended_hash(&pk->extended_types);
    if(handler == Qnil) {
        rb_hash_delete(pk->extended_types, klass);
    } else if(handler == Qfalse) {
        rb_hash_aset(pk->extended_types, klass, Qfalse);
    } else {
        rb_hash_aset(pk->extended_types, klass, rb_obj_freeze(rb_ary_new3(2, typenr, handler)));
    }
}


void msgpack_packer_write_array_value(msgpack_packer_t* pk, VALUE v)
{
    /* actual return type of RARRAY_LEN is long */
    unsigned long len = RARRAY_LEN(v);
    if(len > 0xffffffffUL) {
        rb_raise(rb_eArgError, "size of array is too long to pack: %lu entries, should be <= %lu", len, 0xffffffffUL);
    }
    unsigned int len32 = (unsigned int)len;
    msgpack_packer_write_array_header(pk, len32);

    unsigned int i;
    for(i=0; i < len32; ++i) {
        VALUE e = rb_ary_entry(v, i);
        msgpack_packer_write_value(pk, e);
    }
}

static int write_hash_foreach(VALUE key, VALUE value, VALUE pk_value)
{
    if (key == Qundef) {
        return ST_CONTINUE;
    }
    msgpack_packer_t* pk = (msgpack_packer_t*) pk_value;
    msgpack_packer_write_value(pk, key);
    msgpack_packer_write_value(pk, value);
    return ST_CONTINUE;
}

void msgpack_packer_write_hash_value(msgpack_packer_t* pk, VALUE v)
{
    /* actual return type of RHASH_SIZE is long (if SIZEOF_LONG == SIZEOF_VOIDP
     * or long long (if SIZEOF_LONG_LONG == SIZEOF_VOIDP. See st.h. */
    unsigned long len = RHASH_SIZE(v);
    if(len > 0xffffffffUL) {
        rb_raise(rb_eArgError, "size of hash is too long to pack: %ld entries, should be <= %lu", len, 0xffffffffUL);
    }
    unsigned int len32 = (unsigned int)len;
    msgpack_packer_write_map_header(pk, len32);

#ifdef RUBINIUS
    VALUE iter = rb_funcall(v, s_to_iter, 0);
    VALUE entry = Qnil;
    while(RTEST(entry = rb_funcall(iter, s_next, 1, entry))) {
        VALUE key = rb_funcall(entry, s_key, 0);
        VALUE val = rb_funcall(entry, s_value, 0);
        write_hash_foreach(key, val, (VALUE) pk);
    }
#else
    rb_hash_foreach(v, write_hash_foreach, (VALUE) pk);
#endif
}

static void _msgpack_packer_write_other_value(msgpack_packer_t* pk, VALUE v)
{
    /* check for registered class */
    VALUE klass = rb_obj_class(v);
    VALUE exttype_spec = msgpack_packer_resolve_registered_type(pk, klass);

    switch(exttype_spec) {

    case Qnil:
        // no-op here, resort to to_msgpack
        break;

    case Qfalse:
        rb_raise(rb_eTypeError, "packing of class %s disallowed", rb_class2name(klass));
        break;

    default:  // [typenr, handler]
        {
            VALUE type = rb_ary_entry(exttype_spec, 0);
            VALUE handler = rb_ary_entry(exttype_spec, 1);
            VALUE result;
            VALUE method, obj = v;
            VALUE argv[3] = { type, type, pk->to_msgpack_arg };
            int argc = 2;

            switch(rb_type(handler)) {

            case T_CLASS:
                method =  pk->to_exttype_method;
                break;

            case T_SYMBOL:
                method =  rb_to_id(handler);
                break;

            default: // a callable object
                obj = handler;
                argv[1] = v;
                method = s_call;
                argc = 3;
            }

            if(type == Qnil) {  // low-level packing, type argument not passed
                --argc;
            }
            result = rb_funcall2(obj, method, argc, argv + (3 - argc));
            int result_type = rb_type(result);

            if(type == Qnil) {  // ran a low-level handler
                if(result_type == T_STRING) {  // to catch a confusion between a high- a low- level serialization
                    rb_raise(rb_eTypeError, "low-level exttype handler must not return a String");
                }
                // no-op, the low-level handler should have done all the work

            } else {  // ran a high-level handler
                if(rb_type(result) != T_STRING) {
                    rb_raise(rb_eTypeError, "high-level exttype handler must return a String");
                }
                msgpack_packer_write_exttype_header(pk, RSTRING_LEN(result), FIX2INT(type));
                msgpack_buffer_append_string(PACKER_BUFFER_(pk), result);
            }
            return;
        }
    }

    /* unregistered class, try delegating the packing to the object itself */
    rb_funcall(v, pk->to_msgpack_method, 1, pk->to_msgpack_arg);
}

void msgpack_packer_write_value(msgpack_packer_t* pk, VALUE v)
{
    switch(rb_type(v)) {
    case T_NIL:
        msgpack_packer_write_nil(pk);
        break;
    case T_TRUE:
        msgpack_packer_write_true(pk);
        break;
    case T_FALSE:
        msgpack_packer_write_false(pk);
        break;
    case T_FIXNUM:
        msgpack_packer_write_fixnum_value(pk, v);
        break;
    case T_SYMBOL:
        msgpack_packer_write_symbol_value(pk, v);
        break;
    case T_STRING:
        msgpack_packer_write_string_value(pk, v);
        break;
    case T_ARRAY:
        msgpack_packer_write_array_value(pk, v);
        break;
    case T_HASH:
        msgpack_packer_write_hash_value(pk, v);
        break;
    case T_BIGNUM:
        msgpack_packer_write_bignum_value(pk, v);
        break;
    case T_FLOAT:
        msgpack_packer_write_float_value(pk, v);
        break;
    default:
        _msgpack_packer_write_other_value(pk, v);
    }
}

