
# (c) Copyright 2009 - 2012 Nodally Technologies Inc.
# All Rights Reserved.
#

require 'fileutils'
require 'rubygems/package'
require 'zlib'

module XenoCore
  
  class Util

    def symbolize_hash_keys(hash, first_level_only = true)
      ret_val = {}
      hash.each_pair do |k,v|
        if v.is_a?(Hash) && !first_level_only
          v = symbolize_hash_keys(v) 
        end
        ret_val[k.to_sym] = v
      end
      ret_val
    end
    
    def stringify_hash_keys(hash)
      ret_val = {}
      hash.each_pair do |k,v|
        v = stringify_hash_keys(v) if v.is_a?(Hash)
        ret_val[k.to_s] = v
      end
      ret_val
    end
        
    def lock_write(fname, data, purge = false)
      if purge && File.exist?(fname)
        File.unlink(fname)
      end
      File.open(fname, "a") do |f|
        f.flock(File::LOCK_EX)
        f.write(data)
        f.flush
        f.flock(File::LOCK_UN)
        f.close
      end
    end
    
  end
    
end
