module MessagePack

  #
  # MessagePack::Packer is a class to serialize objects.
  #
  class Packer
    #
    # Creates a MessagePack::Packer instance.
    #
    # @overload initialize(options={})
    #   @param options [Hash]
    #
    # @overload initialize(io, options={})
    #   @param io [IO]
    #   @param options [Hash]
    #   This packer writes serialzied objects into the IO when the internal buffer is filled.
    #   _io_ must respond to write(string) or append(string) method.
    #
    # Supported options:
    #
    # * *:unknown_class* how to deal with unregistered classes.
    #
    #   When an unregistered class is about to be packed, the packer behavior can be influenced with this option value:
    #   * +nil+:(default) proceed with the default behavior, call +to_msgpack+(packer) on the packed object.
    #   * +false+: raise a TypeError exception.
    #
    # See also {Buffer#initialize} for further options.
    #
    def initialize(*args)
    end

    #
    # Internal buffer
    #
    # @return MessagePack::Buffer
    #
    attr_reader :buffer

    #
    # Serializes an object into internal buffer, and flushes to io if necessary.
    #
    # If it could not serialize the object, it raises
    # NoMethodError: undefined method `to_msgpack' for #<the_object>.
    #
    # @param obj [Object] object to serialize
    # @return [Packer] self
    #
    def write(obj)
    end

    alias pack write

    #
    # Serializes a nil object. Same as write(nil).
    #
    def write_nil
    end

    #
    # Write a header of an array whose size is _n_.
    # For example, write_array_header(1).write(true) is same as write([ true ]).
    #
    # @return [Packer] self
    #
    def write_array_header(n)
    end

    #
    # Write a header of an map whose size is _n_.
    # For example, write_map_header(1).write('key').write(true) is same as write('key'=>true).
    #
    # @return [Packer] self
    #
    def write_map_header(n)
    end

    #
    # Write a header of an extended type whose size is _n_ and type number is _typenr_.
    #
    # @return [Packer] self
    #
    def write_exttype_header(n, typenr)
    end

    #
    # Flushes data in the internal buffer to the internal IO. Same as _buffer.flush.
    # If internal IO is not set, it does nothing.
    #
    # @return [Packer] self
    #
    def flush
    end

    #
    # Makes the internal buffer empty. Same as _buffer.clear_.
    #
    # @return nil
    #
    def clear
    end

    #
    # Returns size of the internal buffer. Same as buffer.size.
    #
    # @return [Integer]
    #
    def size
    end

    #
    # Returns _true_ if the internal buffer is empty. Same as buffer.empty?.
    # This method is slightly faster than _size_.
    #
    # @return [Boolean]
    #
    def empty?
    end

    #
    # Returns all data in the buffer as a string. Same as buffer.to_str.
    #
    # @return [String]
    #
    def to_str
    end

    alias to_s to_str

    #
    # Returns content of the internal buffer as an array of strings. Same as buffer.to_a.
    # This method is faster than _to_str_.
    #
    # @return [Array] array of strings
    #
    def to_a
    end

    #
    # Writes all of data in the internal buffer into the given IO. Same as buffer.write_to(io).
    # This method consumes and removes data from the internal buffer.
    # _io_ must respond to write(data) method.
    #
    # @param io [IO]
    # @return [Integer] byte size of written data
    #
    def write_to(io)
    end

    #
    # Register a class for packing via an extended type.
    #
    # When an instance of _klass_ is about to be packed, the packer will call an appropriate
    # high-level or low-level method, as explained below.
    #
    # @return [Class] _klass_
    #
    # @overload register_exttype(klass, typenr)
    #   Basic variant using predefined methods for packing.
    #
    #   For *high-level* packing, the invoked method is +to_exttype+(_typenr_, _packer_).
    #   - _typenr_ is the extended type number registered here, and
    #   - _packer_ is the +Packer+ instance doing the packing.
    #   - +to_exttype+ must return a +String+ containing the exttype *payload only*.
    #
    #   For *low-level* packing, the invoked method is +to_msgpack+(_packer_).
    #   * It should call _packer_ methods directly to write the exttpe header and exttype data.
    #   * _packer_ is the +Packer+ instance doing the packing.
    #   * Alternatively, {MessagePack::ExtType.pack} may be used for safety and convenience.
    #   * Its return value is ignored.
    #
    #   @param klass [Class] the class to register for packing via extended type mechanism.
    #
    #   @param typenr [Integer,nil] the extended type number to assign to objects of this class.
    #     - If a number +0..127+, it selects high-level packing.
    #     - If +nil+, it selects low-level packing.
    #
    # @overload register_exttype(klass, typenr, handler_name)
    #   @param handler_name [Symbol,String] method of the packed _klass_ instance to call instead of +to_exttype+/+to_msgpack+.
    #   Both high- and low-level packing call the same method; only the number of arguments differs.
    #
    # @overload register_exttype(klass, typenr, handler_method)
    #   @param handler_method [Method] a bound method to call on packing of an instance of _klass_.
    #   It gets passed one extra argument, the _object_ being packed.
    #   For high-level packing, the call is: +handler_method.call+(_typenr_, _object_, _packer_)
    #   For low-level-level packing, the call is: +handler_method.call+(_object_, _packer_)
    #   The meaning of the arguments is the same as for the block variant below.
    #
    # @overload register_exttype(klass, typenr, &block)
    #   If a block is given instead of a _handler_method_, it will be converted to a +Proc+ and treated the same way as a bound method above.
    #   If typenr is Integer, high-level packing is selected, and the block is called with 3 arguments:
    #   @yieldparam typenr [Integer] the same type number as in the registration.
    #   @yieldparam object [Object] the object to pack.
    #   @yieldparam packer [Packer] the packer doing the packing.
    #   @yieldreturn [String] extended type data (payload)
    #
    # @overload register_exttype(klass, nil, &block)
    #   If _typenr_ is nil, low-level packing is selected, and the block is called with 2 arguments:
    #   @yieldparam object [Object] the object to pack.
    #   @yieldparam packer [Packer] the packer doing the packing.
    #   @yieldreturn [Object] ignored
    #
    # @overload register_exttype(klass, typenr, false)
    #   Prevent instances of _klass_ from being packed. An attempt to do so will result in a TypeError.
    #
    def register_exttype klass, typenr, arg
    end


    #
    # To select low-level packing in {#register_exttype}, the _typenr_ argument must be set to +nil+
    # +register_lowlevel+ is a convenience method that omits the _typenr_ parameter and calls +register_exttype+ with _typenr_=+nil+.
    #
    # @return [Class] _klass_
    #
    # @overload register_lowlevel(klass)
    #
    # @overload register_lowlevel(klass, handler_name)
    #
    # @overload register_lowlevel(klass, handler_method)
    #
    # @overload register_lowlevel(klass, &block)
    #   @yieldparam object [Object] the object to pack.
    #   @yieldparam packer [Packer] the packer doing the packing.
    #   @yieldreturn [Object] ignored
    #
    # @overload register_lowlevel(klass, false)
    #
    def register_lowlevel klass, arg
    end

    #
    # Unregister a previously registered class.
    #
    # @param klass [Class] the class to unregister.
    def unregister_exttype klass
    end

    #
    # Get the local registration info for _klass_.
    #
    # This method retrieves exactly the information registered with this Packer instance and does NOT observe the defaults.
    # To find out how _klass_ instances would actually be packed, use {#resolve_exttype}.
    #
    # @param klass [Class] the class to get the registration info for.
    #
    # @return [Array,nil,false]
    #   - frozen array [typenr, handler], or
    #   - nil if the defaults are to be used for _klass_, or
    #   - false if _klass_ instance may not be packed
    #
    def exttype klass
    end

    #
    # Find out how _klass_ instances would be packed.
    #
    # Unlike {#exttype}, this method DOES observe the defaults.
    #
    # If this method returns +nil+, when packing an _object_,
    # the packer will call _object_.+to_msgpack+(_packer_).
    #
    # @param klass [Class] the class to get the packing info for.
    #
    # @return [Array,nil,false]
    #   - frozen array [typenr, handler], or
    #   - nil if no exttype info found for _klass_, or
    #   - false if _klass_ instance may not be packed
    #
    def resolve_exttype klass
    end

  end
end
