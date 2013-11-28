# XenoCore::Nodebase
# Copyright © Nodally Technologies Inc. 2009 - 2013 (All Rights Reserved).
#

module XenoCore

  module XenodeBase

    attr_reader :config, :msg_count, :start_time
    
    # initialize class variables from framework
    def initialize(opts)
      begin
        @account_id  = "XCT"
        @xenoflow_id = opts[:xenoflow_id]
        @log         = opts[:log]
        @xenode_id   = opts[:xenode_id]
        @disk_dir    = opts[:disk_dir]
        @log_path    = opts[:log_path]
        @tmp_dir     = opts[:tmp_dir]
        @config      = opts[:config]
        @debug       = opts[:config][:debug] if opts[:config]
        @loop_delay  = opts.fetch(:loop_delay, 5.0)
        @msg_count   = 0
        @start_time  = 0.0
        
        opts = nil
        
      rescue Exception => e
        emsg = "#{self.class}.#{__method__} - #{e.inspect} #{e.backtrace}"
        if @log
          @log.error(emsg)
        else
          if @log_path
            File.open(@log_path, "a") do |f|
              f.write("#{Time.now} #{emsg}")
            end
          end
        end
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
    
    def resolve_sys_dir(fp)
      if fp
        fp.gsub!("@this_node", @disk_dir) if fp.include?("@this_node") && @disk_dir
        fp.gsub!("@this_server", @tmp_dir) if fp.include?("@this_server") && @tmp_dir
      end
      fp
    end
    
    # # James: this method is used to apply the system token into the config
    # def apply_sys_token(config)
    #   if config.is_a?(String)
    #     # this is where we substitute token with values
    #     config.gsub!("@disk_dir", @disk_dir) if config.include?("@disk_dir") && @disk_dir
    #     config.gsub!("@tmp_dir", @tmp_dir) if config.include?("@tmp_dir") && @tmp_dir
    #   elsif config.is_a?(Hash)
    #     config.each_pair do |key, value|
    #       config[key] = apply_sys_token(value)
    #     end
    #     #END each_pair
    #   end 
    #   config
    # end
    # #END apply_sys_token
    
    
  end
  
end
