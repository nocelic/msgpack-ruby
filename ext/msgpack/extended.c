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

#include "buffer.h"
#include "extended.h"

#define UNPACKER_BUFFER_(uk) (&(uk)->buffer)

static inline int object_complete_extended(msgpack_unpacker_t* uk, int8_t exttype, VALUE data)
{
    uk->head_byte = HEAD_BYTE_REQUIRED;
    uk->reading_raw_remaining = 0;
    uk->reading_raw = Qnil;  // previous value, if any, has been passed here as 3rd argument (data)


#ifdef COMPAT_HAVE_ENCODING
    ENCODING_SET(data, msgpack_rb_encindex_ascii8bit);
#endif
    VALUE type = INT2FIX(exttype);

    VALUE argv[2] = {type, data};
    VALUE object = rb_class_new_instance(2, argv, cMessagePack_Extended);

    uk->last_object = object;

    return PRIMITIVE_OBJECT_COMPLETE;
}

static int read_raw_body_cont(int8_t exttype, msgpack_unpacker_t* uk)
{
    size_t length = uk->reading_raw_remaining;

    if(uk->reading_raw == Qnil) {
        uk->reading_raw = rb_str_buf_new(length);
    }

    do {
        size_t n = msgpack_buffer_read_to_string(UNPACKER_BUFFER_(uk), uk->reading_raw, length);
        if(n == 0) {
            return PRIMITIVE_EOF;
        }
        /* update reading_raw_remaining everytime because
         * msgpack_buffer_read_to_string raises IOError */
        uk->reading_raw_remaining = length = length - n;
    } while(length > 0);

    return object_complete_extended(uk, exttype, uk->reading_raw);
}


int msgpack_read_extended_body(msgpack_unpacker_t* uk)
{
    int8_t exttype;
    union msgpack_buffer_cast_block_t* cb = msgpack_buffer_read_cast_block(UNPACKER_BUFFER_(uk), 1);
    if(cb == NULL) {
        return PRIMITIVE_EOF;
    } else {
      exttype = cb->i8;
    }

    size_t length = uk->reading_raw_remaining;

    if(length <= msgpack_buffer_top_readable_size(UNPACKER_BUFFER_(uk))) {
        VALUE data = msgpack_buffer_read_top_as_string(UNPACKER_BUFFER_(uk), length, false);
        return object_complete_extended(uk, exttype, data);
    }

    return msgpack_read_extended_body_cont(uk);
}
