
# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

# This Xenode will look for the first unread message sent to the account configured
# via config from the email address set in sender, and put the contents of each
# attached file in the data key of an message sent to its child Xenodes.
#
#@version 0.3.0
#
require 'gmail'

class GmailReaderNode
  include XenoCore::NodeBase

  # Initialization of variables derived from @config.
  # @param [Hash] opts
  # @option opts [:log] Logger instance.
  def startup()
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    do_debug("#{mctx} - config: #{@config.inspect}")
    @last_check = Time.now.to_f
    @interval = @config.fetch(:interval, 300.0)
    @loop_delay = @config.fetch(:loop_delay, 5.0)
    @sender = @config[:sender]
  end

  # Triggers mail check for gmail account in @config on @loop_delay timer.
  # @param []
  def process
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    if @config
      @elapsed = Time.now.to_f - @last_check
      if @elapsed > @interval.to_f
        
        do_debug("#{mctx} - checking email.. elapsed = #{@elapsed}, loop_delay: #{@loop_delay}", true)

        data = get_data_from_sender()
        do_debug("#{mctx} - data from sender: #{data.inspect}")
        
        unless data.empty?
          data.each do |attachment|
            msg_out = XenoCore::Message.new()
            msg_out.data = attachment[:data]
            msg_out.context = msg_out.context || {}
            msg_out.context[:sender] = attachment[:sender]
            msg_out.context[:file_name] = attachment[:file_name]
            write_to_children(msg_out)
          end
        end
        
        @last_check = Time.now.to_f
      end
    end
  end

  # Retrieves attachments from first unread mail sent to account from target sender.
  # @return [Array] Each item is a hash that represents an attachment on the message.
  def get_data_from_sender
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    ret_val = []

    begin
      # process the first email for each sender

      Gmail.new(@config[:user_name], @config[:passwd]) do |gm|

        count = gm.inbox.count(:unread, :from => @sender)
        do_debug("#{mctx} - unread count: #{count.inspect} sender: #{@sender}", true) if @sender

        # process the first email only as this gets called every n seconds
        email = gm.inbox.emails(:unread, :from => @sender).first
        if email && !email.message.attachments.empty?
          
          email.message.attachments.each do |att|
            filename = nil
            filename = att.filename
            do_debug("#{mctx} - got filename: #{filename.inspect}", true)
            if filename
              data = ""
              data << att.decoded
              ret_val << {sender: @sender, file_name: filename, data: data}
            end
          end
          # testing only
          email.unread!

          # mark it as read
          # email.read!

        end
      end

    rescue Exception => e
      catch_error("#{mctx} - #{e.inspect} #{e.backtrace}")
    end
    
    ret_val
  end

end
