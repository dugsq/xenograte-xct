# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

# 
# @version 0.1.0
#
# Hash to CSV Xenode parses through an array of hashes from incoming message
# data then converts them into CSV format and sends the data off
# to the next Xenode.
#
# Config file options:
#   loop_delay: float # The seconds the xenode waits before running process(). Process_message() doesn't use loop_delay.
#   enabled: true/false # Determines if the xenode process is allowed to run.
#   debug: true/false # Enables extra logging messages in the log file.
#   has_header: true/false # If set to true, the first line of output will contain the column names.
#   row_delim: string # The default row delimiter.
#   col_delim: string # The default column delimiter.
#
# @example Config File:
#   ---
#   loop_delay: 5
#   enabled: true
#   debug: true
#   has_header: true
#   row_delim: "\n"
#   col_delim: ","
#
# @example Example Input:
#   msg.data: [{"PurchaseOrderNumber"=>"99503", "OrderDate"=>"2013-03-10", "PartNumber"=>"872-AA", "ProductName"=>"Lawnmower", "Quantity"=>50, "USPrice"=>148.95, "ShipDate"=>"2013-03-11", "ShipMethod"=>"AIR", "Comment"=>"Confirm Order by 2013-03-10", "ArrivalDate"=>"2013-05-11"}, {"PurchaseOrderNumber"=>"23567", "OrderDate"=>"2013-03-14", "PartNumber"=>"17-A6-23", "ProductName"=>"Particle Cannon", "Quantity"=>3, "USPrice"=>1948628.95, "ShipDate"=>"2013-03-16", "ShipMethod"=>"SEA", "Comment"=>"Confirm Order by 2013-03-15", "ArrivalDate"=>"2013-03-16"}]
#
# @example Run Command:
#   $ bin/xeno run xenode -i hash_to_csv -f hash_to_csv_node -k HashToCsvNode
#   $ bin/xeno write message -i hash_to_csv -f xenode_lib/hash_to_csv_node/test_data/hash_to_csv_write_message.yml
#
# @example Example Output:
#   msg.data: "PurchaseOrderNumber,OrderDate,PartNumber,ProductName,Quantity,USPrice,ShipDate,ShipMethod,Comment,ArrivalDate\n99503,2013-03-10,872-AA,Lawnmower,50,148.95,2013-03-11,AIR,Confirm Order by 2013-03-10,2013-05-11\n23567,2013-03-14,17-A6-23,Particle Cannon,3,1948628.95,2013-03-16,SEA,Confirm Order by 2013-03-15,2013-03-16"
class HashToCsvNode
  include XenoCore::NodeBase

  # Initialization of variables derived from @config.
  #
  # @param opts [Hash]
  def startup(opts = {})
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    @debug = @config[:debug]
    
    # convenience 
    do_debug("#{mctx} - config: #{@config.inspect}")

    @start_time = 0.0
    @msg_count = 0

    # @has_header is set in the config.
    # If true, the first line of the CSV data will contain the column names
    @has_header = @config[:has_header]
    # row delimiter default value.
    @default_row_delim = @config[:row_delim].to_s
    # field or column delimiter default value.
    @default_col_delim = @config[:col_delim].to_s
  end

  # Parses through the data passed in from the message. Each line of CSV output data 
  # will be generated from each hash inside the array. If has_header is set as 
  # true in the config then the first line will be the column names in CSV format.
  #
  # @param data [Array] The Array of Hashes.
  # @return [String] The data within Array of Hashes in CSV format.
  def parse_hash(data)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    ret_val = ""
    
    # Reset header variable for each message received
    header = @has_header
    
    data.each do |hash|
      # If has_header is true in the config then the first line will contain
      # the column names
      if header
        hash.each_key do |key|
          ret_val << key.to_s
          ret_val << @col_delim 
        end
        # replace last column delimiter with the row delimiter
        ret_val[-1] = @row_delim
        header = false
      end
      # Write a line of data values in CSV format.
      hash.each_value do |value|
        ret_val << value.to_s
        ret_val << @col_delim
      end
      # replace last column delimiter with the row delimiter
      ret_val[-1] = @row_delim
    end
    # Return CSV data
    ret_val
  end

  # Invoked by controlling process when a message is published to the Xenode. 
  # Sets the row and column delimiter format and parses through the message
  # data, generating the same data in CSV format.
  #
  # @param msg [XenoCore::Message] The message being passed to this Xenode.
  def process_message(msg)
    do_debug("Message from parent node: #{msg}")
    do_debug("Context from parent node: #{msg.context}")
    do_debug("Data from parent node: #{msg.data}")

    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    @start_time = Time.now.to_f unless @start_time > 0.0
    @msg_count += 1

    if msg
      # If the context specifies a unique way to seperate columns and rows
      # then we will use that method. 
      # This xenode will accept both symbols and strings as context hash keys
      if msg.context
        if msg.context[:row_delim]
          @row_delim = msg.context[:row_delim].to_s
        elsif msg.context["row_delim"]
          @row_delim = msg.context["row_delim"].to_s
        else
          @row_delim = @default_row_delim
        end
        if msg.context[:col_delim]
          @col_delim = msg.context[:col_delim].to_s
        elsif msg.context["col_delim"]
          @col_delim = msg.context["col_delim"].to_s
        else
          @col_delim = @default_col_delim
        end
      else
        @row_delim = @default_row_delim
        @col_delim = @default_col_delim
      end
      
      do_debug("Has Header?: #{@has_header}")
      do_debug("Row Delimiter: #{@row_delim}")
      do_debug("Column Delimiter: #{@col_delim}")
      
      # Parse through the array of hashes to construct a string in csv format
      data = parse_hash(msg.data)
      
      # If nothing was generated from parsing then don't write to children.
      if data && data.length > 0
        msg.data = data
        do_debug("Message to child node: #{msg}")
        do_debug("Context to child node: #{msg.context}")
        do_debug("Data to child node: #{msg.data}")
        write_to_children(msg)
      end
    end

  # If incorrect data is submitted, log error but keep running
  rescue Exception => e
    @log.error("#{mctx} - #{e.inspect} #{e.backtrace}")
  end
end
