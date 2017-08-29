require 'spec_helper'

RSpec.describe ParallelTests::Pids do
  subject { described_class.instance }

  before do
    subject.clear
    subject.add(1, 123)
    subject.add(2, 456)
  end

  describe '#add' do
    specify do
      subject.add(3, 789)
      expect(subject.all).to eq ([123, 456, 789])
    end
  end
  
  describe '#delete' do
    specify do
      subject.add(3, 101)
      subject.delete(1)
      expect(subject.all).to eq ([456, 101])
    end
  end

  describe '#clear' do
    specify do
      subject.add(1, 222)
      subject.clear
      expect(subject.all).to eq ([])
    end
  end

  describe '#file_path' do
    specify do
      expect(File.exists?(subject.file_path)).to eq(true)
    end
  end

  describe '#all' do
    specify { expect(subject.all).to eq([123,456]) }
  end
  
  describe '#count_from_file' do
    let(:file_path) { subject.file_path }
    specify { expect(subject.count_from_file(file_path)).to eq(2) }
  end
end
