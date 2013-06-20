# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

module XenoCore

  class XenoQueue

    def initialize(opts)
      mctx = "#{self.class}.#{__method__}()"

      begin

        @log = opts[:log]
        do_debug("#{mctx} - opts: #{opts.inspect}")

        redis_conn  = nil
        redis_conn = opts[:redis_conn]

        # load options
        @rdb        = EM::Hiredis.connect(redis_conn)
        @rdb_sub    = EM::Hiredis.connect(redis_conn).pubsub
        @config     = opts[:xenode_config]
        @xenode_id  = opts[:xenode_id]

        @debug      = opts[:debug]
        @block_on_failed = opts[:block_on_failed]


        # set store keys
        @msg_key      = "#{@xenode_id}:msg"
        @msg_pub_key  = "#{@xenode_id}:msgpub"
        @msg_fail_key = "#{@xenode_id}:fail_msg"

        # setu subscriptions
        set_subscribe(@xenode_id)

        # hookup subscription to call get_msg()
        @rdb_sub.on(:message) do |channel, msg|
          do_debug("#{mctx} - channel: #{channel}")
          if channel == @msg_pub_key
            do_debug("#{mctx} - calling get_msg()")
            get_msg()
          end
        end

        get_msg()

      rescue Exception => e
        raise "#{mctx} - #{e.inspect} #{e.backtrace}"
      end

    end

    # callbacks
    def on_message(&blk)
      @msg_callback = blk if blk
    end

    def get_msg
      # note don't wrap this method in a fiber
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      # logsys(mctx, "get_msg() called in xeno_queue...")
      if @rdb
        do_debug("#{mctx} - called.", true)
        res = @rdb.llen(@msg_fail_key)
        res.callback do |failed|
          do_debug("#{mctx} - failed count is: #{failed.inspect}", true)
          # pop the next message
          if @block_on_failed && failed > 0
            # skip msg until failed msgs is empty
            # or @block_on_failed is false
            # puts "skipping get_msg"
          else
          # unless @block_on_failed && failed > 0
            # don't pop msg if xenode_config is nil (it can be {} though - i.e. empty)
            do_debug("#{mctx} - xenode_config is #{ @config.inspect}")
            df = @rdb.rpop(@msg_key) unless  @config.nil?
            if df
              df.callback { |msg_in|
                if msg_in
                  do_debug("#{mctx} - rpop(#{@msg_key}) msg: #{msg_in.inspect}")
                  do_debug("#{mctx} - calling @msg_callback()", true)
                  msg = XenoCore::Message.new().load(msg_in)
                  @msg_callback.call(msg) if @msg_callback
                  # call this method again in next tick - keep the loop going
                  EM.next_tick { get_msg() }
                end
              }
              df.errback { |error|
                # log error to syslog
                catch_error("#{mctx} - #{error}")
              }
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

    def failed_msgs_count
      mctx = "#{self.class}.#{__method__}"
      get_count(@msg_fail_key, "failed messages", mctx)
    end

    def queued_msgs_count
      mctx = "#{self.class}.#{__method__}"
      get_count(@msg_key, "queued messages", mctx)
    end

    def get_count(key, name = nil, mctx = nil)
      mctx ||= "#{self.class}.#{__method__}"
      name ||= "message"
      begin
        f = Fiber.current
        if @rdb
          emdefer = @rdb.llen(key)
          emdefer.callback { |count|
            if count
              # puts "key: #{key} count: #{count.inspect}"
              f.resume(count)
            end
          }
          emdefer.errback { |error|
            # puts "error in queued_msgs_count: #{error}"
            # log error to syslog
            catch_error("#{mctx} - #{error}")
            f.resume(error)
          }
        end
        return Fiber.yield
      rescue Exception => e
        catch_error("#{mctx} - #{e.inspect}", true)
      end
    end

    def send_alert(alert_msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      if @rdb
        # capture the time
        stamp = Time.now.strftime(@time_fmt)
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

      if @rdb && msg

        # makesure it is a xeno message
        xeno_msg = XenoCore::Message.new
        xeno_msg.load(msg)
        xeno_msg.to_id = to_id
        xeno_msg.from_id = @xenode_id

        packed = xeno_msg.pack

        msg_key = "#{to_id}:msg"

        do_debug("#{mctx} - msg_key: #{msg_key}")

        # make sure the config is loaded
        # get_config() if @xenode_config.nil?

        # do_debug("#{mctx} - @xenode_config: #{@config.inspect}")

        if @config[:children] && @config[:children].include?(to_id)
          # its a local xenode
          push_msg(msg_key,"#{to_id}:msgpub", packed)
          do_debug("#{mctx} - push_msg msg_key: #{msg_key} pub_key: #{to_id}:msgpub", true)
        end

      end
    end

    def push_msg(msg_key, pub_key, msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      @rdb.lpush(msg_key, msg).callback do
        # publish message
        df = @rdb.publish(pub_key, msg_key)

        df.errback do |error|
          # log error to syslog
          catch_error("#{mctx} - #{error}")
        end
      end
    end

    def write_to_children(msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      do_debug("#{mctx} - write_to_children called. msg: #{msg.inspect}", true)
      do_debug("#{mctx} - @config: #{@config.inspect}",true)
      if @config && @config[:children]
         @config[:children].each do |kid_id|
          do_debug("#{mctx} - sending msg to #{kid_id} from #{@xenode_id}.", true)
          # send the message
          # send_msg will take care of the to from ids and remote kids...
          send_msg(kid_id, msg)
        end
      end
    end

    def write_to_xenode(xenode_id, msg)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      if @config && @config[:children] && @config[:children].keys
        if xenode_id && @config[:children].keys.include?(xenode_id.to_sym)
          # send_msg will take care of the to from ids and remote kids...
          send_msg(xenode_id, msg)
        end
      end
    end

    def set_subscribe(xenode_id)
      mctx = "#{self.class}.#{__method__}() - [#{@xenode_id}]"
      # msg subscription
      @rdb_sub.subscribe(@msg_pub_key)
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
