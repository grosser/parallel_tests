# frozen_string_literal: true
require 'spec_helper'

describe ParallelTests::RSpec::LoggerBase do
  before do
    @temp_file = Tempfile.open('xxx')
    @logger = ParallelTests::RSpec::LoggerBase.new(@temp_file)
  end

  after do
    @temp_file.close
  end

  describe 'on tests finished' do
    it 'should respond to close' do
      expect(@logger).to respond_to(:close)
    end

    it 'should close output' do
      expect(@temp_file).to receive(:close)
      @logger.close
    end

    it 'should not close stdout' do
      @logger = ParallelTests::RSpec::LoggerBase.new($stdout)
      expect($stdout).not_to receive(:close)
      @logger.close
    end

    it 'should not close IO instance' do
      io = double(IO)
      @logger = ParallelTests::RSpec::LoggerBase.new(io)
      @logger.close
    end
  end
end
