# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

class StartNode
  include XenoCore::NodeBase
  
  def startup()
    @routes = @config[:routes]
  end
  
  def process_message(msg)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    begin
    
      if msg
        do_debug("#{mctx} - context: #{msg.context.inspect}")
      end
    
    rescue Exception => e
      catch_error("#{mctx} - #{e.inspect} #{e.backtrace}")
    end
    
  end
  
end