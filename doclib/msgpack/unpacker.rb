module MessagePack

  #
  # MessagePack::Unpacker is a class to deserialize objects.
  #
  class Unpacker
    #
    # Creates a MessagePack::Unpacker instance.
    #
    # @overload initialize(options={})
    #   @param options [Hash]
    #
    # @overload initialize(io, options={})
    #   @param io [IO]
    #   @param options [Hash]
    #   This unpacker reads data from the _io_ to fill the internal buffer.
    #   _io_ must respond to readpartial(length [,string]) or read(length [,string]) method.
    #
    # Supported options:
    #
    # * *:symbolize_keys* deserialize keys of Hash objects as Symbol instead of String
    # * *:default_exttype* [nil,false,Class,Method,Proc] How to deal with unregistered exttype numbers. See {#default_exttype=} for details.
    #
    # See also Buffer#initialize for other options.
    #
    def initialize(*args)
    end

    #
    # Internal buffer
    #
    # @return [MessagePack::Buffer]
    #
    attr_reader :buffer

    #
    # Deserializes an object from the io or internal buffer and returns it.
    #
    # This method reads data from io into the internal buffer and deserializes an object
    # from the buffer. It repeats reading data from the io until enough data is available
    # to deserialize at least one object. After deserializing one object, unused data is
    # left in the internal buffer.
    #
    # If there're not enough data to deserialize one object, this method raises EOFError.
    # If data format is invalid, this method raises MessagePack::MalformedFormatError.
    # If the object nests too deeply, this method raises MessagePack::StackError.
    #
    # @return [Object] deserialized object
    #
    def read
    end

    alias unpack read

    #
    # Deserializes an object and ignores it. This method is faster than _read_.
    #
    # This method could raise the same errors with _read_.
    #
    # @return nil
    #
    def skip
    end

    #
    # Deserializes a nil value if it exists and returns _true_.
    # Otherwise, if a byte exists but the byte doesn't represent nil value,
    # returns _false_.
    #
    # If there're not enough data, this method raises EOFError.
    #
    # @return [Boolean]
    #
    def skip_nil
    end

    #
    # Read a header of an array and returns its size.
    # It converts a serialized array into a stream of elements.
    #
    # If the serialized object is not an array, it raises MessagePack::TypeError.
    # If there're not enough data, this method raises EOFError.
    #
    # @return [Integer] size of the array
    #
    def read_array_header
    end

    #
    # Reads a header of an map and returns its size.
    # It converts a serialized map into a stream of key-value pairs.
    #
    # If the serialized object is not a map, it raises MessagePack::TypeError.
    # If there're not enough data, this method raises EOFError.
    #
    # @return [Integer] size of the map
    #
    def read_map_header
    end

    #
    # Appends data into the internal buffer.
    # This method is equivalent to unpacker.buffer.append(data).
    #
    # @param data [String]
    # @return [Unpacker] self
    #
    def feed(data)
    end

    #
    # Repeats to deserialize objects.
    #
    # It repeats until the io or internal buffer does not include any complete objects.
    #
    # If the an IO is set, it repeats to read data from the IO when the buffer
    # becomes empty until the IO raises EOFError.
    #
    # This method could raise same errors with _read_ excepting EOFError.
    #
    # @yieldparam object [Object] deserialized object
    # @return nil
    #
    def each(&block)
    end

    #
    # Appends data into the internal buffer and repeats to deserialize objects.
    # This method is equivalent to unpacker.feed(data) && unpacker.each { ... }.
    #
    # @param data [String]
    # @yieldparam object [Object] deserialized object
    # @return nil
    #
    def feed_each(data, &block)
    end

    #
    # Clears the internal buffer and resets deserialization state of the unpacker.
    #
    # @return nil
    #
    def reset
    end

    #
    # Register a mechanism for unpacking extended type _typenr_.
    #
    # When extended type _typenr_ is encountered in the input, the unpacker will call an appropriate
    # method to create the unpacked object, as explained below.
    #
    # @return [Integer] _typenr_
    #
    # @overload register_exttype(typenr, klass)
    #   Basic variant using predefined class method of _klass_ for unpacking.
    #
    #   The predefined method is:
    #
    #   +from_exttype+(_type_, _data_).
    #
    #   * _type_ [Integer] is the extended type number.
    #   * _data_ [String] is the extended type data (payload), ASCII-8BIT encoded.
    #   * Its return value is the final unpacked object.
    #
    #   @param typenr [Integer] the extended type number +0..127+ being registered.
    #
    #   @param klass [Class] the class that will finish the extended type unpacking via its +from_exttype+ method.
    #
    #
    # @overload register_exttype(typenr, method)
    #   @param method [Method] a bound method to be called for unpacking the extended type _typenr_.
    #     Arguments are the same as for _klass_.+from_exttype+ above.
    #
    # @overload register_exttype(typenr, &block)
    #   This variant takes a block to be called for unpacking the extended type _typenr_.
    #   Arguments are the same as for _klass_.+from_exttype+ above:
    #   @yieldparam type [Integer]
    #   @yieldparam data [String]
    #   @yieldreturn [Object] the unpacked object
    #
    # @overload register_exttype(typenr, nil)
    #   Unregister extended type _typenr_. The defaults from Unpacker instance and Unpacker class still apply.
    #
    # @overload register_exttype(typenr, false)
    #   Prohibit unpacking of extended type _typenr_. UnpackerError exception will be raised if extended type _typenr_ is encountered.
    #
    def register_exttype typenr, arg
    end

    #
    # Register a default mechanism for unpacking unknown extended types by this Unpacker instance.
    #
    # When an unregistered extended type is encountered in the input, the unpacker will use the default handler
    # to create the unpacked object.
    #
    # This method behaves the same as {#register_exttype}, except that it sets the default unpacker.
    # The default unpacker is used when there is no registration info found for a given extended type.
    # Correspondingly, the _typenr_ argument is omitted in comparison to {#register_exttype}.
    #
    # See {#register_exttype} for more details.
    #
    # @return [Class,Method,Proc,nil,false]
    #
    # @overload default_exttype= klass
    #   Use _klass_.+from_exttpe+(_typenr_, _data_) for unpacking unknown extended types.
    #
    # @overload default_exttype= method_proc
    #   Register a bound method or a proc to unpack unknown extended types.
    #   A proc is treated the same way as a bound method.
    #
    #   The method or the proc will be called with 2 arguments:
    #
    #   _method_proc_.+call+(_typenr_, _data_).
    #
    # @overload default_exttype= nil
    #   For unknown extended types, resort to global defaults.
    #
    # @overload default_exttype= false
    #   Prohibit unpacking of unknown extended types. If such types are encountered, UnpackerError exception will be raised.
    #
    def default_exttype= arg
    end

    #
    # Retrieve the default unpacker of extended types set by {#register_exttype}.
    #
    # @return [Class,Method,Proc,nil,false]
    #
    def default_exttype
    end

    #
    # Get the local registration info for extended type number _typenr_.
    #
    # This method retrieves exactly the information registered with this Unpacker instance and does NOT observe the defaults.
    # To find out how extended type _typenr_ would actually be unpacked, use {#resolve_exttype}.
    #
    # @param typenr [Integer] the type number to look up.
    #
    # @return [Class,Method,Proc,nil,false]
    #   - Class / Method / Proc registered for unpacking this extended type, or
    #   - nil if the defaults are to be used for extended type _typenr_, or
    #   - false if _typenr_ extended type may not be unpacked (raising an UnpackerError exception instead)
    #
    def exttype typenr
    end

    #
    # Find out how extended type _typenr_ would be unpacked.
    #
    # Unlike {#exttype}, this method does observe the instance and global defaults.
    # The lookup chain consists of:
    # 1.  self.exttype( typenr )
    # 2.  self.default_exttype
    # 3.  Unpacker.exttype( typenr )
    # 4.  Unpacker.default_exttype
    # The search proceeds down the lookup chain until a non-nil value is found.
    #
    # If this method returns +nil+, an attempt to unpack extended type _typenr_
    # will result in an UnpackerError exception.
    #
    # @param typenr [Integer] the extended type number to look up.
    #
    # @return [Class,Method,Proc,nil,false]
    #   - the Class / Method / Proc registered for unpacking this extended type, or
    #   - nil if no info has been found for extended type _typenr_, or
    #   - false if _typenr_ extended type may not be unpacked (raising an UnpackerError exception instead)
    #
    def resolve_exttype typenr
    end

    #
    # Register the global default mechanism for unpacking unknown extended types.
    #
    # It behaves the same as {#default_exttype=}, except that it sets the *global* Unpacker default, not the Unpacker instance default.
    #
    # See {#default_exttype=} for more details.
    #
    def self.default_exttype= arg
    end

    #
    # Retrieve the global default mechanism for unpacking unknown extended types.
    #
    # It behaves the same as {#default_exttype}, except that it gets the *global* Unpacker default, not the Unpacker instance default.
    #
    # See {#default_exttype} for more details.
    #
    # @return [Class,Method,Proc,nil,false]
    #
    def self.default_exttype
    end

    #
    # Register the global default mechanism for unpacking extended type _typenr_.
    #
    # It behaves the same as {#register_exttype}, except that it sets the *global* default behavior for extended type _typenr_, not for an instance.
    # The behavior set by {#register_exttype} always overrides the global default.
    #
    # See {#register_exttype} for more details.
    #
    # @return [Integer] _typenr_
    #
    def self.register_exttype typenr, arg
    end

    #
    # Get the local registration info for extended type number _typenr_.
    #
    # @return [Class,Method,Proc,nil,false]
    #
    def self.exttype
    end

  end

end
