require 'tempfile'
require 'json'

module ParallelTests
  class Pids
    attr_reader :pids, :file_path, :mutex

    def initialize(file_path)
      @file_path = file_path
      @mutex = Mutex.new
    end

    def add(test_num, pid)
      pids[test_num.to_s] = pid
      save
    end

    def delete(test_num)
      pids.delete(test_num.to_s)
      save
    end

    def count
      read
      pids.count
    end

    private

    def pids
      @pids ||= {}
    end

    def all
      read
      pids.values
    end

    def clear
      @pids = {}
      save
    end

    def read
      sync do
        contents = IO.read(file_path)
        return if contents.empty?
        @pids = JSON.parse(contents)
      end
    end

    def save
      sync { IO.write(file_path, pids.to_json) }
    end

    def sync
      mutex.synchronize { yield }
    end
  end
end
