# encoding: ascii-8bit
require 'spec_helper'

describe ExtType do
  let :unpacker do
    Unpacker.new
  end

  let :packer do
    Packer.new
  end

  it "should create new instances from type and data" do
    lambda{ ExtType.new   0, "ab" }.should_not raise_error
    lambda{ ExtType.new 127, "ab" }.should_not raise_error
  end

  it "should reject invalid types" do
    lambda{ ExtType.new  -1, "ab" }.should raise_error
    lambda{ ExtType.new 128, "ab" }.should raise_error
  end

  it "should reject invalid data" do
    lambda{ ExtType.new 1, 1 }.should raise_error
    lambda{ ExtType.new 1, [] }.should raise_error
    lambda{ ExtType.new 1, {} }.should raise_error
    lambda{ ExtType.new 1, :test }.should raise_error
  end

  it "ExtType.pack works properly" do
    ExtType.pack(packer, 45, ":)").to_s.should == "\xD5-:)"
  end

  it "ExtType.pack rejects invalid types" do
    lambda{ ExtType.pack(packer,  -1, ":x") }.should raise_error
    lambda{ ExtType.pack(packer, 128, ":x") }.should raise_error
  end

  it "ExtType.pack rejects invalid data" do
    lambda{ ExtType.pack(packer, 0, 1) }.should raise_error
    lambda{ ExtType.pack(packer, 0, []) }.should raise_error
    lambda{ ExtType.pack(packer, 0, {}) }.should raise_error
    lambda{ ExtType.pack(packer, 0, :test) }.should raise_error
  end

end
