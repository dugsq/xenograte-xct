# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

class SingleMessageNode
  include XenoCore::NodeBase
  
  # This xenode uses the startup to send
  # a single message to it's children.
  # The msg_data in the config will be sent in the message data.
  def startup()
    
    # the data for the message
    msg_data = @config[:msg_data]
    
    # the message
    msg = XenoCore::Message.new
    
    # set the data to whats in the config
    msg.data = msg_data

    # write to the children
    write_to_children(msg)
    
    do_debug("#{mctx} - sent message. #{msg.to_hash}")
  end
  
end