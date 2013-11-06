# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

module XenoCore

  class XenoQueue
    
    TIMEFMT = "%Y-%m-%d %H:%M:%S.%L"
    
    def initialize(opts)
      
      begin

        @log            = opts[:log]
        @xenode_id      = opts[:xenode_id]
        @xenode_config  = opts[:xenode_config] # it is the whole xenode config, NOT the config key inside it
        
        redis_conn  = opts[:redis_conn]
        
        mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
                
        # load options
        conn_url       = "redis://#{redis_conn[:host]}:#{redis_conn[:port]}/#{redis_conn[:db]}"
        @rdb           = EM::Hiredis.connect(conn_url)
        @rdb_sub       = EM::Hiredis.connect(conn_url)
        @debug         = opts[:debug]
        
        @block_on_failed = opts[:block_on_failed]

        # set store keys
        @msg_key      = "#{@xenode_id}:msg"
        @msg_pub_key  = "#{@xenode_id}:msgpub"
        @msg_fail_key = "#{@xenode_id}:fail_msg"
        @alert_key    = "#{@xenode_id}:alertmsg"

        # hookup subscription to call get_msg()
        subscribe
        
        do_debug("#{mctx} - redis_conn: #{redis_conn} conn_url: #{conn_url}", true)
        get_msg()

      rescue Exception => e
        raise "#{mctx} - #{e.inspect} #{e.backtrace}"
      end

    end
    
    def subscribe
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      
      # hookup subscription to call get_msg()
      @rdb_sub.pubsub.on(:message) do |channel, msg|
        if channel == @msg_pub_key
          do_debug("#{mctx} - calling get_msg()", true)
          get_msg()
        end
      end

    end
    
    # callbacks
    def on_message(&blk)
      if blk
        @msg_callback = blk 
        get_msg()
      end
    end
    
    def get_msg
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      do_debug("#{mctx} -- entering get_msg() @rdb.nil?: #{@rdb.nil?}")

      if @rdb
        @rdb.llen(@msg_fail_key).callback do |failed_count|
          if @block_on_failed && failed_count > 0
            do_debug("#{mctx} - block_on_failed: #{@block_on_failed.inspect} failed_count: #{failed_count.inspect}", true)
          else
            
            @rdb.rpop(@msg_key).callback do |msg_in|
              do_debug("#{mctx} - rpop callback msg_in: #{msg_in.inspect}", true)
              if msg_in
                do_debug("#{mctx} - calling @msg_callback()")
                msg = XenoCore::Message.new().load(msg_in)
                @msg_callback.call(msg) if @msg_callback
                EM.next_tick { get_msg() }
              end
            end
          end
        end
      end

    end

    def fail_message(msg)
      # note don't wrap this method in a fiber
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      if @rdb
        df = @rdb.lpush(@msg_fail_key, msg)
        df.callback do
          # msg now in failed queue
          # send alert
          send_alert("Failed Message")
        end
        df.errback do |error|
          # log error to syslog
          catch_error("#{mctx} - #{error}")
        end
      end
    end

    # expects a block to yield to
    def failed_msgs_count
      mctx ||= "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      begin
        if @rdb
          @rdb.llen(@msg_fail_key).callback do |count|
            if count
              do_debug("#{mctx} - count: #{count}", true)
              yield(count)
            else
              yield(0)
            end
          end
        end
      rescue Exception => e
        catch_error("#{mctx} - #{e.inspect}", true)
      end
    end

    def queued_msgs_count
      mctx ||= "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      begin
        if @rdb
          @rdb.llen(@msg_key).callback do |count|
            if count
              do_debug("#{mctx} - count: #{count}", true)
              yield(count)
            else
              yield(0)
            end
          end
        end
      rescue Exception => e
        catch_error("#{mctx} - #{e.inspect}", true)
      end
    end
    
    # expects a block 
    def get_count(key)
      mctx ||= "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      
      begin
        if @rdb
          @rdb.llen(key).callback do |count|
            if count
              do_debug("#{mctx} - key: #{key} count: #{count}", true)
              yield(count)
            else
              yield(0)
            end
          end
        end
      rescue Exception => e
        catch_error("#{mctx} - #{e.inspect}", true)
      end
    end

    def send_alert(alert_msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      if @rdb
        # capture the time
        stamp = Time.now.strftime(TIMEFMT)
        # set the alert
        alert = "#{stamp}|#{@xenode_id}|#{alert_msg}"
        # write alert to queue
        df = @rdb.lpush(@alert_key, alert)
        df.callback do
          # notify alert callback
          @alert_callback.call(alert) if @alert_callback
        end
        df.errback do |error|
          # user log
          catch_error("#{mctx} - #{error} - Unable to send alert (not sent): #{alert.inspect}")
        end
      end
    end

    def send_msg(to_id, msg)
      # note don't wrap this method in a fiber
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      
      begin
        
        if @rdb && msg

          # makesure it is a xeno message
          xeno_msg = XenoCore::Message.new
          xeno_msg.load(msg)
          xeno_msg.to_id = to_id
          xeno_msg.from_id = @xenode_id

          packed = xeno_msg.pack

          msg_key = "#{to_id}:msg"

          do_debug("#{mctx} - msg_key: #{msg_key}", true)

          # make sure the config is loaded
          # get_config() if @xenode_config.nil?

          # do_debug("#{mctx} - @xenode_config: #{@xenode_config.inspect}")

          if @xenode_config[:children] && @xenode_config[:children].include?(to_id)
            # its a local xenode
            push_msg(msg_key,"#{to_id}:msgpub", packed)
            # do_debug("#{mctx} - push_msg msg_key: #{msg_key} pub_key: #{to_id}:msgpub", true)
          end

        end
      
      rescue Exception => e
        do_debug("#{mctx} ERROR: #{e.message}", true)
        catch_error("#{mctx} ERROR: #{e.message} #{e.backtrace}")
      end 
      
    end
    
    def push_msg(msg_key, pub_key, msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      
      begin
        do_debug("#{mctx} - pushing message msg:key #{msg_key}")
        @rdb.lpush(msg_key, msg).callback do
          do_debug("#{mctx} - pushed msg...", true)
          # publish message
          @rdb_sub.publish(pub_key, msg_key).callback do |pubcount|
            do_debug("#{mctx} - published msg to #{pubcount} clients.")
          end
        end
      rescue => e
        do_debug("#{mctx} ERROR: #{e.message}", true)
        catch_error("#{mctx} ERROR: #{e.message} #{e.backtrace}")
      end
    end

    def write_to_children(msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      do_debug("#{mctx} - write_to_children called. msg: #{msg.inspect}", true)
      do_debug("#{mctx} - @xenode_config: #{@xenode_config.inspect}",true)
      if @xenode_config && @xenode_config[:children]
         @xenode_config[:children].each do |kid_id|
          do_debug("#{mctx} - sending msg to #{kid_id} from #{@xenode_id}.", true)
          # send the message
          send_msg(kid_id, msg)
        end
      end
    end

    def write_to_xenode(xenode_id, msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      if @xenode_config && @xenode_config[:children]
        if xenode_id && @xenode_config[:children].include?(xenode_id)
          do_debug("#{mctx} - sending message to xenode: #{xenode_id}", true)
          # send_msg will take care of the to from ids and remote kids...
          send_msg(xenode_id, msg)
          catch_error("#{mctx} - #{xenode_id.inspect} is not a child of xenode: #{@xenode_id}")
        end
      end
    end

    def catch_error(error_message, reraise = false)
      if error_message
        @log ? @log.error(error_message) : warn(error_message)
        raise(Exception, error_message) if reraise
      end
    end

    def do_debug(msg, force = false)
      if @debug || force
        @log.debug(msg) if @log
      end
    end

  end

end
