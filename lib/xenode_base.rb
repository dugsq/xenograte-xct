# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

module XenoCore

  module NodeBase

    attr_reader :config, :msg_count, :start_time

    # initialize class variables from framework
    def initialize(opts)
      begin
        @account_id  = "XCT"
        @xenoflow_id = opts[:xenoflow_id]
        @xenode_id   = opts[:xenode_id]
        @shared_dir  = opts[:shared_dir]
        @log_path    = opts[:log_path]
        @log         = opts[:log]
        @log.debug("#{self.class}.#{__method__} opts[:xenode_config]: #{opts[:xenode_config]}")
        @config      = {}
        @config      = opts[:xenode_config]
        @loop_delay  = opts.fetch(:loop_delay, 5.0)
        @loop_delay  = @config[:loop_delay] if @config[:loop_delay]
        @log.debug("#{self.class}.#{__method__} loop_delay: #{@loop_delay}")
      rescue Exception => e
        warn "#{e.inspect} #{e.backtrace}"
      end
    end

    # startup abstract - implemented in xenode
    def startup()
    end

    # shutdown abstract - implemented in xenode
    def shutdown()
    end

    def on_message(&blk)
      @write_to_message_callback = blk if blk
    end

    def on_write_to_xenode(&blk)
      @write_to_xenode_callback = blk if blk
    end

    def write_to_children(msg)
      @write_to_message_callback.call(msg) if @write_to_message_callback
    end

    def write_to_xenode(xenode_id, msg)
      @write_to_xenode_callback.call(xenode_id, msg) if @write_to_xenode_callback
    end

    def process
    end
    
    def process_message(msg)
    end
    
    # do_debug lets you force logging of debug info even
    # if @debug is false, if force is true.
    # otherwise it will use the @debug flag.
    def do_debug(msg, force = false)
      if msg && @log
        if @debug || force
          @log.debug(msg)
        end
      end
    end
    
    def catch_error(error_message, reraise = false)
      if error_message
        @log ? @log.error(error_message) : warn(error_message)
        raise(Exception, error_message) if reraise
      end
    end
    
  end
  
end
