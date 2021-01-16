# frozen_string_literal: true
require 'spec_helper'

RSpec.describe ParallelTests::Pids do
  let(:file_path) { Tempfile.new('pidfile').path }
  subject { described_class.new(file_path) }

  before do
    subject.send(:clear)
    subject.add(123)
    subject.add(456)
  end

  describe '#add' do
    specify do
      subject.add(789)
      expect(subject.all).to eq([123, 456, 789])
    end
  end

  describe '#delete' do
    specify do
      subject.add(101)
      subject.delete(123)
      expect(subject.all).to eq([456, 101])
    end
  end

  describe '#count' do
    specify { expect(subject.count).to eq(2) }
  end

  describe '#all' do
    specify { expect(subject.all).to eq([123, 456]) }
  end
end
