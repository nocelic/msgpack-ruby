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

#include "extended.h"
#include "extended_class.h"


static VALUE Extended_initialize(VALUE self, VALUE type, VALUE data)
{
  rb_iv_set(self, "@type", type);
  rb_iv_set(self, "@data", data);
  return self;
}

static VALUE Extended_type(VALUE self)
{
  return rb_iv_get(self, "@type");
}

static VALUE Extended_data(VALUE self)
{
  return rb_iv_get(self, "@data");
}

void MessagePack_Extended_module_init(VALUE mMessagePack)
{

    cMessagePack_Extended = rb_define_class_under(mMessagePack, "Extended", rb_cObject);

    //~ rb_define_alloc_func(cMessagePack_Extended, Extended_alloc);

    //~ rb_define_singleton_method(cMessagePack_Extended, "pack", Extended_class_pack, 2);
    //~ rb_define_singleton_method(cMessagePack_Extended, "pack_to", Extended_class_pack_to, 3);


    rb_define_method(cMessagePack_Extended, "initialize", Extended_initialize, 2);
    rb_define_method(cMessagePack_Extended, "type", Extended_type, 0);
    rb_define_method(cMessagePack_Extended, "data", Extended_data, 0);
}
