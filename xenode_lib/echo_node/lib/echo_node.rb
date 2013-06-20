# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

class EchoNode
  include XenoCore::NodeBase
  def process_message(message)
    write_to_children(message)
  end
end

