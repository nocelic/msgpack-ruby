# encoding: ascii-8bit
require 'spec_helper'

describe Unpacker do
  let :unpacker do
    Unpacker.new
  end

  let :packer do
    Packer.new
  end

  class Ext
    def self.from_exttype(nr, data, unpacker)
      self.new()
    end
    def deserializer(nr, data, unpacker)
      [nr, data]
    end
  end

  let :extobj do
    Ext.new
  end

  before(:all) do
    $unpacker_default = Unpacker.default_exttype
  end

  after(:all) do
    Unpacker.default_exttype = $unpacker_default
  end

  # TODO initialize

  it 'read_array_header succeeds' do
    unpacker.feed("\x91")
    unpacker.read_array_header.should == 1
  end

  it 'read_array_header fails' do
    unpacker.feed("\x81")
    lambda {
      unpacker.read_array_header
    }.should raise_error(MessagePack::TypeError)
  end

  it 'read_map_header converts an map to key-value sequence' do
    packer.write_array_header(2)
    packer.write("e")
    packer.write(1)
    unpacker = Unpacker.new
    unpacker.feed(packer.to_s)
    unpacker.read_array_header.should == 2
    unpacker.read.should == "e"
    unpacker.read.should == 1
  end

  it 'read_map_header succeeds' do
    unpacker.feed("\x81")
    unpacker.read_map_header.should == 1
  end

  it 'read_map_header converts an map to key-value sequence' do
    packer.write_map_header(1)
    packer.write("k")
    packer.write("v")
    unpacker = Unpacker.new
    unpacker.feed(packer.to_s)
    unpacker.read_map_header.should == 1
    unpacker.read.should == "k"
    unpacker.read.should == "v"
  end

  it 'read_map_header fails' do
    unpacker.feed("\x91")
    lambda {
      unpacker.read_map_header
    }.should raise_error(MessagePack::TypeError)
  end

  it 'skip_nil succeeds' do
    unpacker.feed("\xc0")
    unpacker.skip_nil.should == true
  end

  it 'skip_nil fails' do
    unpacker.feed("\x90")
    unpacker.skip_nil.should == false
  end

  it 'skip skips objects' do
    packer.write(1)
    packer.write(2)
    packer.write(3)
    packer.write(4)
    packer.write(5)

    unpacker = Unpacker.new
    unpacker.feed(packer.to_s)

    unpacker.read.should == 1
    unpacker.skip
    unpacker.read.should == 3
    unpacker.skip
    unpacker.read.should == 5
  end

  it 'read raises EOFError' do
    lambda {
      unpacker.read
    }.should raise_error(EOFError)
  end

  it 'skip raises EOFError' do
    lambda {
      unpacker.skip
    }.should raise_error(EOFError)
  end

  it 'skip_nil raises EOFError' do
    lambda {
      unpacker.skip_nil
    }.should raise_error(EOFError)
  end

  let :sample_object do
    [1024, {["a","b"]=>["c","d"]}, ["e","f"], "d", 70000, 4.12, 1.5, 1.5, 1.5]
  end

  it 'feed and each continue internal state' do
    raw = sample_object.to_msgpack.to_s * 4
    objects = []

    raw.split(//).each do |b|
      unpacker.feed(b)
      unpacker.each {|c|
        objects << c
      }
    end

    objects.should == [sample_object] * 4
  end

  it 'feed_each continues internal state' do
    raw = sample_object.to_msgpack.to_s * 4
    objects = []

    raw.split(//).each do |b|
      unpacker.feed_each(b) {|c|
        objects << c
      }
    end

    objects.should == [sample_object] * 4
  end

  it 'reset clears internal buffer' do
    # 1-element array
    unpacker.feed("\x91")
    unpacker.reset
    unpacker.feed("\x01")

    unpacker.each.map {|x| x }.should == [1]
  end

  it 'reset clears internal state' do
    # 1-element array
    unpacker.feed("\x91")
    unpacker.each.map {|x| x }.should == []

    unpacker.reset

    unpacker.feed("\x01")
    unpacker.each.map {|x| x }.should == [1]
  end

  it 'frozen short strings' do
    raw = sample_object.to_msgpack.to_s.force_encoding('UTF-8')
    lambda {
      unpacker.feed_each(raw.freeze) { }
    }.should_not raise_error
  end

  it 'frozen long strings' do
    raw = (sample_object.to_msgpack.to_s * 10240).force_encoding('UTF-8')
    lambda {
      unpacker.feed_each(raw.freeze) { }
    }.should_not raise_error
  end

  it 'read raises level stack too deep error' do
    512.times { packer.write_array_header(1) }
    packer.write(nil)

    unpacker = Unpacker.new
    unpacker.feed(packer.to_s)
    lambda {
      unpacker.read
    }.should raise_error(MessagePack::StackError)
  end

  it 'skip raises level stack too deep error' do
    512.times { packer.write_array_header(1) }
    packer.write(nil)

    unpacker = Unpacker.new
    unpacker.feed(packer.to_s)
    lambda {
      unpacker.skip
    }.should raise_error(MessagePack::StackError)
  end

  it 'read raises invalid byte error' do
    unpacker.feed("\xc1")
    lambda {
      unpacker.read
    }.should raise_error(MessagePack::MalformedFormatError)
  end

  it 'skip raises invalid byte error' do
    unpacker.feed("\xc1")
    lambda {
      unpacker.skip
    }.should raise_error(MessagePack::MalformedFormatError)
  end

  it "gc mark" do
    raw = sample_object.to_msgpack.to_s * 4

    n = 0
    raw.split(//).each do |b|
      GC.start
      unpacker.feed_each(b) {|o|
        GC.start
        o.should == sample_object
        n += 1
      }
      GC.start
    end

    n.should == 4
  end

  it "buffer" do
    orig = "a"*32*1024*4
    raw = orig.to_msgpack.to_s

    n = 655
    times = raw.size / n
    times += 1 unless raw.size % n == 0

    off = 0
    parsed = false

    times.times do
      parsed.should == false

      seg = raw[off, n]
      off += seg.length

      unpacker.feed_each(seg) {|obj|
        parsed.should == false
        obj.should == orig
        parsed = true
      }
    end

    parsed.should == true
  end

  it 'MessagePack.unpack symbolize_keys' do
    symbolized_hash = {:a => 'b', :c => 'd'}
    MessagePack.load(MessagePack.pack(symbolized_hash), :symbolize_keys => true).should == symbolized_hash
    MessagePack.unpack(MessagePack.pack(symbolized_hash), :symbolize_keys => true).should == symbolized_hash
  end

  it 'Unpacker#unpack symbolize_keys' do
    unpacker = Unpacker.new(:symbolize_keys => true)
    symbolized_hash = {:a => 'b', :c => 'd'}
    unpacker.feed(MessagePack.pack(symbolized_hash)).read.should == symbolized_hash
  end

  it "msgpack str 8 type" do
    MessagePack.unpack([0xd9, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xd9, 0x00].pack('C*')).encoding.should == Encoding::UTF_8
    MessagePack.unpack([0xd9, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xd9, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "msgpack str 16 type" do
    MessagePack.unpack([0xda, 0x00, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xda, 0x00, 0x00].pack('C*')).encoding.should == Encoding::UTF_8
    MessagePack.unpack([0xda, 0x00, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xda, 0x00, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "msgpack str 32 type" do
    MessagePack.unpack([0xdb, 0x00, 0x00, 0x00, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xdb, 0x00, 0x00, 0x00, 0x00].pack('C*')).encoding.should == Encoding::UTF_8
    MessagePack.unpack([0xdb, 0x00, 0x00, 0x00, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xdb, 0x00, 0x00, 0x00, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "msgpack bin 8 type" do
    MessagePack.unpack([0xc4, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xc4, 0x00].pack('C*')).encoding.should == Encoding::ASCII_8BIT
    MessagePack.unpack([0xc4, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xc4, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "msgpack bin 16 type" do
    MessagePack.unpack([0xc5, 0x00, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xc5, 0x00, 0x00].pack('C*')).encoding.should == Encoding::ASCII_8BIT
    MessagePack.unpack([0xc5, 0x00, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xc5, 0x00, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "msgpack bin 32 type" do
    MessagePack.unpack([0xc6, 0x00, 0x00, 0x00, 0x00].pack('C*')).should == ""
    MessagePack.unpack([0xc6, 0x0, 0x00, 0x00, 0x000].pack('C*')).encoding.should == Encoding::ASCII_8BIT
    MessagePack.unpack([0xc6, 0x00, 0x00, 0x00, 0x01].pack('C*') + 'a').should == "a"
    MessagePack.unpack([0xc6, 0x00, 0x00, 0x00, 0x02].pack('C*') + 'aa').should == "aa"
  end

  it "should register extended types with a class" do
    unpacker.register_exttype 64, Ext
    #
    unpacker.exttype(64).should == Ext
    unpacker.feed("\xD5@xx").unpack.class.should == Ext
  end

  it "should register extended types with a bound method" do
    unpacker.register_exttype 65, extobj.method( :deserializer)
    #
    unpacker.exttype(65).class.should == Method
    unpacker.feed("\xD5Ayy").unpack.should == [65, "yy"]
  end

  it "should register extended types with a block" do
    unpacker.register_exttype(66) { |nr, data, unpacker| {nr => data} }
    #
    unpacker.exttype(66).class.should == Proc
    unpacker.feed("\xD5Bzz").unpack.should == {66 => "zz"}
  end

  it "should refuse unknown exttypes by default" do
    unpacker.default_exttype = false
    #
    unpacker.default_exttype.should == false
    unpacker.exttype(63).should == nil
    unpacker.resolve_exttype(63).should == false
    lambda{ unpacker.feed("\xD5?aa").unpack }.should raise_error(MessagePack::UnpackError)
  end

  it "should refuse selected unknown exttypes" do
    unpacker.register_exttype 64, false
    #
    unpacker.default_exttype.should == nil
    unpacker.exttype(64).should == false
    unpacker.resolve_exttype(64).should == false
    lambda{ unpacker.feed("\xD5@aa").unpack }.should raise_error(MessagePack::UnpackError)
    lambda{ unpacker.feed("\xD5!aa").unpack }.should_not raise_error
  end

  it "should set instance default exttype handler to a class" do
    unpacker.default_exttype = Ext
    #
    unpacker.default_exttype.should == Ext
    unpacker.exttype(75).should == nil
    unpacker.resolve_exttype(75).should == Ext
    unpacker.feed("\xD5Jxx").unpack.class.should == Ext
  end

  it "should set instance default exttype handler to a bound method" do
    unpacker.default_exttype = extobj.method( :deserializer)
    #
    unpacker.default_exttype.class.should == Method
    unpacker.exttype(75).should == nil
    unpacker.resolve_exttype(75).class.should == Method
    unpacker.feed("\xD5Kyy").unpack.should == [75, "yy"]
  end

  it "should set instance default exttype handler to a proc" do
    unpacker.default_exttype = proc{ |nr, data, unpacker| {nr => data} }
    #
    unpacker.default_exttype.class.should == Proc
    unpacker.exttype(76).should == nil
    unpacker.resolve_exttype(76).class.should == Proc
    unpacker.feed("\xD5Lzz").unpack.should == {76 =>"zz"}
  end

  it "should set global default exttype handler to a class" do
    Unpacker.default_exttype = ExtType
    #
    Unpacker.default_exttype.should == ExtType
    unpacker.exttype(77).should == nil
    unpacker.resolve_exttype(77).should == ExtType
    unpacker.feed("\xD5Mxx").unpack.should == ExtType[77, "xx"]
  end

  it "should set global default exttype handler to a bound method" do
    Unpacker.default_exttype = extobj.method( :deserializer)
    #
    Unpacker.default_exttype.class.should == Method
    unpacker.exttype(78).should == nil
    unpacker.resolve_exttype(78).class.should == Method
    unpacker.feed("\xD5Nyy").unpack.should == [78, "yy"]
  end

  it "should set global default exttype handler to a proc" do
    Unpacker.default_exttype = proc{ |nr, data, unpacker| {nr => data} }
    #
    Unpacker.default_exttype.class.should == Proc
    unpacker.exttype(79).should == nil
    unpacker.resolve_exttype(79).class.should == Proc
    unpacker.feed("\xD5Ozz").unpack.should == {79 => "zz"}
  end

  it "should globally refuse unknown exttypes by default if so instructed" do
    Unpacker.default_exttype = false
    #
    Unpacker.default_exttype.should == false
    unpacker.exttype(80).should == nil
    unpacker.resolve_exttype(80).should == false
    lambda{ unpacker.feed("\xD5Pww").unpack }.should raise_error(MessagePack::UnpackError)
  end

  it "should globally register exttypes by class" do
    Unpacker.default_exttype = false
    # -----
    Unpacker.register_exttype 88, Ext
    #
    Unpacker.default_exttype.should == false
    unpacker.resolve_exttype(87).should == false
    unpacker.resolve_exttype(88).should == Ext
    unpacker.feed("\xD5Xxx").unpack.class.should == Ext
  end

  it "should globally register exttypes with a block" do
    Unpacker.default_exttype = false
    # -----
    Unpacker.register_exttype(89) { |nr, data, unpacker| {nr => data} }
    #
    Unpacker.default_exttype.should == false
    unpacker.resolve_exttype(87).should == false
    unpacker.resolve_exttype(89).class.should == Proc
    unpacker.feed("\xD5Yyy").unpack.should == {89 => "yy"}
  end

end

