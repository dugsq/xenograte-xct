# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require 'logger'
require 'yaml'
require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'fileutils'
require 'em-synchrony'
require 'em-hiredis'

# this clss is called to fork a new instance of a xenode.
class InstanceXenode

  TIMEFMT = "%Y-%m-%d %H:%M:%S.%L"

  def initialize(args)
    # method context for debugging
    mctx = "#{self.class}.#{__method__}"

    begin
      # these are the required_options
      @required_opts = %w"xenode_id xenode_file xenode_klass"

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

      xenode_basename = File.basename(@opts[:xenode_file],".rb")
      require File.join(@dir_set[:xenode_lib_dir], xenode_basename, 'lib', xenode_basename )

      # get this xenode's library config dir for defaults
      @xenode_default_config = File.expand_path(File.join(@dir_set[:xenode_lib_dir], xenode_basename, 'config','config.yml'))

      # setup the log
      set_log()

      do_debug("#{mctx} - xenode_class: #{@xenode_class.inspect}")

      # see if redis server is running
      rpid = `ps -e -o pid -o comm | grep [r]edis-server`
      if rpid.to_s.empty?
        emsg = "#{mctx} - Xenode stopped: Redis server is not running."
        warn emsg
        catch_error(emsg)
        exit!
      end

      # run the xenode
      do_debug("#{mctx} - spawning xenode: #{@xenode_id} with options: #{opts.inspect}")
      spawn_xenode()

    rescue Exception => e
      emsg = "#{e.inspect} #{e.backtrace}"
      if @log
        @log.error(emsg)
      else
        warn emsg
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
    $stderr.reopen(@log_file, "a")

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

    # redis connection - override it here unless you want the defaults
    redis_conn = nil

    @xenode_obj = nil

    # fire up the EM loop
    EM.synchrony do

      # pass-in usefull options
      opts = {}
      opts[:log_path]  = @log_path
      opts[:log] = @log
      opts[:xenode_id] = @xenode_id
      opts[:xenode_config] = load_xenode_config
      opts[:shared_dir] = @dir_set[:shared_dir]

      @loop_delay = opts[:xenode_config][:loop_delay] if opts[:xenode_config] && opts[:xenode_config][:loop_delay]
      @loop_delay ||= 0.5

      @dir_set = nil

      # create the xenode
      @xenode_obj = Object.const_get(@xenode_class).new(opts)

      # create the xenode_queue object
      # opts.merge! {:log => @log}
      opts[:log] = @log
      @xenode_queue = XenoCore::XenoQueue.new(opts)

      # add the write_to_children method to the xenode class with callback
      @xenode_obj.on_message do |msg|
        do_debug("#{mctx} - calling #{@xenode_id}.write_to_children msg: #{msg.inspect}", true)
        @xenode_queue.write_to_children(msg)
      end

      # add write to xenode method to the xenode class with callback
      @xenode_obj.on_write_to_xenode do |to_xenode_id, msg|
        do_debug("#{mctx} - calling #{@xenode_id}.write_to_xenode to_xenode_id: #{to_xenode_id} msg: #{msg.inspect}")
        @xenode_queue.write_to_xenode(to_xenode_id, msg)
      end

      # call Xenode's process_message() with xenode_queue
      @xenode_queue.on_message do |msg|
        do_debug("#{mctx} - calling process_message msg: #{msg.inspect}", true)
        # send orig msg to xenode's process_message
        @xenode_obj.process_message(msg)
      end

      # call xenode's startup() method
      do_debug("#{mctx} - calling startup on xenode.", true)
      @xenode_obj.startup({:log => @log})

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

    end # end of EM.synchrony do

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

    end

    opts.parse!(args)

    options

  end

  def load_xenode_config
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    # set the default return value
    ret_val = {}

    # init the default_data
    default_data = nil

    do_debug("#{mctx} - @xenode_default_config: #{@xenode_default_config.inspect}", true)

    # see if the default config file for the xenode type exists
    if File.exist?(@xenode_default_config)
      # read the raw yaml
      yml = File.read(@xenode_default_config)
      # turn raw yml into ruby hash
      default_data = YAML.load(yml) if yml
      default_data = symbolize_hash_keys(default_data)
    end

    # override defaults with instance's config if it exists
    fp = File.join(@dir_set[:xenodes],@xenode_id,'config.yml')
    do_debug("#{mctx} - instance config path: #{fp.inspect}", true)
    # see if the file exists
    if File.exist?(fp)
      # read the raw yaml
      yml = File.read(fp)
      # turn raw yml into ruby hash
      yml_data = YAML.load(yml) if yml
      cfg_data = symbolize_hash_keys(yml_data)

      # set ret_val to cfg_data from instance's config
      ret_val = cfg_data if cfg_data
      # merge the hashes overwriting the defaults
      ret_val = default_data.merge(cfg_data) if default_data
    else
      # set ret_val to default_data since there is no instance config file
      ret_val = default_data if default_data
    end

    ret_val
  end

  def process_options(opts)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    @opts = {}

    # ensure option keys are symbolized and lowercase
    opts.each_pair do |key, val|
      if key == :xenode_class
        @xenode_class = val
      end
      @opts[key.to_s.downcase.to_sym] = val
    end

    # pull out the xenode id for conveinience
    @xenode_id = opts[:xenode_id]

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
    @log_file = File.join(@dir_set[:log_dir],"#{@xenode_id}.log")
    @log = Logger.new @log_file
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
    shared_dir     = File.join(run_dir,'shared_dir')  # shared dir used for xenodes to read and write scratch files
    xenodes        = File.join(run_dir,'xenodes')     # xenodes instance directory
    pid_dir        = File.join(run_dir,'pids')        # pids directory
    @pid_path      = File.join(pid_dir, xenode_pid)   # full path to pid file


    # paths hash make it easy to automate directory methods
    @dir_set = {
      sys_lib: sys_lib,
      root_dir: root_dir,
      log_dir: log_dir,
      shared_dir: shared_dir,
      run_dir: run_dir,
      xenodes: xenodes,
      xenode_lib_dir: xenode_lib_dir,
      pid_dir: pid_dir
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

end

InstanceXenode.new(ARGV) if $0 == __FILE__
exit
