require 'spec_helper'

describe Fastlane::Helper::CpuLoadHandler do
  before do
    subject.stub(:sleep)
  end

  describe '#print_cpu_load' do
    it 'prints the load with passed parameter' do
      expect(Fastlane::UI).to receive(:important).with('CPU load is: 30')
      described_class.print_cpu_load(30)
    end

    it 'does not print the load if OS does not support printing it' do
      expect(Fastlane::Actions).to receive(:sh).with('cat /proc/loadavg').and_return('')
      expect(Fastlane::UI).not_to receive(:important)
      described_class.print_cpu_load
    end

    it 'prints the load with default parameter' do
      allow(described_class).to receive(:cpu_load).and_return(50)
      expect(Fastlane::UI).to receive(:important).with('CPU load is: 50')
      described_class.print_cpu_load
    end
  end

  describe '#cpu_load' do
    it 'returns the load of cpu' do
      expect(Fastlane::Actions).to receive(:sh).with('cat /proc/loadavg').and_return('0.59 1.77 2.01 1/687 19522')
      expect(described_class.cpu_load).to eql(0.59)
    end

    it 'returns nil if the command is not supported' do
      expect(Fastlane::Actions).to receive(:sh).with('cat /proc/loadavg').and_return('')
      expect(described_class.cpu_load).to be_nil
    end
  end

  describe '#cpu_core_amount' do
    it 'returns amount of cpu cores' do
      expect(Fastlane::Actions).to receive(:sh).with("cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1").and_return('3')
      expect(described_class.cpu_core_amount).to eql('3')
    end
  end

  describe '#wait_cpu_to_idle' do
    it 'returns true if the platform is not linux' do
      allow(OS).to receive(:linux?).and_return(false)
      expect(described_class.wait_cpu_to_idle).to be true
    end

    it 'returns true immediately if load is *1.5 times more than amount of cores' do
      allow(OS).to receive(:linux?).and_return(true)
      allow(described_class).to receive(:cpu_load).and_return(12.0)
      allow(described_class).to receive(:cpu_core_amount).and_return(8)

      expect(described_class.wait_cpu_to_idle).to be true
    end

    it 'waits 30 times per 60 secs for the suitable load and raise if it is not' do
      allow(OS).to receive(:linux?).and_return(true)
      allow(described_class).to receive(:cpu_load).and_return(13.0)
      allow(described_class).to receive(:cpu_core_amount).and_return(8)
      subject.should_receive(:sleep).with(60).exactly(30).times

      expect do
        subject.wait_cpu_to_idle
      end.to raise_exception(RuntimeError, "CPU was overloaded. Couldn't start emulator")
    end

    it 'returns true after retry if load became better' do
      allow(OS).to receive(:linux?).and_return(true)
      allow(subject).to receive(:cpu_load).and_return(13.0, 14.0, 12.0)
      allow(subject).to receive(:cpu_core_amount).and_return(8)
      subject.should_receive(:sleep).with(60).twice

      expect(subject.wait_cpu_to_idle).to be true
    end
  end
end
