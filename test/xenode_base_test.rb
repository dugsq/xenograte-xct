# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

require "minitest/autorun"
require 'logger'
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'xenode_base'))


module Helpers
  
  def set_opts
    ret_val = {}
    root_dir = File.expand_path(File.join(File.dirname(__FILE__),'..'))
root_dir.must_equal "poo"

    xenode_pid = "#{@xenode_id}_pid"

    # all other directories are off of the run_dir
    
    # xenode_lib_dir = File.join(root_dir,'xenode_lib') # your xenode library
    # xeno_flow_dir  = File.join(root_dir,'xenoflows')  # xenoflows directory
    # run_dir        = File.join(root_dir,"run")        # run directory for running xenode instances
    # tmp_dir        = File.join(run_dir,"tmp")         # tmp directory for all xenode instances
    # xenodes        = File.join(run_dir,'xenodes')     # xenodes instance directory
    # disk_dir       = File.join(xenodes, @xenode_id, 'files')  # disk dir for xenode to read and write scratch files
    # log_dir        = File.join(xenodes, @xenode_id, 'log') # the log directory
    # pid_dir        = File.join(run_dir,'pids')        # pids directory
    # @pid_path      = File.join(pid_dir, xenode_pid)   # full path to pid file
    # config_dir     = File.join(xenodes, @xenode_id, 'config')   # xenode's config directory
    ret_val
  end
  
end

describe "Xenode_base tests" do
  include Helpers
  
  before do
    
  end
  
  describe "Test initialization" do
    
    it 'should be initialized from options' do
      set_opts
    end
    
  end
  
  
end