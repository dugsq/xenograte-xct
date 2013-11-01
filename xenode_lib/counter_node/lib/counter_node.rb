# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

class CounterNode
  include XenoCore::NodeBase
  
  def startup()
    mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"

    @max_msgs = @config[:max_msgs]
    @msg_count = 0
    @start_time = 0.0
    @stop_time = 0.0
    
    do_debug("#{mctx} - config: #{@config}", true)
    
    do_debug("#{mctx} - resolve_sys_dir: this_node #{resolve_sys_dir(@config[:this_node])}")
    do_debug("#{mctx} - resolve_sys_dir: this_server #{resolve_sys_dir(@config[:this_server])}")
  end
  
  def process_message(msg)
    mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
    @msg_count += 1 if msg
    @start_time = Time.now.to_f unless @start_time > 0.0
    # stop sending if we have reached the max msgs
    if @msg_count > @max_msgs
      # capture the stop time once
      @stop_time = Time.now.to_f unless @stop_time > 0.0
    else
      # add the context for max messages
      msg.context ||= {}
      msg.context[:max_msgs] = @max_msgs
      # send the message down stream to all of this nodes children
      write_to_children(msg)
    end
  end
  
  def shutdown
    mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
    
    elapsed = 0.0
    msgspersec = 0
    
    elapsed = @stop_time - @start_time if @start_time
    msgspersec = @msg_count / elapsed if elapsed > 0.0
    
    if @msg_count > 0
      if msgspersec > 0
        do_debug("#{mctx} - Processed: #{@msg_count} msgs which took #{elapsed.to_i} to run for #{msgspersec.to_i} per second.")
      end
    else
      do_debug("#{mctx} - No messages were processed.")
    end
    
  end
  
end