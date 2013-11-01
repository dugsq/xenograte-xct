# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require "minitest/autorun"

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'instance_xenode'))

describe "instance_xenode tests" do

  before do
    lib_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
    @cmd = "ruby -I #{lib_dir} -- #{lib_dir}/instance_xenode.rb -f echo_node -k EchoNode -i echonodetest1"
    @pid_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'run', 'pids', 'echonodetest1_pid'))
  end
  
  describe "startup a xenode" do

    it 'should run a xenode in the background' do
      
      # run the xenode
      system("#{@cmd} &")
      
      sleep(1)
      
      # pid file should have been created
      File.exist?(@pid_path).must_equal true
      
      # make sure the node is running
      pid = File.read(@pid_path).to_i
      res = true
      begin
        Process.kill(0,pid)
      rescue
        res = false
      end
      res.must_equal true
      
      # kill the xenode
      Process.kill("TERM", pid)
      # it should remove the pid
      sleep(1)
      File.exist?(@pid_path).must_equal false
      # make sure the pid is not running
      res = true
      begin
        Process.kill(0,pid)
      rescue
        res = false
      end
      res.must_equal false
      
    end
    
 

  end
  
end