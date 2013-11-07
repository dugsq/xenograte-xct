# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require 'logger'
require 'yaml'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'fileutils'
require 'eventmachine'
require 'redis'
require 'em-hiredis'

# this clss is called to fork a new instance of a xenode.
class InstanceXenode

  TIMEFMT = "%Y-%m-%d %H:%M:%S.%L"

  def initialize(args)
    # method context for debugging
    mctx = "#{self.class}.#{__method__}"

    begin
      # these are the required_options
      @required_opts = %w"xenode_id xenode_file xenode_class"

      # parse options
      opts = opts_parse(args)

      # process the options creates @opts hash for options
      process_options(opts)

      # set the directories up
      set_dirs()

      # require lib files
      require File.join(@dir_set[:sys_lib], "xeno_message")
      require File.join(@dir_set[:sys_lib], "xenode_base")
      require File.join(@dir_set[:sys_lib], "xeno_queue")

      @xenode_basename = File.basename(@opts[:xenode_file],".rb")
      require File.join(@dir_set[:xenode_lib_dir], @xenode_basename, 'lib', @xenode_basename )
      
      # setup the log
      set_log()
      
      # dir_set
      do_debug("#{mctx} - @dir_set: #{@dir_set.inspect}", true)
      
      do_debug("#{mctx} - xenode_class: #{@xenode_class.inspect}")

      # # show the info to console
      # puts "\n* run xenode with options:\n"
      # puts "  xenode_id: #{@xenode_id}"
      # puts "  xenode_class: #{@xenode_class}"
      # puts "  redis: #{@opts[:redis_host]}:#{@opts[:redis_port]}"
      
      # see if redis server is running
      rpid = `ps -e -o pid -o comm | grep [r]edis-server`
      if rpid.to_s.empty?
        emsg = "\n#{mctx} - Xenode stopped: Redis server is not running.\nrun 'redis-server &' to start Redis first"
        warn emsg
        catch_error(emsg)
        exit!
      end
      
      # run the xenode
      do_debug("\n#{mctx} - spawning xenode: #{@xenode_id} with options: #{opts.inspect}", true)
      
    rescue Exception => e
      emsg = "#{e.inspect} #{e.backtrace}"
      if @log
        @log.error(emsg)
      else
        raise Exception, emsg
      end
      exit
    end

  end

  def spawn_xenode
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    # raise an error if the xenode is already running
    raise RuntimeError, "#{mctx} - Xenode: is already running." if xenode_running?

    # none of the below happens if xenode is already running...

    # daemonize - this class should have been called with fork()
    Process.daemon(true,true)

    # redirect sdtout to null & sdterr to file to capture errors
    $stdout.reopen("/dev/null", "w")
    $stderr.reopen(@pid_path, "a")

    # capture the pid
    pid = $$
    # write the pid to disk - true param will overwrite the file
    lock_write(@pid_path, pid, true)

    # setup at_exit processing
    at_exit do
      tm = Time.now.strftime(TIMEFMT)
      # record the shutdown time and the value of the shutdown flag
      emsg = "#{mctx} - Exit at #{tm} shutdown = #{@shutdown.inspect}"
      # true in do_debug() will force debug to be written
      do_debug(emsg, true)
      # remove the pid file for this process
      File.unlink(@pid_path) if File.exist?(@pid_path)
    end

    @xenode_obj = nil
    
    begin
      # fire up the EM loop
      EM.run do

        # pass-in usefull options
        opts = {}
        opts[:log_path]  = @log_path
        opts[:log] = @log
        opts[:xenode_id] = @xenode_id
        opts[:xenode_config] = load_xenode_config()
        opts[:config] = opts[:xenode_config][:config]
        opts[:disk_dir] = @dir_set[:disk_dir]
        opts[:tmp_dir] = @dir_set[:tmp_dir]
        opts[:redis_conn] = @redis_conn
        
        # check if xenode is enabled
        if opts[:config] && opts[:config][:enabled]
        
          @loop_delay = opts[:xenode_config][:loop_delay] if opts[:xenode_config] && opts[:xenode_config][:loop_delay]
          @loop_delay ||= 0.5

          @dir_set = nil

          # create the xenode
          @xenode_obj = Object.const_get(@xenode_class).new(opts)

          # create the xenode_queue object
          @xenode_queue = XenoCore::XenoQueue.new(opts)

          # add the write_to_children method to the xenode class with callback
          @xenode_obj.on_message do |msg|
            do_debug("#{mctx} - calling #{@xenode_id}.write_to_children msg: #{msg.inspect}")
            @xenode_queue.write_to_children(msg)
          end

          # add write to xenode method to the xenode class with callback
          @xenode_obj.on_write_to_xenode do |to_xenode_id, msg|
            do_debug("#{mctx} - calling #{@xenode_id}.write_to_xenode to_xenode_id: #{to_xenode_id} msg: #{msg.inspect}")
            @xenode_queue.write_to_xenode(to_xenode_id, msg)
          end

          # call Xenode's process_message() with xenode_queue
          @xenode_queue.on_message do |msg|
            do_debug("#{mctx} - calling process_message msg: #{msg.inspect}")
            # send orig msg to xenode's process_message
            @xenode_obj.process_message(msg)
          end

          # call xenode's startup() method
          do_debug("#{mctx} - calling startup on xenode.", true)
          # don't pass in options here as options are already passed in xenode constructor
          # @xenode_obj.startup({:log => @log})
          @xenode_obj.startup()

          # capture the signal so we can die nice
          [:QUIT, :TERM, :INT].each do |sig|
            trap(sig) do
              @shutdown = true
            end
          end

          # call xenode's process() method periodically based on loop_delay value if it is defined
          if defined?(@xenode_obj.process)
            EM.add_periodic_timer(@loop_delay) do
              do_debug("#{mctx} process called.")
              @xenode_obj.process
            end
          end

          # add periodic timer to check to see if we need to shut down
          EM.add_periodic_timer(0.5) do
            if @shutdown
              # call the shutdown on the xenode so it can clean up
              @xenode_obj.shutdown()
              # end the eventmachine loop
              EM.stop
            end
          end
          
        else
          catch_error("#{mctx} - ERROR Xenode is not enabled.")
          # end the eventmachine loop
          EM.stop
        end
        
      end # EM.run
    rescue Exception => e
      catch_error("#{mctx} - ERROR #{e.inspect} #{e.backtrace}")
    end
  end

  def opts_parse(args)
    options = {}

    opts = OptionParser.new do |opts|

      opts.on("-f", "--file FILE",
               "Set the file to run to FILE") do |file|
        options[:xenode_file] = File.basename(file)
      end

      opts.on("-k", "--klass XENODE_CLASS",
               "Set the xenode class to NODE_CLASS") do |klass|
        options[:xenode_class] = klass
      end

      opts.on("-i", "--id [XENODE_ID]",
               "Set the xenode id to XENODE_ID") do |id|
        options[:xenode_id] = id
      end

      opts.on("-x", "--xenoflow XENOFLOW_ID",
               "Set the Node's xenoflow id to XENOFLOW_ID") do |xenoflow_id|
        options[:xenoflow_id] = xenoflow_id
      end

      opts.on("-d", "--[no-]debug", "Set log to debug level") do |v|
        options[:debug] = v
      end
      
      opts.on("--redis-host REDIS_HOST", "Set redis_host to REDIS_HOST") do |redis_host|
        options[:redis_host] = redis_host
      end
      
      opts.on("--redis-port REDIS_PORT", "Set redis_port to REDIS_PORT") do |redis_port|
        options[:redis_port] = redis_port
      end
      
      opts.on("--redis-db REDIS_DB", "Set redis_db to REDIS_DB") do |redis_db|
        options[:redis_db] = redis_db
      end
      

    end

    opts.parse!(args)

    options

  end
  
  # this will load xenode's config in run directory
  # NOTE that it will return xenode_config, NOT just the config key inside it 
  def load_xenode_config
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    # get default config
    def_cfg = {}
    def_cfg_path = File.expand_path(File.join(@dir_set[:xenode_lib_dir], @xenode_basename, 'config','config.yml'))
    if File.exist?(def_cfg_path)
      yml = File.read(def_cfg_path)
      def_cfg = YAML.load(yml) if yml
      def_cfg = symbolize_hash_keys(def_cfg)
    end
    def_cfg[:loop_delay] = 5.0 unless def_cfg.has_key?(:loop_delay)
    def_cfg[:enabled] = true unless def_cfg.has_key?(:enabled)
    def_cfg[:debug] = false unless def_cfg.has_key?(:debug)
    
    # get run config ** NOTE that run_cfg's structure is DIFFERENT than def_cfg
    run_cfg = {}
    run_cfg_path = File.join(@dir_set[:config_dir],'config.yml')
    # if run config exist, merge it from default config
    if File.exist?(run_cfg_path)
      yml = File.read(run_cfg_path)
      run_cfg = YAML.load(yml) if yml
      run_cfg = symbolize_hash_keys(run_cfg)
      run_cfg[:config] = def_cfg.merge(run_cfg[:config])
    # if NOT exist, add default config and write it do run directory
    else
      run_cfg[:config] = def_cfg.merge(run_cfg[:config])
      hash = stringify_hash_keys(run_cfg)
      lock_write(run_cfg_path, YAML.dump(hash))
    end
    
    do_debug("#{mctx} - xenode_config: #{run_cfg.inspect}", true)
    run_cfg
  end

  def process_options(opts)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    @opts = {
      :xenode_id => nil,
      :xenode_file => nil,
      :xenode_class => nil,
      :redis_host => '127.0.0.1',
      :redis_port => 6379,
      :redis_db => 0
    }
    
    # ensure option keys are symbolized and lowercase
    symbolized_opts = {}
    opts.each_pair do |key, val|
      symbolized_opts[key.to_s.downcase.to_sym] = val
    end

    @opts.merge!(symbolized_opts)
    @xenode_class = @opts[:xenode_class]
    @xenode_id = @opts[:xenode_id]
    @redis_conn = {
      :host   => @opts[:redis_host],
      :port   => @opts[:redis_port],
      :db     => @opts[:redis_db],
    }
        
    # check that all required options were provided
    required_opts
    
  end

  def required_opts
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    if @opts && @opts.keys
      @required_opts.each do |required_key|
        if @opts.keys.to_s.downcase.include?(required_key.to_s.downcase)
          # raise an error if the value of the required option is nil
          raise ArgumentError, "#{mctx} - #{required_key} is a required option." unless @opts[required_key.to_s.downcase.to_sym]
        end
      end
    else
      raise ArgumentError, "#{mctx} - the following options: #{@required_opts} are required." if @required_opts
    end
  end

  # setup the log (must be done after options are processed)
  def set_log
    @log_path = File.join(@dir_set[:log_dir],"xn_#{@xenode_id}.log")
    @log = Logger.new @log_path
    @log.level = Logger::DEBUG
  end

  def do_debug(debug_message, force = false)
    if @debug || force
      @log.debug(debug_message)
    end
  end

  def catch_error(error_message, reraise = false)
    if error_message
      @log ? @log.error(error_message) : warn(error_message)
      raise(Exception, error_message) if reraise
    end
  end

  # set directory paths
  def set_dirs
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    # this file is in the lib dir so capture the full path
    sys_lib = File.expand_path(File.dirname(__FILE__))

    # the root dir is one dir up from here
    root_dir = File.expand_path(File.join(sys_lib,'..'))

    xenode_pid = "#{@xenode_id}_pid"

    # all other directories are off of the run_dir
    log_dir        = File.join(root_dir,'log')        # the log directory
    xenode_lib_dir = File.join(root_dir,'xenode_lib') # your xenode library
    xeno_flow_dir  = File.join(root_dir,'xenoflows')  # xenoflows directory
    run_dir        = File.join(root_dir,"run")        # run directory for running xenode instances
    tmp_dir        = File.join(run_dir,"tmp")         # tmp directory for all xenode instances
    xenodes        = File.join(run_dir,'xenodes')     # xenodes instance directory
    disk_dir       = File.join(xenodes, @xenode_id, 'files')  # disk dir for xenode to read and write scratch files
    log_dir        = File.join(xenodes, @xenode_id, 'log') # the log directory
    pid_dir        = File.join(run_dir,'pids')        # pids directory
    @pid_path      = File.join(pid_dir, xenode_pid)   # full path to pid file
    config_dir     = File.join(xenodes, @xenode_id, 'config')   # xenode's config directory


    # paths hash make it easy to automate directory methods
    @dir_set = {
      :sys_lib        => sys_lib,
      :root_dir       => root_dir,
      :log_dir        => log_dir,
      :disk_dir       => disk_dir,
      :run_dir        => run_dir,
      :tmp_dir        => tmp_dir,
      :xenodes        => xenodes,
      :xenode_lib_dir => xenode_lib_dir,
      :pid_dir        => pid_dir,
      :config_dir     => config_dir
    }
    
    # make sure the directories exist
    ensure_dirs

  end

  def xenode_running?
    ret_val = false
    if File.exist?(@pid_path)
      pid = File.read(@pid_path) if File.exist?(@pid_path)
      begin
        if pid
          Process.kill(0, pid.to_i)
          ret_val = true
        end
      rescue Errno::ESRCH
      end
    end
    ret_val
  end

  def ensure_dirs
    # ensure directories exist
    @dir_set.each do |key, dir|
      unless Dir.exist?(dir)
        FileUtils.mkdir_p(dir)
      end
    end
  end

  def lock_write(fname, data, purge = false)
    if purge && File.exist?(fname)
      File.unlink(fname)
    end
    File.open(fname, "a") do |f|
      f.flock(File::LOCK_EX)
      f.write(data)
      f.flush
      f.flock(File::LOCK_UN)
      f.close
    end
  end

  def symbolize_hash_keys(hash)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    begin
      ret_val = {}
      if hash
        hash.each_pair do |k,v|
          v = symbolize_hash_keys(v) if v.is_a?(Hash)
          ret_val[k.to_sym] = v
        end
      end
      ret_val
    rescue Exception => e
      @log.error("#{mctx} - #{e.inspect} #{e.backtrace}")
    end
  end

  def stringify_hash_keys(hash)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    begin
      ret_val = {}
      hash.each_pair do |k,v|
        v = stringify_hash_keys(v) if v.is_a?(Hash)
        ret_val[k.to_s] = v
      end
      ret_val
    rescue Exception => e
      @log.error("#{mctx} - #{e.inspect} #{e.backtrace}")
    end
  end
  
end

# only run this is this file is run directly 
# and not instanced in another program
if $0 == __FILE__
  InstanceXenode.new(ARGV).spawn_xenode()
  exit
end
