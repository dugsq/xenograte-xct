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
              run_xenoflow(xenoflows[xenoflow_id])
            else
              xenoflows.each_value do |xflow|
                run_xenoflow(xflow)
              end
            end
          else
            puts "Error: You must supply a xenoflow file name."
          end
          #END if
        end
        #END if
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
    
    def run_xenoflow(xenoflow)
      lib_dir = Xeno::lib_dir
      
      if xenoflow
        puts "* CLI attempt to run xenoflow: #{xenoflow['id']}"
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
            
            # get xeno_conf
            # may move this to a helper later because we may need this in other commands
            xeno_conf = {
              :redis_host => '127.0.0.1',
              :redis_port => 6379,
              :redis_db => 0
            }
            xeno_conf_file = File.join(lib_dir, '..', 'bin', 'xeno.yml')
            if File.exist?(xeno_conf_file)
              hash = YAML.load(File.read(xeno_conf_file))
              if hash
                symbolized_hash = Xeno::symbolize_hash_keys(hash)
                xeno_conf.merge!(symbolized_hash)
                # puts "* CLI checking xeno_conf: #{xeno_conf.inspect}"
              end
            end
            #END if
            # also need to add globals into xenode's config
            #END get xeno_conf
            
            if xenode_class
              Xeno::write_xenode_config(xenode)
              
              xenode_pid = Xeno::get_xenode_pid(xenode_id)
              # don't start it if it is already running
              unless xenode_pid
                puts "* CLI attempt to run xenode: #{xenode_id} (#{xenode_class})\n"
              
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
              
                system("#{exec_cmd} &")
                
                # check pid again
                sleep(0.5)
                xenode_pid = Xeno::get_xenode_pid(xenode_id)
                if xenode_pid
                  puts "* CLI has confirmed xenode #{xenode_id} (#{xenode_class}) is running in pid: #{xenode_pid}\n"
                else
                  puts "* CLI not able to find the pid for #{xenode_id} (#{xenode_class})\n"
                end
                
              else
                puts "* CLI found xenode #{xenode_id} (#{xenode_class}) is already running in pid: #{xenode_pid}\n"  
              end
            else
              puts "* CLI cannot find the class in xenode file: #{xenode_file}\n\n"
            end
            #END if
          end
          #END each_value
        else
          puts "xenodes are empty for xenoflow #{xenoflow['id']}"
        end
        #END if
      end
      #END if
    end
    #END run_xenoflow
  end

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
              stop_xenoflow(xenoflows[xenoflow_id])
            else
              xenoflows.each_value do |xflow|
                stop_xenoflow(xflow)
              end
            end
          else
            puts "Error: You must supply a xenoflow file name."
          end
          #END if
        end
        #END if
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
      
    end
    
    def stop_xenoflow(xenoflow)
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
  
  class ClearMessages < ::Escort::ActionCommand::Base
    def execute
      begin
        if command_name.to_s.downcase == 'message'
          if command_options[:xenode_id_given]
            redis_port = nil
            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new
            xenode_id  = command_options[:xenode_id]
            msg_key = "#{xenode_id}:msg"
            rdb.del(msg_key)
            puts "messages for xenode: #{xenode_id} cleared."
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  end

  class ListMessages < ::Escort::ActionCommand::Base
    def execute
      lib_dir = Xeno::lib_dir

      require File.join(lib_dir,"xeno_message")

      begin
        if command_name.to_s.downcase == 'message'
          if command_options[:xenode_id_given]
            redis_port = nil
            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new
            xenode_id  = command_options[:xenode_id]
            msg_key = "#{xenode_id}:msg"
            msgs = rdb.lrange(msg_key, 0, -1)
            if msgs
              puts
              puts "Messages for Xenode: #{xenode_id}"
              puts "-------------------------------------------"
              msgs.each do |m|
                m = XenoCore::Message.new.load(m)
                puts m.to_hash
              end
              puts
            end
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  end
  
  class WriteMessage < ::Escort::ActionCommand::Base
    def execute
      lib_dir = Xeno::lib_dir

      require File.join(lib_dir,"xeno_message")

      begin
        if command_name.to_s.downcase == 'message'

          if command_options[:xenode_id_given]

            data = context = redis_port = nil

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

            redis_port = command_options[:redis_port] if command_options[:redis_port]

            rdb = redis_port ? Redis.new(:port => redis_port) : Redis.new

            msg_key = "#{xenode_id}:msg"
            pub_key = "#{xenode_id}:msgpub"

            rdb.lpush(msg_key, xmsg.pack)
            rdb.publish(pub_key, msg_key)

            puts "Message written to #{xenode_id}"

          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end

    end

  end

  class ClearLogMessages < ::Escort::ActionCommand::Base
    def execute
      begin
        lib_dir = Xeno::lib_dir
        
        if command_name.to_s.downcase == 'log'
          if command_options[:xenode_id_given]
            xenode_id = command_options[:xenode_id]
            log_path = File.expand_path(File.join(lib_dir,'..','log',"#{xenode_id}.log"))
            puts "clearing log: #{log_path}"
            File.unlink(log_path) if File.exist?(log_path)
            puts "Log messages for xenode: #{xenode_id} cleared."
          else
            puts "*WARNING* This will clear all logs. Do you want to proceed? [y/n]:"
            user_input = STDIN.gets.chomp
            if user_input[0] == "Y" || user_input[0] == "y"
              log_path = File.expand_path(File.join(lib_dir,'..','log',"*.log"))
              puts "clearing log: #{log_path}"
              FileUtils.rm Dir.glob(log_path)
              puts "All log messages cleared."
            else
              puts "Cancelled clearing all log messages."
            end
          end
        end
      rescue Exception => e
        puts "#{e.inspect} #{e.backtrace}"
      end
    end
  end
  
  def self.lib_dir
    Pathname.new(__FILE__).realpath.dirname
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
            v['xenodes'].each_pair do |xk, xv|
              xv['id'] = xk
              # also add xenoflow info into xenode
              xv['xenoflow_file_name'] = file_name
              xv['xenoflow_id'] = k
            end
          end
        end
        #END unless
        # don't symbolized because we use string to get the valuse in other methods
        # symbolized_hash = Xeno::symbolize_hash_keys(hash)
        ret_val = hash
      else
        puts "* CLI cannot find any xenoflow in file: #{file_path}"
      end
    else
      puts "* CLI cannot find xenoflow file: #{file_path}"
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

  # and I need to grab the xenode config from xenoflow file and merge it with the default
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
        def_cfg = YAML.load(yml) if yml
      end
      def_cfg['loop_delay'] = 5.0 unless def_cfg.has_key?('loop_delay')
      def_cfg['enabled'] = true unless def_cfg.has_key?('enabled')
      def_cfg['debug'] = false unless def_cfg.has_key?('debug')

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
  
  def self.symbolize_hash_keys(hash)
    ret_val = {}
    hash.each_pair do |k,v|
      v = Xeno::symbolize_hash_keys(v) if v.is_a?(Hash)
      ret_val[k.to_sym] = v
    end
    ret_val
  end
  # END symbolize_hash_keys
  
end
