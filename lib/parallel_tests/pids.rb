require 'tempfile'
require 'singleton'
require 'json'

module ParallelTests
  class Pids
    attr_reader :file, :pids, :mutex

    include Singleton

    def initialize
      @file = Tempfile.new('parallel_pids')
      @mutex = Mutex.new
      @pids = {}
      save
    end

    def file_path
      file.path
    end

    def add(test_num, pid)
      pids[test_num] = pid
      save
    end

    def delete(test_num)
      pids.delete(test_num)
      save
    end

    def count_from_file(path)
      sync do
        JSON.parse(File.read(path)).count
      end
    end

    def all
      read
      pids.values
    end

    def clear
      @pids = {}
      save
    end

    private

    def read
      sync do
        @pids = JSON.parse(file.read)
      end
    end

    def save
        sync do
          file.truncate(0)
          file.write(pids.to_json)
          file.rewind
        end
    end

    def sync
      mutex.synchronize { yield }
    end
  end
end
