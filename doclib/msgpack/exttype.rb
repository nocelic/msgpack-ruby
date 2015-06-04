module MessagePack

  class ExtType

    #
    # Make this class the global default target for unpacking unregistered extended types.
    #
    # This is useful in compatibility subclasses of +ExtType+: {Extended}, {ExtendedValue}, {ExtensionValue}.
    #
    # Explicit type registration via {Unpacker#register_exttype} or {Unpacker.register_exttype} always takes precedence over this default.
    #
    def self.set_as_global_default
    end

    #
    # Helper method for safe packing of extended types.
    #
    # It is intended to be used from +to_msgpack+ instance methods
    # to avoid unsafe manual writes to packer buffer during low-level
    # packing.
    #
    # @overload self.pack packer, typenr, data
    #   The fast variant writing directly to _packer_.
    #
    #   @param packer [Integer] the packer to write to.
    #   @param typenr [Integer] the extended type number +0..127+.
    #   @param data [Integer] the extended type data (payload).
    #
    #   @return [Packer] _packer_
    #
    # @overload self.pack typenr, data
    #   The slow variant that creates an ExtType instance and packs it.
    #   This in turn creates a new instance of +Packer+, packs the ExtType and
    #   returns the contents of its buffer as a +String+.
    #
    #   This variant is useful for one-off packing. For repeated packing,
    #   it is recommended to create a permanent +Packer+ instance and use
    #   the above 3-parameter overload.
    #
    #   @param typenr [Integer] the extended type number +0..127+.
    #   @param data [String] the extended type data (payload).
    #
    #   @return [String] packed exttype.
    #
    def self.pack packer, typenr, data
    end

    #
    #  Same as self.new.
    #
    #  See {#initialize} for details.
    #
    def self.[](typenr, data)
    end

    #
    #  Same as self.new(typenr, data).
    #
    #  Intended to be called internally by the _unpacker_.
    #
    def self.from_exttype(typenr, data)
    end

    #
    # Creates an ExtType instance.
    #
    # @param typenr [Integer] the extended type number +0..127+.
    # @param data [String] the extended type raw data (payload).
    #   No further processing will be done on this string when packing the exttype.
    #
    def initialize typenr, data
    end

    #
    # Get extended type number
    #
    # @return [Integer] +0..127+
    #
    def type
    end

    #
    # Get raw data (payload)
    #
    # @return [String] raw data (payload)
    #
    def data
    end

    #
    # Test for equality of extended type objects.
    #
    # Instances of ExtType and all ExtType subclasses compare mutually equal
    # iff their type and data are equal.
    #
    # @return [true,false]
    #
    def ==(it)
    end

    #
    # Produce exttype data (payload) for packing.
    #
    # It is intended to be called during high-level packing of +ExtType+ instances.
    #
    # @return [String] raw data (payload)
    #
    def to_exttype()
    end

    #
    # Pack this ExtType instance.
    #
    # It is intended to be called for low-level packing of +ExtType+ instances.
    #
    # @overload to_msgpack(packer)
    #   write directly to _packer_ buffer.
    #   @param [Packer] packer
    #   @return [Packer] _packer_
    #
    # @overload to_msgpack()
    #   create a new +Packer+, pack this instance to it and return its buffer as a String.
    #   @return [String] +self+ packed to a String.
    #
    def to_msgpack(packer)
    end

  end

  #
  # Compatibility ExtType subclass. Tries to emulate the MessagePack specification language.
  # Call .set_as_global_default to use it instead of ExtType (see {ExtType.set_as_global_default}).
  #
  class Extended < ExtType
  end

  #
  # Compatibility ExtType subclass. Tries to emulate the Java MessagePack library.
  # Call .set_as_global_default to use it instead of ExtType (see {ExtType.set_as_global_default}).
  #
  class ExtendedValue < ExtType
  end

  #
  # Compatibility ExtType subclass. Tries to emulate the JRuby MessagePack library.
  # Call .set_as_global_default to use it instead of ExtType (see {ExtType.set_as_global_default}).
  #
  class ExtensionValue < ExtType
  end

end
