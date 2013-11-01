# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

class FileWriterNode
  include XenoCore::NodeBase
  
  def startup
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    do_debug("#{mctx} - config: #{@config.inspect}")
  end

  def process_message(msg)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    begin
      
      if msg
        
        # initialize vars
        file_path = file_name = nil
        mask = dir = rel_path = nil
        
        if msg.data

          # default file_mode to overwrite
          file_mode = "w"
        
          # config exists
          if @config 
            do_debug("#{mctx} - config exists", true)
            # set the file_mode from the config
            file_mode = @config[:file_mode] if @config[:file_mode]
          
            # use a relative path if rel_path is true
            rel_path = true if @config[:rel_path] 
          
            # default it to the shared_dir
            dir = @shared_dir
          
            # override the path as a full path if config has dir_path
            dir = File.expand_path(@config[:dir_path]) if @config[:dir_path]
          
            # make it a relative path if rel_path is true
            if rel_path && @shared_dir &&  @config[:dir_path]
              dir = File.expand_path(File.join(@shared_dir, @config[:dir_path])) 
            end

            if @config[:file_mask]
              mask = DateTime.now.strftime(@config[:file_mask])
            end
          
            # set the file_name
            file_name = "#{mask}_#{@config[:file_name]}" if @config[:file_name]
          
          end
        
          # override config with values from context if provided in message
          if msg.context
          
            # override the dir_path
            if msg.context[:dir_path]
              if rel_path
                dir = File.join(@shared_dir, msg.context[:dir_path])
              else
                dir = File.expand_path(msg.context[:dir_path])
              end
            end
          
            # override the file_name - will be "#{mask}_#{file_name}"
            if msg.context[:file_name]
              file_name = "#{mask}_#{msg.context[:file_name]}"
            end
          
          end
          
          do_debug("#{mctx} - mask: #{mask.inspect}", true)
          do_debug("#{mctx} - dir: #{dir.inspect}", true)
          do_debug("#{mctx} - rel_path: #{rel_path.inspect}", true)
          do_debug("#{mctx} - file_name: #{file_name.inspect}", true)
          do_debug("#{mctx} - shared_dir: #{@shared_dir.inspect}", true)
          
          # ensure directory exists
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
        
          # set the file_path
          file_path = File.expand_path(File.join(dir, file_name))
          do_debug("#{mctx} - file_path: #{file_path.inspect}", true)
          
          # write the data to the file
          File.open(file_path, "#{file_mode}") do |f|
            f.write(msg.data)
          end
        
          do_debug("#{mctx} - file written to: #{file_path.inspect}")
        
        end
    
        # add the full file_path to the context
        msg.context ||= {}
        msg.context[:file_path] = file_path
        
        # pass the message we recieved through to children
        # with the file_path context added
        write_to_children(msg)
        
      end

    rescue Exception => e
      catch_error("#{e.inspect} #{e.backtrace}")
    end
    
  end
  
end


