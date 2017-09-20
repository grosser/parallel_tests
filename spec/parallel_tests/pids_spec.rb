require 'spec_helper'

RSpec.describe ParallelTests::Pids do
  let(:file_path) { Tempfile.new('pidfile').path }
  subject { described_class.new(file_path) }

  before do
    subject.send(:clear)
    subject.add(1, 123)
    subject.add(2, 456)
  end

  describe '#add' do
    specify do
      subject.add(3, 789)
      expect(subject.send(:all)).to eq ([123, 456, 789])
    end
  end
  
  describe '#delete' do
    specify do
      subject.add(3, 101)
      subject.delete(1)
      expect(subject.send(:all)).to eq ([456, 101])
    end
  end

  describe '#count' do
    specify { expect(subject.count).to eq(2) }
  end
end
