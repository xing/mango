require 'spec_helper'

describe Fastlane::Helper::EmulatorCommander do

  subject(:emulator_commander) { Fastlane::Helper::EmulatorCommander.new('a_name')  }

  describe '#disable_animations' do
    it 'disables emulator animation' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global window_animation_scale 0.0\"")
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global transition_animation_scale 0.0\"")
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb shell settings put global animator_duration_scale 0.0\"")

      emulator_commander.disable_animations
    end
  end

  describe '#increase_logcat_storage' do
    it 'increases_logcat_storage' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb logcat -G 16m\"")
      emulator_commander.increase_logcat_storage
    end
  end

  describe '#emulator_is_healthy?' do
    it 'returns true if emulator is healthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tdevice")
      expect(emulator_commander.emulator_is_healthy?).to be true
    end

    it 'returns false if emulator is unhealthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tunauthorized")
      expect(emulator_commander.emulator_is_healthy?).to be false
    end
  end

  describe '#check_connection' do
    it 'returns false if simulator is unhealthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tunauthorized")
      expect(emulator_commander.check_connection).to be false
    end

    it 'returns true if simulator is healthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tdevice")
      expect(emulator_commander.check_connection).to be true
    end

    it 'prints a success message if simulator is healthy' do
      expect(Fastlane::Actions).to receive(:sh).with("docker exec -i a_name bash -l -c \"adb devices\"").and_return("emulator_5554 \tdevice")
      expect(Fastlane::UI).to receive(:success).with('Checking if emulator is connected to ADB.')
      expect(Fastlane::UI).to receive(:success).with('Emulator connected successfully')
      emulator_commander.check_connection
    end
  end
end
