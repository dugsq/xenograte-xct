require 'redis'
require 'em-hiredis'
require 'logger'
require 'minitest/autorun'
require 'eventmachine'

# set lib dir so we can include libs
@lib_dir = File.expand_path(File.join(File.dirname(__FILE__),'..', 'lib'))
# require xeno_queue.rb
require File.join(@lib_dir, 'xeno_queue')
require File.join(@lib_dir, 'xeno_message')


describe "xeno_queue tests" do
  
  before do
    
    log_path = File.join("test", "xeno_queue_test.log")
    
    # create log
    @log = Logger.new(log_path)
    @log.level = Logger::DEBUG
    
    # setup opts for xeno_queue
    @opts1 = {}
    
    # redis connection
    redis_conn = {
      :host   => '127.0.0.1',
      :port   => 6379,
      :db     => 12
    }
    
    @count = 0
    @count1 = 0
    
    # add log
    @opts1[:log] = @log
    @opts1[:xenode_config] = {:children => ["n2", "n3"]}
    @opts1[:redis_conn] = redis_conn
    @opts1[:xenode_id] = "n1"
    @opts1[:debug] = true
    @opts1[:block_on_failed] = false
    
    @opts2 = {}
    @opts2[:log] = @log
    @opts2[:xenode_config] = {:children => ["n1"]}
    @opts2[:redis_conn] = redis_conn
    @opts2[:xenode_id] = "n2"
    @opts2[:debug] = true
    @opts2[:block_on_failed] = false
    
    # flushdb(redis_conn[:db].to_i)

  end
  
  after do
    # flush db
    r = Redis.new
    r.select 12
    r.flushall
  end
  
  describe "Tests run in eventmachine run loop" do
    
    it 'should push and publish a message' do
        
      EM.run do
        
        # time out
        EM.add_timer(0.5) do
          EM.stop
          flunk "Test timed out!"
        end
        
        EM.add_timer(0.1) do

          nq1 = XenoCore::XenoQueue.new(@opts1)
          nq2 = XenoCore::XenoQueue.new(@opts2)
                  
          nq2.on_message { |msg|
            if msg
              @count += 1
              if @count > 3
                EM.stop
              end
            end
          }
          
          msg = XenoCore::Message.new
          msg.data = "hello from n1"
          msg.to_id = "n2"
          
          # send 4 messages
          nq1.send_msg("n2", msg)
          nq1.send_msg("n2", msg)
          nq1.send_msg("n2", msg)
          nq1.send_msg("n2", msg)
          
        end
        
      end
      
      @count.must_equal 4

    end
    
    it 'should get failed messages count' do
        
      EM.run do
        
        # time out
        EM.add_timer(0.5) do
          EM.stop
          flunk "Test timed out!"
        end
        
        EM.add_timer(0.1) do

          nq1 = XenoCore::XenoQueue.new(@opts1)
          
          msg = XenoCore::Message.new
          msg.data = "hello from n1"
          msg.to_id = "n1"
          nq1.fail_message(msg)
          
          # give the above fail_message a chance to run first
          EM.add_timer(0.2) do
            nq1.failed_msgs_count do |count|
              if count
                @count = count
                EM.stop
              end
            end
          end

        end
        
      end
      
      @count.must_equal 1

    end
    
    it 'should write messages to children' do
      
      EM.run do
        
        # time out
        EM.add_timer(0.5) do
          EM.stop
          flunk "Test timed out!"
        end
        
        nq1 = XenoCore::XenoQueue.new(@opts1)
        
        msg = XenoCore::Message.new
        msg.data = "hello from n1"
        msg.to_id = "n2"
        
        nq1.write_to_children(msg)
        
        EM.add_timer(0.2) do
          
          # msg to n2
          nq1.get_count("n2:msg") do |count|
            if count
              @count = count
              EM.stop
            end
          end
          
          # msg to n3
          nq1.get_count("n2:msg") do |count|
            if count
              @count1 = count
              EM.stop
            end
          end
          
        end
        
      end
      
      @count.must_equal 1
      @count1.must_equal 1
      
    end
    
  end

end




