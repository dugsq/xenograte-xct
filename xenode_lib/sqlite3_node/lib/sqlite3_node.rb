# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

# gem sqlite3 (1.3.7)
require 'sqlite3'

#
# @version 0.1.0
#
# SQLite3 Xenode listens for values to substitute into a SQL statement. 
# This xenode only works with SQLite3 and requires the sqlite3 ruby gem. 
# SQL Templates and a SQLite3 database are required to run this Xenode. 
# There are sample templates and databases in their respective directories.
#
# This xenode processes a message containing an array of hashes where each 
# hash is a row. After executing the SQL statement, the xenode will write 
# the output from the database to its children. If there was no output, it 
# passes the message data to its children as it came in.
#
# SQL Templates can have custom tokens in them which will get replaced by 
# the message context and data that gets passed in. SQL Templates don't 
# necessarily need to have the custom tokens. 
# Simply don't include the ~~ after the SQL statement.
# 
# Config file options:
#   loop_delay: float # The seconds the xenode waits before running process(). Process_message() doesn't use loop_delay.
#   enabled: true/false # Determines if the xenode process is allowed to run.
#   debug: true/false # Enables extra logging messages in the log file.
#   sql_template: filepath # SQL templates belong in the templates directory located in <project-root>/xenode_lib/sqlite3_node/templates/. If custom tokens are used, put ~~ after the statement followed by the tokens. Seperate the tokens with commas.
#   db_path: filepath # Local SQLite3 databases belong in the databases directory.
#   pass_through: true/false # Determines if the xenode will send a message to other xenodes.
#   rel_path: true/false # The relative path for templates and databases from the <project-root>/run/shared_dir directory. If set to false, the database files will be pulled from the direct filepath specified.
#
# @example Config File:
#   ---
#   loop_delay: 5
#   enabled: true
#   debug: true
#   sql_template: xenode_lib/sqlite3_node/templates/insert_shipping_tokens.tmp
#   db_path: databases/Shipping.db
#   pass_through: true
#   rel_path: true
#
# @example Example Input:
#   insert_shipping_tokens.tmp: INSERT INTO Shipping VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)~~|ponum|,|odate|,|pnum|,|pname|,|qty|,|price|,|sdate|,|smethod|,|comment|,|adate|
#   msg.context: {:sqlite3_node=>{"PurchaseOrderNumber"=>"|ponum|", "OrderDate"=>"|odate|", "PartNumber"=>"|pnum|", "ProductName"=>"|pname|", "Quantity"=>"|qty|", "USPrice"=>"|price|", "ShipDate"=>"|sdate|", "ShipMethod"=>"|smethod|", "Comment"=>"|comment|", "ArrivalDate"=>"|adate|"}}
#   msg.data: [{"PurchaseOrderNumber"=>"99503", "OrderDate"=>"2013-03-10", "PartNumber"=>"872-AA", "ProductName"=>"Lawnmower", "Quantity"=>50, "USPrice"=>148.95, "ShipDate"=>"2013-03-11", "ShipMethod"=>"AIR", "Comment"=>"Confirm Order by 2013-03-10", "ArrivalDate"=>"2013-05-11"}, {"PurchaseOrderNumber"=>"23567", "OrderDate"=>"2013-03-14", "PartNumber"=>"17-A6-23", "ProductName"=>"Particle Cannon", "Quantity"=>3, "USPrice"=>1948628.95, "ShipDate"=>"2013-03-16", "ShipMethod"=>"SEA", "Comment"=>"Confirm Order by 2013-03-15", "ArrivalDate"=>"2013-03-16"}]
#
# @example Run Command:
#   $ bin/xeno run xenode -i sqlite -f sqlite3_node -k SQLite3Node
#   $ bin/xeno write message -i sqlite -f xenode_lib/sqlite3_node/test_data/sqlite3_write_message.yml
#   $ sqlite3 run/shared_dir/databases/Shipping.db 
#   $ SELECT * FROM Shipping;
#   
# @example Example Output:
#   SQL Statement: INSERT INTO Shipping VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)  #Data: ["99503", "2013-03-10", "872-AA", "Lawnmower", 50, 148.95, "2013-03-11", "AIR", "Confirm Order by 2013-03-10", "2013-05-11"]
#   SQL Statement: INSERT INTO Shipping VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)  #Data: ["23567", "2013-03-14", "17-A6-23", "Particle Cannon", 3, 1948628.95, "2013-03-16", "SEA", "Confirm Order by 2013-03-15", "2013-03-16"]
#   SQL Results: [[], []] # INSERT statements don't return anything from the database. If there is no output then msg.data gets left alone.
#   msg.data being sent to children: [{"PurchaseOrderNumber"=>"99503", "OrderDate"=>"2013-03-10", "PartNumber"=>"872-AA", "ProductName"=>"Lawnmower", "Quantity"=>50, "USPrice"=>148.95, "ShipDate"=>"2013-03-11", "ShipMethod"=>"AIR", "Comment"=>"Confirm Order by 2013-03-10", "ArrivalDate"=>"2013-05-11"}, {"PurchaseOrderNumber"=>"23567", "OrderDate"=>"2013-03-14", "PartNumber"=>"17-A6-23", "ProductName"=>"Particle Cannon", "Quantity"=>3, "USPrice"=>1948628.95, "ShipDate"=>"2013-03-16", "ShipMethod"=>"SEA", "Comment"=>"Confirm Order by 2013-03-15", "ArrivalDate"=>"2013-03-16"}]
class SQLite3Node
  include XenoCore::NodeBase

  # Initialization of variables derived from @config.
  #
  # @param opts [Hash]
  def startup()
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"

    @debug = @config[:debug]
    
    # convenience 
    do_debug("#{mctx} - config: #{@config.inspect}")
    
    # Open the local database
    if @config[:rel_path]
      @db = SQLite3::Database.new File.join(@shared_dir, @config[:db_path].to_s).to_s
    else
      @db = SQLite3::Database.new @config[:db_path].to_s
    end
    @start_time = 0.0
    @msg_count = 0
  end

  # Writes the database output to children. If no output was given then
  # the message data will get passed to children without being modified.
  #
  # @param msg [XenoCore::Message] The original message that was passed to this Xenode.
  # @param data [Array] Contains the output from the database or an empty array if there was no output.
  def send_data(msg, data)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    # Send output from database to child xenodes if config
    # flag pass_through is set to true.
    # If the SQL statement requires no output, the original
    # message data is sent
    if (@config[:pass_through] == true)
      if data.flatten.length > 0
        msg.data = data
      end
     
      do_debug("Message to child node: #{msg}")
      do_debug("Context to child node: #{msg.context}")
      do_debug("Data to child node: #{msg.data}")

      write_to_children(msg)
    end
  end

  # Invoked by controlling process when a message is published to the Xenode. 
  # Sets up the database connection and executes the SQL statement.
  #
  # @param msg [XenoCore::Message] The message being passed to this Xenode.
  def process_message(msg)
   
    do_debug("Message from parent node: #{msg}")
    do_debug("Context from parent node: #{msg.context}")
    do_debug("Data from parent node: #{msg.data}")


    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    return_val = []

    @start_time = Time.now.to_f unless @start_time > 0.0
    @msg_count += 1

    # Load SQL template file
    # Read the SQL statement from the template file
    # gsub is used for substituting newlines with
    # spaces in the sql statement
    sql_cmd = ""
    File.open(@config[:sql_template], "r").each_line do |line|
      sql_cmd << line.gsub(/\n/, ' ')
    end

    # Rescued if there is a SQLException error
    # Example, creating a table that already exists
    begin
      # A SQL template containing ~~ after the sql statement
      # tells the xenode to expect tokens
      # and that the mapping is located inside the context.
      # At the moment the only mapping is an array of hashes
      # If there are no '?'s in the sql statement, don't insert data.
      if sql_cmd.include?('~~') && msg.data.class == Array && sql_cmd.include?('?')
        # The ~~ gets discarded
        sql = sql_cmd.split('~~').first
        tokens = sql_cmd.split('~~').last

        msg.data.each do |hash|
          # If there is more than one SQL statement to run then
          # refresh the variable
          tokens_array = tokens.split(',')
          hash.each_key do |key|
            tokens_array.each_index do |token_i|
              # This Xenode will accept both a symbol or string hash key
              if msg.context[:sqlite3_node] != nil
                # Replace the token in the SQL template with the data
                if hash[key].class == String
                  tokens_array[token_i] = tokens_array[token_i].to_s.gsub(msg.context[:sqlite3_node][key].to_s, "\'"+hash[key].to_s+"\'")
                else
                  tokens_array[token_i] = tokens_array[token_i].to_s.gsub(msg.context[:sqlite3_node][key].to_s, hash[key].to_s)
                end
              elsif msg.context["sqlite3_node"] != nil
                # Replace the token in the SQL template with the data
                if hash[key].class == String
                  tokens_array[token_i] = tokens_array[token_i].to_s.gsub(msg.context["sqlite3_node"][key].to_s, "\'"+hash[key].to_s+"\'")
                else
                  tokens_array[token_i] = tokens_array[token_i].to_s.gsub(msg.context["sqlite3_node"][key].to_s, hash[key].to_s)
                end
              end
            end
          end
          do_debug("SQL Statement: #{sql} #Data: #{tokens_array}")
          # Run SQL Statement
          return_val << @db.execute(sql, tokens_array)
          do_debug("SQL Results: #{return_val}")
        end
      # NO ~~ in sql command with tokens but there's
      # still data to insert
      # At the moment the only mapping is an array of hashes
      # If there are no '?'s in the sql statement, don't insert data.
      elsif msg.data.class == Array && sql_cmd.include?('?')
        msg.data.each do |hash|
          do_debug("SQL Statement: #{sql_cmd} #Data: #{hash.values}")
          # Run SQL Statement
          return_val << @db.execute(sql_cmd, hash.values)
          do_debug("SQL Results: #{return_val}")
        end
      # No ~~ in sql command with tokens and there's
      # no data then just run the sql statement.
      # Used for sql statements that don't require input
      # Example: SELECT * FROM Shipping;
      else
        do_debug("SQL Statement: #{sql_cmd}")
        # Run SQL Statement
        return_val << @db.execute(sql_cmd)
        do_debug("SQL Results: #{return_val}")
      end

      # Write to children
      send_data(msg, return_val)
    # Catch SQL errors
    # Example, creating a table that already exists
    rescue SQLite3::SQLException => sql_e
      @log.error("#{mctx} - #{sql_e.inspect} #{sql_e.backtrace}")
    end

  # If incorrect data is submitted, log error but keep running
  rescue Exception => e
    @log.error("#{mctx} - #{e.inspect} #{e.backtrace}")
  end
end
