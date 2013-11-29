# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require 'pathname'
require 'yaml'
require 'redis'
require 'fileutils'

module Xeno
  
  class RunXenoFlow < ::Escort::ActionCommand::Base
    def execute
      begin
        if command_name.to_s.downcase == 'xenoflow'
          if command_options[:xenoflow_file_given] 
            
            xenoflow_id   = command_options[:xenoflow_id]
            xenoflow_file = command_options[:xenoflow_file]
            xenoflows = Xeno::load_xenoflows_from_file(xenoflow_file)
            # puts "* xenoflows: #{xenoflows.inspect}"
            
            if xenoflow_id
              RunXenoFlow.run_xenoflow(xenoflows[xenoflow_id])
            else
              xenoflows.each_value do |xflow|
                RunXenoFlow.run_xenoflow(xflow)
              end
            end
          else
            RunXenoFlow.run_xenoflows()
            # puts "Error: You must supply a xenoflow file name."
          end
          #END if
        end
        #END if
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
    
    def self.run_xenoflows()
      lib_dir = Xeno::lib_dir
      xenoflows_dir_path = File.expand_path(File.join(lib_dir,'..','xenoflows'))
      
      xenodes = {} # used to check if there's duplicate Xenode id
      xenoflows = [] # used to run xenoflow (could be duplicate id for XenoFlow, but we don't care)
      cancel = false # check if no duplicate Xenode is found
      
      Dir.entries(xenoflows_dir_path).each do |f|
        # ignore current and parent and none-YAML
        next if f == "." || f == ".." || f == ".DS_Store"
        next if File.extname(f) != ".yml"
        
        xenoflow_file_name = f
        xenoflow_file_xenoflows = Xeno::load_xenoflows_from_file(xenoflow_file_name)
        
        # getting ALL the xenodes to check if there's duplicate ID
        xenoflow_file_xenoflows.each_pair do |xf_id, xf|
          xenoflows << xf
          xf['xenodes'].each_pair  do |xn_id, xn|
            # if there's repeating id
            if xenodes.has_key?("#{xn_id}")
              
              puts "* CLI cancel the run action because it find duplicate Xenodes instance id:\n"
              puts "  - Xenode: #{xn_id} in XenoFlow: #{xenodes["#{xn_id}"]["xenoflow_id"]} of file: #{xenodes["#{xn_id}"]["xenoflow_file_name"]}"
              puts "  - Xenode: #{xn_id} in XenoFlow: #{xf_id} of file: #{xenoflow_file_name}"
              puts "  Please provide them a unique instance id and try run again."
              cancel = true
              break
              
            # NO repeating id, just save it into the hash
            else
              xenodes["#{xn_id}"] = xn
              xenodes["#{xn_id}"]["xenoflow_id"] = xf_id
              xenodes["#{xn_id}"]["xenoflow_file_name"] = xenoflow_file_name
            end
            #END if
          end
          #END each_pair
        end
        #END each_pair
      end
      #END each
      
      # puts "wegfiueguifw:\n#{xenodes.keys.join("\n")}"
      
      unless cancel
        xenoflows.each do |xf|
          RunXenoFlow.run_xenoflow(xf)
        end
        
        # check pid again
        success = 0
        sleep(0.5)
        xenodes.each_pair do |xn_id, xn|
          xenode_pid = Xeno::get_xenode_pid(xn_id)
          if xenode_pid
            success += 1
          end
        end
        puts "* CLI has successfully running #{success} Xenodes out of #{xenodes.size}; Found #{xenodes.size - success} having errors."
        
      end
      #END unless
      
      # self.run_xenoflow(xenoflow)
    end
    
    def self.run_xenoflow(xenoflow)
      lib_dir = Xeno::lib_dir
      
      if xenoflow
        puts "* CLI attempt to run XenoFlow: #{xenoflow['id']}"
        if xenoflow['xenodes']
          xenoflow['xenodes'].each_value do |xenode|
            
            # get options
            xenode_id   = xenode['id']
            xenode_file = xenode['path']
            xenode_class = xenode['klass']
            
            # **** pass required field to the record
            xenode['xenoflow_id'] = xenoflow['id']
            # xenode['xenoflow_file'] = xenoflow['file']

            # get klass nmae if not provided
            unless xenode['klass']
              xenode_class = Xeno::get_xenode_class(xenode_file)
              xenode['klass'] = xenode_class
            end
            
            xeno_conf = Xeno::get_xeno_conf()
            
            if xeno_conf[:new_log_everytime]
              ClearLog.clear_xenode_log(xenode_id)
            end
            
            if xenode_class
              xenode_pid = Xeno::get_xenode_pid(xenode_id)
              # don't start it if it is already running
              unless xenode_pid
                # to make sure config gets updated properly
                Xeno::ClearRunConfig.clear_xenode_run_config(xenode_id)
                Xeno::write_xenode_config(xenode)
                
                puts "* CLI attempt to run Xenode: #{xenode_id} (#{xenode_class})\n"
                
                # run the xenode
                exec_cmd = "ruby -I #{lib_dir} -- #{lib_dir}/instance_xenode.rb "
                exec_cmd << "-f #{xenode_file} -k #{xenode_class} "
                exec_cmd << "-i #{xenode_id.to_s} "
                # exec_cmd << "-d " # if @debug
                exec_cmd << "--redis-host #{xeno_conf[:redis_host]} " if xeno_conf[:redis_host]
                exec_cmd << "--redis-port #{xeno_conf[:redis_port]} " if xeno_conf[:redis_port]
                exec_cmd << "--redis-db #{xeno_conf[:redis_db]} " if xeno_conf[:redis_db]
                
                # # no longer use fork
                # pid = fork do
                #   exec(exec_cmd)
                # end
                # Process.detach(pid)
                
                # putting rescue here does not seems work
                system("#{exec_cmd} &")
                
                # check pid again
                sleep(0.5)
                xenode_pid = Xeno::get_xenode_pid(xenode_id)
                if xenode_pid
                  puts "* CLI has confirmed Xenode #{xenode_id} (#{xenode_class}) is running in pid: #{xenode_pid}\n"
                else
                  puts "* CLI not able to find the pid for #{xenode_id} (#{xenode_class})\n"
                end
                
              else
                puts "* CLI found Xenode #{xenode_id} (#{xenode_class}) is already running in pid: #{xenode_pid}\n"  
              end
            else
              puts "* CLI cannot find the class in Xenode file: #{xenode_file}\n\n"
            end
            #END if
          end
          #END each_value
        else
          puts "* CLI found the value of 'xenodes' are empty for XenoFlow: #{xenoflow['id']}"
        end
        #END if
      end
      #END if
    end
    #END run_xenoflow
  end
  #END class
  
  class StopXenoFlow < ::Escort::ActionCommand::Base
    def execute
      lib_dir = Xeno::lib_dir
      begin
        if command_name.to_s.downcase == 'xenoflow'
          if command_options[:xenoflow_file_given] 

            xenoflow_id   = command_options[:xenoflow_id]
            xenoflow_file = command_options[:xenoflow_file]
            xenoflows = Xeno::load_xenoflows_from_file(xenoflow_file)
            # puts "* xenoflows: #{xenoflows.inspect}"
            
            if xenoflow_id
              StopXenoFlow.stop_xenoflow(xenoflows[xenoflow_id])
            else
              xenoflows.each_value do |xflow|
                StopXenoFlow.stop_xenoflow(xflow)
              end
            end
          else
            StopXenoFlow.stop_xenoflows()
            # puts "Error: You must supply a xenoflow file name."
          end
          #END if
        end
        #END if
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
      
    end
    
    def self.stop_xenoflows()
      lib_dir = Xeno::lib_dir
      xenoflows_dir_path = File.expand_path(File.join(lib_dir,'..','xenoflows'))

      Dir.entries(xenoflows_dir_path).each do |f|
        # ignore current and parent and none-YAML
        next if f == "." || f == ".." || f == ".DS_Store"
        next if File.extname(f) != ".yml"
        
        xenoflow_file_name = f
        xenoflow_file_xenoflows = Xeno::load_xenoflows_from_file(xenoflow_file_name)
        
        # getting ALL the xenodes to check if there's duplicate ID
        xenoflow_file_xenoflows.each_pair do |xf_id, xf|
          StopXenoFlow.stop_xenoflow(xf)          
        end
        #END each_pair
      end
      #END each
    end
    #END stop_xenoflows
    
    def self.stop_xenoflow(xenoflow)
      lib_dir = Xeno::lib_dir
      
      if xenoflow
        puts "* CLI attempt to stop xenoflow: #{xenoflow['id']}"
        if xenoflow['xenodes']
          
          xenoflow['xenodes'].each_value do |xenode|
          
            # get options
            xenode_id   = xenode['id']
            xenode_file = xenode['path']
            xenode_class = xenode['klass']
          
            # get klass nmae if not provided
            unless xenode['klass']
              xenode_class = Xeno::get_xenode_class(xenode_file)
              xenode['klass'] = xenode_class
            end
          
            unless xenode_class
              puts "* CLI cannot find the class for xenode #{xenode_id}, but will process to stop #{xenode_id} anyways"
            end
          
            xenode_pid = Xeno::get_xenode_pid(xenode_id)
            # don't start it if it is already running
            if xenode_pid
              puts "* CLI attempt to stop xenode: #{xenode_id} (#{xenode_class})\n"

              begin
                Process.kill("TERM", xenode_pid.to_i)
                puts "* CLI has stopped xenode #{xenode_id} (#{xenode_class}) in pid: #{xenode_pid}"
              rescue Errno::ESRCH
              end
            else
              puts "* CLI found xenode #{xenode_id} (#{xenode_class}) is already stopped."
            end
            #END if
          end
          #END each_value
        end
        #END if
      end
      #END if
    end
    #END stop_xenoflow
  end
  #END class
  
  class WriteMessage < ::Escort::ActionCommand::Base
    def execute
      lib_dir = Xeno::lib_dir

      require File.join(lib_dir,"xeno_message")

      begin
        if command_name.to_s.downcase == 'message'

          if command_options[:xenode_id_given]

            data = context = nil

            xenode_id  = command_options[:xenode_id]

            xmsg         = XenoCore::Message.new
            xmsg.from_id = "console"
            xmsg.to_id   = xenode_id

            if command_options[:msg_file_given]
              fp = command_options[:msg_file]
              basename = File.basename(fp)
              if basename.downcase.include?(".csv")
                if command_options[:context_given]
                  context = command_options[:context]
                  xmsg.context = Xeno::text_to_hash(context) if context
                end
                msg = File.read(fp)
                xmsg.data = msg
              elsif basename.downcase.include?(".yml")
                msg = YAML.load(File.read(fp)) if File.exist?(fp)
                xmsg.load(msg) if msg.is_a?(Hash)
              end
            else
              data       = command_options[:data]       if command_options[:data_given]
              context    = command_options[:context]    if command_options[:context_given]
              puts "context: #{context.inspect}" if context
              data_hash = Xeno::text_to_hash(data)
              xmsg.data = data_hash ? data_hash : data

              context_hash = Xeno::text_to_hash(context)
              xmsg.context = context_hash ? context_hash : context
            end
            
            # get Redis instance
            xeno_conf = Xeno::get_xeno_conf()
            redis_port = xeno_conf[:redis_port]
            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new

            msg_key = "#{xenode_id}:msg"
            pub_key = "#{xenode_id}:msgpub"

            rdb.lpush(msg_key, xmsg.pack)
            rdb.publish(pub_key, msg_key)
            
            puts
            puts "* CLI has written a message to Xenode: #{xenode_id}"
            puts
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end

    end

  end
  #END class
  
  class ListMessages < ::Escort::ActionCommand::Base
    def execute
      lib_dir = Xeno::lib_dir

      require File.join(lib_dir,"xeno_message")

      begin
        if command_name.to_s.downcase == 'messages'
          if command_options[:xenode_id_given]
            
            # get Redis instance
            xeno_conf = Xeno::get_xeno_conf()
            redis_port = xeno_conf[:redis_port]
            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new
            
            xenode_id  = command_options[:xenode_id]
            msg_key = "#{xenode_id}:msg"
            msgs = rdb.lrange(msg_key, 0, -1)
            if msgs
              puts
              puts "* CLI listing queued messages for Xenode: #{xenode_id}..."
              puts
              msgs.each do |m|
                m = XenoCore::Message.new.load(m)
                puts m.to_hash
              end
              puts
              puts "* CLI has found #{msgs.size} queued messages for Xenode: #{xenode_id}"
              puts "  Redis: #{rdb.inspect}"
              puts
            end
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  end
  #END class
  
  class ClearMessages < ::Escort::ActionCommand::Base
    def execute
      begin
        if command_name.to_s.downcase == 'messages'
          if command_options[:xenode_id_given]
            
            # get Redis instance
            xeno_conf = Xeno::get_xeno_conf()
            redis_port = xeno_conf[:redis_port]
            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new
            
            xenode_id  = command_options[:xenode_id]
            msg_key = "#{xenode_id}:msg"
            msgs = rdb.lrange(msg_key, 0, -1)
            rdb.del(msg_key)
            puts
            puts "* CLI has cleared #{msgs.size} queued messages for Xenode: #{xenode_id}"
            puts "  Redis: #{rdb.inspect}"
            puts
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
    #END execute
  end
  #END class
  
  class ClearRunConfig < ::Escort::ActionCommand::Base
    def execute
      begin
        lib_dir = Xeno::lib_dir
        
        if command_options[:xenode_id_given]
          xenode_id = command_options[:xenode_id]
          ClearRunConfig.clear_xenode_run_config(xenode_id)
        else
          ClearRunConfig.clear_xenodes_run_config()
        end
        
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
    
    def self.clear_xenodes_run_config
      lib_dir = Xeno::lib_dir
      xenodes_dir_path = File.expand_path(File.join(lib_dir,'..','run','xenodes'))
      Dir.entries(xenodes_dir_path).each do |f|
        # ignore current and parent
        next if f == "." || f == ".." || f == ".DS_Store"
        xenode_id = f
        self.clear_xenode_run_config(xenode_id)
      end
    end
    
    def self.clear_xenode_run_config(xenode_id)
      lib_dir = Xeno::lib_dir
      config_path = File.expand_path(File.join(lib_dir,'..','run','xenodes',"#{xenode_id}",'config',"config.yml"))

      if File.exist?(config_path)
        File.unlink(config_path) 
        # puts "* CLI has cleared the run (cached) config for xenode: #{xenode_id}"
      else
        # puts "* CLI unable to find the run (cached) config for xenode: #{xenode_id}"
      end
    end
  end
  
  class ClearLog < ::Escort::ActionCommand::Base
    def execute
      begin
        lib_dir = Xeno::lib_dir
        if command_name.to_s.downcase == 'log'
          if command_options[:xenode_id_given]
            xenode_id = command_options[:xenode_id]
            ClearLog.clear_xenode_log(xenode_id)
          else
            ClearLog.clear_xenodes_log()
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  
    def self.clear_xenodes_log
      lib_dir = Xeno::lib_dir
      xenodes_dir_path = File.expand_path(File.join(lib_dir,'..','run','xenodes'))
      Dir.entries(xenodes_dir_path).each do |f|
        # ignore current and parent
        next if f == "." || f == ".." || f == ".DS_Store"
        xenode_id = f
        self.clear_xenode_log(xenode_id)
      end
    end
    
    def self.clear_xenode_log(xenode_id)
      lib_dir = Xeno::lib_dir
      log_path = File.expand_path(File.join(lib_dir,'..','run','xenodes',"#{xenode_id}",'log',"xn_#{xenode_id}.log"))

      if File.exist?(log_path)
        File.unlink(log_path) 
        puts "* CLI has cleared the log for Xenode: #{xenode_id}"
      else
        puts "* CLI found log for Xenode: #{xenode_id} is already deleted"
      end
    end
    
  end
  #END class
  
  class ClearRuntime < ::Escort::ActionCommand::Base
    def execute
      begin
        lib_dir = Xeno::lib_dir
        runtime_dir_path = File.expand_path(File.join(lib_dir,'..','run'))
        if Dir.exists?(runtime_dir_path)
          Dir.entries(runtime_dir_path).each do |f|
            # ignore current and parent and pids
            next if f == "." || f == ".." || f == ".DS_Store"
            next if f == "pids"
            dir_path = File.expand_path(File.join(runtime_dir_path,"#{f}"))
            FileUtils.rm_rf(dir_path)
          end
          puts "* CLI has cleared everything in /run"
        else
          puts "* CLI found /run is already removed."
        end
                
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  end
  #END class
  
  
  def self.lib_dir
    Pathname.new(__FILE__).realpath.dirname
  end
  
  def self.get_xeno_conf
    lib_dir = Xeno::lib_dir
    
    # get xeno_conf
    # may move this to a helper later because we may need this in other commands
    xeno_conf = {
      "redis_host" => '127.0.0.1',
      "redis_port" => 6379,
      "redis_db" => 0,
      "new_log_everytime" => false
    }
    xeno_conf_file = File.join(lib_dir, '..', 'bin', 'xeno.yml')
    if File.exist?(xeno_conf_file)
      hash = YAML.load(File.read(xeno_conf_file))
      if hash
        xeno_conf.merge!(hash)
        # puts "* CLI checking xeno_conf: #{xeno_conf.inspect}"
      end
    end
    #END if
    xeno_conf
  end
  
  def self.get_xenode_pid(xenode_id)
    ret_val = nil
    pid_path = File.expand_path(File.join(lib_dir,'..','run','pids',"#{xenode_id}_pid"))
    # puts "* CLI checking the pid_path: #{pid_path}"
    if File.exist?(pid_path)
      pid = nil
      pid = File.read(pid_path) if File.exist?(pid_path)
      # puts "* CLI found pid for #{xenode_id}: #{pid.inspect}"
      if pid
        begin
          Process.kill(0, pid.to_i)
          # puts "* CLI found #{xenode_id} is running with pid: #{pid}"
          ret_val = pid
        rescue Errno::ESRCH
        end
      end
    end
    ret_val
  end
  
  def self.get_xenode_class(xenode_file)
    ret_val = nil
    
    fp = File.expand_path(File.join(Xeno::lib_dir, '..', 'xenode_lib', xenode_file))
    if Dir.exist?(fp)
      files = Dir.glob(File.join(fp, 'lib', '*.rb'))
      if files.length == 1
        File.read(files[0]).each_line do |line|
          # check if meta is in flie to find class
          line.chomp!.strip!
          if line[0..10] == '#xeno-meta:'
            ret_val = line.split(':')[1]
            puts "ret_val: #{ret_val.inspect}"
            break
          elsif line[0..4] == 'class'
            ret_val = line.split('class')[1].strip
            break
          end
        end
      end
    end
    
    ret_val
  end
  
  # loading xenoflows from file to hash. 
  # ** NOT symbolized because we use string to get the valuse in other methods
  # Also include some extra keys for easy retrieval (like id and file_name) 
  def self.load_xenoflows_from_file(file_name, plain=false)
    ret_val = {}
    lib_dir = Xeno::lib_dir
    
    file_ext = File.extname(file_name)
    file_name = "#{file_name}.yml" unless file_ext && file_ext.downcase == '.yml'
    file_dir = File.expand_path(File.join(lib_dir,'..','xenoflows'))
    file_path = File.join(file_dir, file_name)
    if File.exist?(file_path)
      hash = YAML.load(File.read(file_path))
      if hash
        unless plain
          # adding extra properties for easy retrieval if NOT plain
          hash.each_pair do |k,v|
            v['id'] = k
            v['file_name'] = file_name
            begin
              v['xenodes'].each_pair do |xk, xv|
                xv['id'] = xk
                # also add xenoflow info into xenode
                xv['xenoflow_file_name'] = file_name
                xv['xenoflow_id'] = k
              end
            rescue Exception => e
              if e.message == "undefined method `each_pair' for nil:NilClass"
                puts "* CLI cancel the action, key 'xnoedes' is missing in XenoFlow: #{k} of file: #{file_name}"                
                puts
                break
              else
                # if there's error, it always prints out the error even without puts
                # puts "#{e}"
              end
              #END if
            end
            #END begin
          end
          #END each_pair
        end
        #END unless
        ret_val = hash
      else
        puts "* CLI cannot find any XenoFlow in file: #{file_path}"
      end
    else
      puts "* CLI cannot find XenoFlow file: #{file_path}"
    end
    #END if

    ret_val
  end
  
  # writing xenoflows to a file
  def self.write_xenoflows_to_file(file_name, hash)
    lib_dir = Xeno::lib_dir
    
    file_ext = File.extname(file_name)
    file_name = "#{file_name}.yml" unless file_ext && file_ext.downcase == '.yml'
    file_dir = File.expand_path(File.join(lib_dir,'..','xenoflows'))
    file_path = File.join(file_dir, file_name)
    
    # actual data
    data_out = YAML.dump(hash)

    File.open(file_path, "w") do |f|
      f.write(data_out)
    end
  end

  # I need to grab the xenode config from xenoflow file and merge it with the default
  # if will also return the merged config
  def self.write_xenode_config(xenode)
    if xenode
      
      # you may ask why not just pass the xenoflow hash directly? 
      # because the hash does NOT equals to the content in the xenoflow file (there's extra properties like 'id')
      # it will be easier when we overwrite the xenoflow file with the default xenode config
      xenoflow_file_name = xenode['xenoflow_file_name']
      xenoflow_id = xenode['xenoflow_id']
      
      xenode_id   = xenode['id']
      xenode_file = xenode['path']
      children = xenode['children']
      
      # get default config
      def_cfg = {}
      def_cfg_path = File.expand_path(File.join(Xeno::lib_dir, '..', 'xenode_lib', xenode_file, 'config', 'config.yml'))
      if File.exist?(def_cfg_path)
        yml = File.read(def_cfg_path)
        def_cfg = YAML.load(yml) unless yml.to_s.empty?
      end
      def_cfg['loop_delay'] ||= 5.0 
      def_cfg['enabled'] = true unless def_cfg['enabled'] == false
      def_cfg['debug'] = false unless def_cfg['debug'] == true

      # get intance config
      int_cfg = {}
      xenoflow_globals = {}
      xenode_children = {}
      xenoflows = Xeno::load_xenoflows_from_file(xenoflow_file_name, true)
      unless xenoflows.empty?
        xenoflow_globals = xenoflows[xenoflow_id]['globals']
        xenode_children = xenoflows[xenoflow_id]['xenodes'][xenode_id]['children'] rescue {}
        xenode_children ||= {}
        int_cfg = xenoflows[xenoflow_id]['xenodes'][xenode_id]['config'] rescue {}
        int_cfg ||= {}
      end
      
      # write run config
      run_cfg = {}
      run_cfg = def_cfg.merge(int_cfg)
      run_cfg_path = File.expand_path(File.join(Xeno::lib_dir, '..', 'run', 'xenodes', xenode_id, 'config', 'config.yml'))

      # update xenoflow file before write run config
      unless xenoflows.empty?
        xenoflows[xenoflow_id]['xenodes'][xenode_id]['config'] = run_cfg
        Xeno::write_xenoflows_to_file(xenoflow_file_name, xenoflows)
      end
      
      # NOTE that there are structure different btw run_cfg and def_cfg
      # what you defined in def_cfg, it would be equivalent to the value inside the config KEY
      run_cfg = {
        'config' => run_cfg,
        'globals' => xenoflow_globals,
        'children' => xenode_children
      }

      # some info to be written on the head
      header_comment = "# #{xenode_file} config written @ #{Time.now}\n"
      # actual data
      data_out = YAML.dump(run_cfg)
      
      # make sure the path exists
      FileUtils.mkdir_p(File.dirname(run_cfg_path))
      
      File.open(run_cfg_path, "w") do |f|
        f.write(header_comment)
        f.write(data_out)
      end
      
      # puts "* CLI has created run config file for #{xenode_id} in run directory"
    end
    #END if
  end
  #END write_xenode_config
  

  #-------------------------------------------------------------------------------------
  #  helpers
  #-------------------------------------------------------------------------------------
  
  def self.text_to_hash(hash_text)
    ret_val = nil
    if hash_text
      ret_val = hash_text
      if hash_text && hash_text.include?(':')
        ret_val = {}
        if hash_text.include?(',')
          hash_text.split(',').each do |pair|
            key, val = pair.split(':')
            ret_val[key.to_sym] = val
          end
        else
          key, val = hash_text.split(':')
          ret_val[key.to_sym] = val
        end
      end
    end
    ret_val
  end
  # END text_to_hash
  
end
