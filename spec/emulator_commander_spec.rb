require 'spec_helper'

describe Fastlane::Helper::EmulatorCommander do
  before do
    @emulator_commander = Fastlane::Helper::EmulatorCommander
  end

  describe '#disable_animations' do
    it 'disables emulator animation' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global window_animation_scale 0.0\"")
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global transition_animation_scale 0.0\"")
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global animator_duration_scale 0.0\"")

      @emulator_commander.disable_animations(container_name: 'a_name')
    end
  end

  describe '#increase_logcat_storage' do
    it 'increases_logcat_storage' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb logcat -G 16m\"")
      @emulator_commander.increase_logcat_storage(container_name: 'a_name')
    end
  end

  describe '#emulator_is_healthy?' do
    it 'returns true if emulator is healthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tdevice")
      expect(@emulator_commander.emulator_is_healthy?(container_name: 'a_name')).to be true
    end

    it 'returns false if emulator is unhealthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tunauthorized")
      expect(@emulator_commander.emulator_is_healthy?(container_name: 'a_name')).to be false
    end
  end

  describe '#check_emulator_connection' do
    it 'raises if simulator is unhealthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i some_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tunauthorized")
      expect {
        @emulator_commander.check_emulator_connection(container_name: 'some_name')
      }.to raise_exception(RuntimeError, "Something went wrong. Newly created device couldn't connect to the adb")
    end

    it 'prints a success message if simulator is healthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i some_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tdevice")
      expect(Fastlane::UI).to receive(:success).with('Checking if emulator is connected to ADB.')
      expect(Fastlane::UI).to receive(:success).with('Emulator connected successfully')
      @emulator_commander.check_emulator_connection(container_name: 'some_name')
    end
  end
end
