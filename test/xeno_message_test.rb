# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require "minitest/autorun"
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'xeno_message'))

module Helpers
  
  def chk_msg(msg, time_str)
    msg.to_hash[:account_id].must_equal "xct"
    msg.stamp.must_equal time_str
    msg.to_id.must_equal "to_id"
    msg.from_id.must_equal "from_id"
    msg.command.must_equal "command"
    msg.context.must_equal "context"
    msg.data.must_equal "data"
  end
  
  def chk_hash(hash, time_str)
    hash['account_id'].must_equal "xct"
    hash['stamp'].must_equal time_str
    hash['to_id'].must_equal "to_id"
    hash['from_id'].must_equal "from_id"
    hash['command'].must_equal "command"
    hash['context'].must_equal "context"
    hash['data'].must_equal "data"
  end
  
  def chk_empty_init(msg)
    msg.account_id.must_be_nil
    msg.msg_id.wont_be_nil
    msg.correlation_id.wont_be_nil
    msg.msg_id.length.must_equal 36
    msg.correlation_id.length.must_equal 36
    # no %L on time format so we can just check to the seconds
    time_str = Time.now.strftime("%Y%m%d%H%M%S")
    # truncate result to only include first 14 chars of stamp
    msg.stamp[0..13].must_equal time_str
    msg.to_id.must_be_nil
    msg.from_id.must_be_nil
    msg.command.must_be_nil
    msg.context.must_be_nil
    msg.data.must_be_nil
  end
  
end

describe "Xeno Message tests" do
  include Helpers
  
  before do
    @msg_hash = {
      account_id: "xct",
      to_id:   "to_id",
      from_id: "from_id",
      context: "context",
      data:    "data",
      command: "command"
    }
  end
  
  describe "Test loading of message" do
    
    it 'should create a message with no arguments' do
      msg = XenoCore::Message.new
      chk_empty_init(msg)
    end
    
    it 'should initialize a message from a hash' do
      # initialize from a hash 
      # use truncated string format here
      time_str = Time.now.strftime("%Y%m%d%H%M")
      hash = @msg_hash.merge(:stamp => time_str)
      msg = XenoCore::Message.new(hash)
      chk_msg(msg, time_str)
    end

    it 'should load a message from a hash' do
      # use truncated string format here
      time_str = Time.now.strftime("%Y%m%d%H%M")
      hash = @msg_hash.merge(:stamp => time_str)
      m = XenoCore::Message.new(hash)
      msg = XenoCore::Message.new
      msg = msg.load(m)
      chk_msg(msg, time_str)
    end

    it 'should load a packed message' do
      time_str = Time.now.strftime("%Y%m%d%H%M")
      hash = @msg_hash.merge(:stamp => time_str)
      m = XenoCore::Message.new(hash)
      msg = XenoCore::Message.new
      msg = msg.load(m.pack)
      chk_msg(msg, time_str)
    end

  end

  describe "Test message methods" do

    it 'should report nil if an empty command' do
      msg = XenoCore::Message.new
      msg.command?.must_be_nil
    end
    
    it 'should report true if command' do
      msg = XenoCore::Message.new
      msg.command = "command"
      msg.command?.must_equal true
    end
    
    it 'should unpack a packed message' do
      # use truncated string format here
      time_str = Time.now.strftime("%Y%m%d%H%M")
      hash = @msg_hash.merge(:stamp => time_str)
      m = XenoCore::Message.new(hash)
      packed = m.pack
      h = XenoCore::Message.unpack(packed)
      h.must_be_kind_of Hash
      chk_hash(h, time_str)
    end
    
    it 'should return a sybolized hash' do
      msg = XenoCore::Message.new(@msg_hash)
      hash = msg.to_hash
      hash.keys.each do |k|
        k.is_a?(Symbol).must_equal true
      end
    end
    
    it 'should symbolize hash keys' do
      msg = XenoCore::Message.new(@msg_hash)
      hash = msg.symbolize_hash_keys(msg.to_hash)
      hash.keys.each do |k|
        k.is_a?(Symbol).must_equal true
      end
    end
    
  end
  
end