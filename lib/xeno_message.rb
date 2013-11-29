# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

sys_lib = File.expand_path(File.dirname(__FILE__))
require File.join(sys_lib, "xeno_util")

require 'uuidtools'
require 'msgpack'

module XenoCore

  class Message
    
    STAMP_FMT = "%Y%m%d%H%M%S%L"
    PACKED_PREFIX = "|^P^|"
    CMD_PREFIX = "~cmd"
    
    attr_accessor :msg_id, :correlation_id, :to_id, :from_id, 
                  :command, :context, :data, :account_id, :stamp
    
    def initialize(opts = {})
      @util = XenoCore::Util.new
      
      @account_id     = opts[:account_id]
      @stamp          = opts.fetch(:stamp, Time.now.strftime(STAMP_FMT))
      @msg_id         = opts.fetch(:msg_id, new_id)
      @correlation_id = opts.fetch(:correlation_id, new_id)
      @to_id          = opts[:to_id]
      @from_id        = opts[:from_id]
      @command        = opts[:command]
      @context        = opts[:context]
      @data           = opts[:data]
    end
  
    def load(msg)
      # if it's a xeno message get its hash
      msg = msg.to_hash if msg.is_a?(XenoCore::Message)
      
      # unpack it if it is packed
      if msg.is_a?(String)
        msg[0..4] == PACKED_PREFIX
        msg = XenoCore::Message.unpack(msg)
      end
      
      # load local values if its a hash
      if msg.is_a?(Hash)
        # preserve context and data content keys
        msg_hash = @util.symbolize_hash_keys(msg)
        @account_id = msg_hash[:account_id]
        @stamp = msg_hash[:stamp]
        @msg_id = msg_hash[:msg_id]
        @correlation_id = msg_hash[:correlation_id]
        @to_id = msg_hash[:to_id]
        @from_id = msg_hash[:from_id]
        @command = msg_hash[:command]
        @context = msg_hash[:context]
        @data = msg_hash[:data]
      end
      self
    end
    
    def to_hash
      msg_hash = {}
      msg_hash[:account_id] = @account_id
      msg_hash[:stamp] = @stamp
      msg_hash[:msg_id] = @msg_id
      msg_hash[:correlation_id] = @correlation_id
      msg_hash[:to_id] = @to_id
      msg_hash[:from_id] = @from_id
      msg_hash[:command] = @command
      msg_hash[:context] = @context
      msg_hash[:data] = @data
      msg_hash
    end
  
    def self.unpack(msg)
      # remove packed prefix
      if msg[0..4] == PACKED_PREFIX
        msg = msg[5..-1]
      end
      MessagePack.unpack(msg)
    end
  
    def pack
      msg_hash = self.to_hash
      "#{PACKED_PREFIX}#{msg_hash.to_msgpack}"
    end
    
    def command?
      ret_val = nil
      begin
        ret_val = (@command && @command.length > 0 )
      rescue Exception => e
         raise("Message.command?() Error - #{e.inspect}")
      end
      ret_val
    end
    
    def new_id
      UUIDTools::UUID.random_create().to_s
    end
  
  end

end
