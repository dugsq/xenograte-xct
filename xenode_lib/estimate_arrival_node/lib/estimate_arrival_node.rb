# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0
require 'date'

class EstimateArrivalNode
  include XenoCore::NodeBase
  
  def startup(opts = {})
    # a handy way to log class and method
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    # use the default logger supplied by the system
    @log = opts[:log]
    # log the configuration (so we know we got it right.)
    # do_debug (will log only if the @debug flag is set in the config)
    do_debug("#{mctx} - config: #{@config.inspect}")
  end
  
  def process_message(msg)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    
    do_debug("#{mctx} - msg: #{msg.inspect}", true)
    # this node expects a shipdate and a shipmethod in order to calculate
    # an arrival date.
    
    # The configuration will have the values for each type of shipmethod
    #  under a key called shipmethods
    
    if msg
      if @config && @config[:ship_methods]
        arrival_date = nil
        # true passed to do_debug() forces the log to be written
        do_debug("#{mctx} - @config: #{@config.inspect}", true)
        
        # get the data to use for calculations
        data = msg.data
        
        if data && data.is_a?(Array)
          data.each_index do |index|
            row = data[index]
            # pull out the ship date from the data in the message
            ship_date = row['shipdate']
            # make sure the ship_date is a valid date
            ship_date = Date.parse(ship_date.to_s)
            # pull out the ship method from the message data
            ship_method = row['shipmethod']
            # use the ship_method to get the corresponding number of days from the config
            days = @config[:ship_methods][ship_method.downcase.to_sym]
            # add the number of days to the ship_date to get the arrival date
            do_debug("#{mctx} - days: #{days.inspect}", true)
            arrival_date = (ship_date + days) if days
            do_debug("#{mctx} - arrival_date: #{arrival_date.inspect}", true)
            # add the arrival date into the message data
            if arrival_date
              do_debug("#{mctx} - before updating row: #{row.inspect}", true)
              row['arrival_date'] = arrival_date.to_s
              do_debug("#{mctx} - after updating row: #{row.inspect}", true)
            end
            
            # write the new data to msg.data
            do_debug("#{mctx} - updated row: #{row.inspect}", true)
            msg.data[index] = row
            
          end
          # give the message a new id
          msg.msg_id = msg.new_id
          do_debug("#{mctx} - updated msg: #{msg.inspect}", true)
          # write the updated message out to all children
          write_to_children(msg)
        end
      end
    end
    
  end

end

  
  
