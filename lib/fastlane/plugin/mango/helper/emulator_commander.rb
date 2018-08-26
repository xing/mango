require_relative 'docker_commander'

module Fastlane
  module Helper
    class EmulatorCommander

      attr_accessor :container_name

      def initialize(container_name)
        @container_name = container_name
      end

      # Disables animation for faster and stable testing
      def disable_animations
        DockerCommander.docker_exec(command: 'adb shell settings put global window_animation_scale 0.0', container_name: container_name)
        DockerCommander.docker_exec(command: 'adb shell settings put global transition_animation_scale 0.0', container_name: container_name)
        DockerCommander.docker_exec(command: 'adb shell settings put global animator_duration_scale 0.0', container_name: container_name)
      end

      # Increases logcat storage
      def increase_logcat_storage
        DockerCommander.docker_exec(command: 'adb logcat -G 16m', container_name: container_name)
      end

      # Restarts adb on the separate port and checks if created emulator is connected
      def check_emulator_connection
        UI.success('Checking if emulator is connected to ADB.')

        if emulator_is_healthy?
          UI.success('Emulator connected successfully')
        else
          raise "Something went wrong. Newly created device couldn't connect to the adb"
        end
      end

      def emulator_is_healthy?
        list_devices = DockerCommander.docker_exec(command: 'adb devices', container_name: container_name)
        list_devices.include? "\tdevice"
      end
    end
  end
end