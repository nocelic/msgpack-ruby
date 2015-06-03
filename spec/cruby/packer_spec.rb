# encoding: ascii-8bit
require 'spec_helper'

require 'stringio'
if defined?(Encoding)
  Encoding.default_external = 'ASCII-8BIT'
end

describe Packer do

  class Ext
    def to_exttype(nr, pk)
      '.o0'
    end
    def to_msgpack(packer)
      ExtType.pack packer, 42, self.to_exttype(0,packer)
    end
    def custom_exttype(*arg)
      '.:|'
    end
    def pack_lowlevel(packer)
      ExtType.pack packer, 35, self.custom_exttype(0,packer)
    end
  end

  let :packer do
    Packer.new
  end

  let :packer_of_known_types do
    Packer.new :unknown_class => false
  end

  let :extobj do
    Ext.new
  end

  it 'initialize' do
    Packer.new
    Packer.new(nil)
    Packer.new(StringIO.new)
    Packer.new({})
    Packer.new(StringIO.new, {})
  end

  #it 'Packer' do
  #  Packer(packer).object_id.should == packer.object_id
  #  Packer(nil).class.should == Packer
  #  Packer('').class.should == Packer
  #  Packer('initbuf').to_s.should == 'initbuf'
  #end

  it 'write' do
    packer.write([])
    packer.to_s.should == "\x90"
  end

  it 'write_nil' do
    packer.write_nil
    packer.to_s.should == "\xc0"
  end

  it 'write_array_header 0' do
    packer.write_array_header(0)
    packer.to_s.should == "\x90"
  end

  it 'write_array_header 1' do
    packer.write_array_header(1)
    packer.to_s.should == "\x91"
  end

  it 'write_map_header 0' do
    packer.write_map_header(0)
    packer.to_s.should == "\x80"
  end

  it 'write_map_header 1' do
    packer.write_map_header(1)
    packer.to_s.should == "\x81"
  end

  it 'flush' do
    io = StringIO.new
    pk = Packer.new(io)
    pk.write_nil
    pk.flush
    pk.to_s.should == ''
    io.string.should == "\xc0"
  end

  it 'to_msgpack returns String' do
    nil.to_msgpack.class.should == String
    true.to_msgpack.class.should == String
    false.to_msgpack.class.should == String
    1.to_msgpack.class.should == String
    1.0.to_msgpack.class.should == String
    "".to_msgpack.class.should == String
    Hash.new.to_msgpack.class.should == String
    Array.new.to_msgpack.class.should == String
  end

  class CustomPack01
    def to_msgpack(pk=nil)
      return MessagePack.pack(self, pk) unless pk.class == MessagePack::Packer
      pk.write_array_header(2)
      pk.write(1)
      pk.write(2)
      return pk
    end
  end

  class CustomPack02
    def to_msgpack(pk=nil)
      [1,2].to_msgpack(pk)
    end
  end

  it 'calls custom to_msgpack method' do
    MessagePack.pack(CustomPack01.new).should == [1,2].to_msgpack
    MessagePack.pack(CustomPack02.new).should == [1,2].to_msgpack
    CustomPack01.new.to_msgpack.should == [1,2].to_msgpack
    CustomPack02.new.to_msgpack.should == [1,2].to_msgpack
  end

  it 'calls custom to_msgpack method with io' do
    s01 = StringIO.new
    MessagePack.pack(CustomPack01.new, s01)
    s01.string.should == [1,2].to_msgpack

    s02 = StringIO.new
    MessagePack.pack(CustomPack02.new, s02)
    s02.string.should == [1,2].to_msgpack

    s03 = StringIO.new
    CustomPack01.new.to_msgpack(s03)
    s03.string.should == [1,2].to_msgpack

    s04 = StringIO.new
    CustomPack02.new.to_msgpack(s04)
    s04.string.should == [1,2].to_msgpack
  end

  it "register_exttype with no handler" do
    packer.register_exttype Ext, 55
    #
    packer.exttype(Ext).should == [55, Ext]
    packer.pack(extobj).to_s.should == "\xC7\x037.o0"
    MessagePack.pack(extobj).should == "\xC7\x03*.o0"
  end

  it "register_exttype with method name" do
    packer.register_exttype Ext, 55, :custom_exttype
    #
    packer.exttype(Ext).should == [55, :custom_exttype]
    packer.pack(extobj).to_s.should == "\xC7\x037.:|"
  end

  it "register_exttype with block" do
    packer.register_exttype(Ext, 55) { |type, packer| "-=+" }
    #
    packer.exttype(Ext).last.class.should == Proc
    packer.pack(extobj).to_s.should == "\xC7\x037-=+"
  end

  it "unregister exttype via register_exttype" do
    packer.register_exttype Ext, 55
    packer.exttype(Ext).should == [55, Ext]
    # -----
    packer.register_exttype Ext, nil, nil
    #
    packer.exttype(Ext).should == nil
    packer.clear
    packer.pack(extobj).to_s.should == "\xC7\x03*.o0"
  end

  it "unregister exttype via unregister_exttype" do
    packer.register_exttype Ext, 55
    packer.exttype(Ext).should == [55, Ext]
    # -----
    packer.unregister_exttype Ext
    #
    packer.exttype(Ext).should == nil
    packer.clear
    packer.pack(extobj).to_s.should == "\xC7\x03*.o0"
  end

  it "should refuse unknown classes if so created" do
    pk= packer_of_known_types
    #
    pk.register_exttype Ext, 55
    pk.exttype(Ext).should == [55, Ext]
    pk.exttype(Object).should == nil
    pk.resolve_exttype(Object).should == false
    # -----
    pk.unregister_exttype Ext
    #
    pk.resolve_exttype(Ext).should == false
    lambda{ pk.pack(extobj) }.should raise_exception(TypeError)
  end

  it "should allow low level packing by the packed object itself" do
    packer.register_exttype Ext, nil, :pack_lowlevel
    #
    packer.exttype(Ext).should == [nil, :pack_lowlevel]
    packer.pack(extobj).to_s.should == "\xC7\x03#.:|"
  end

  it "should allow low level packing by a block" do
    packer.register_exttype(Ext, nil) { |obj, packer| ExtType.pack packer, 37, "-=+" }
    #
    packer.exttype(Ext).last.class.should == Proc
    packer.pack(extobj).to_s.should == "\xC7\x03%-=+"
  end

  it "should allow low level packing via register_lowlevel method" do
    packer.register_lowlevel Ext, :pack_lowlevel
    #
    packer.exttype(Ext).should == [nil, :pack_lowlevel]
    packer.pack(extobj).to_s.should == "\xC7\x03#.:|"
  end

  it "should allow low level packing by a block via register_lowlevel" do
    packer.register_lowlevel(Ext) { |obj, packer| ExtType.pack packer, 38, "-=+" }
    #
    packer.exttype(Ext).last.class.should == Proc
    packer.pack(extobj).to_s.should == "\xC7\x03&-=+"
  end

end

