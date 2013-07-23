# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require 'fileutils'

class FileReaderNode
  include XenoCore::NodeBase
  
  def startup
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    do_debug("#{mctx} - config: #{@config.inspect}")
    
    # get where to look for the file
    if @config[:rel_path]
      @file_dir_path = File.join(@shared_dir, @config[:dir_path])
    else
      @file_dir_path = @config[:dir_path]
    end
    
    # file_mask of the file to read i.e. '*.txt'
    @file_mask = @config[:file_mask]
    
    # just grab the full file path without reding the
    # file contents into the message data if path_only is true
    @path_only = @config[:path_only]
    
    do_debug("#{mctx} - file_dir_path: #{@file_dir_path.inspect} file_mask: #{@file_mask.inspect} path_only: #{@path_only.inspect}", true)
  end
  
  def process
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    do_debug("#{mctx} called.", true)
    
    # this method gets called every @loop_delay seconds
    if @file_dir_path && @file_mask
      
      fp = File.join(@file_dir_path, @file_mask)
      
      do_debug("#{mctx} - looking for files matching: #{fp}", true)
      
      files = Dir.glob(fp)
    
      # loop through the files
      files.each do |f|
      
        # create a new message
        msg = XenoCore::Message.new
      
        if File.exist?(f)
          # write the file_path to the message's context
          # so we have it down stream
          # context should last across nodes
          # i.e. a node can add to the context but should not delete it
        
          # force logging of this message (write out the file_path)
          do_debug("#{mctx} - file added to context: #{f}", true)
          msg.context ||= {}
          msg.context[:file_path] = f
        
          unless @path_only
            msg.data = File.read(f)
          end
        
          # write the message to all the children of this node
          do_debug("#{mctx} - reading data from file: #{f}", true)
          write_to_children(msg)
          do_debug("#{mctx} - write to children", true)
        end
      
        # rename the file so it doesn't get read again
        do_debug("#{mctx} - file #{f} exists: #{File.exist?(f)}", true)
        if File.exist?(f)
          do_debug("#{mctx} - backing up read file: #{f}", true)
          # yes it could have been deleted between first check and this one...
          FileUtils.mv(f, "#{f}.bak") if File.exist?(f) 
        end
      
      end
    
    end
    
  end
  
end

