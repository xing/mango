require 'os'

module Fastlane
  module Helper
    module CpuLoadHandler

      def self.print_cpu_load(load = cpu_load)
        UI.important("CPU load is: #{load}") if load
      end

      # Gets load average of Linux machine
      def self.cpu_load
        load = Actions.sh('cat /proc/loadavg')
        load.split(' ').first.to_f unless load.empty?
      end

      # Gets amount of the CPU cores
      def self.cpu_core_amount
        Actions.sh("cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1")
      end

      # For half an hour waiting until CPU load average is less than number of cores*2 (which considers that CPU is ready)
      # Raises when 30 minutes timeout exceeds
      def self.wait_cpu_to_idle
        if OS.linux?
          30.times do
            load = cpu_load
            return true if load <= cpu_core_amount.to_i * 1.5
            print_cpu_load(load)
            UI.important('Waiting for available resources..')
            sleep 60
          end
        else
          return true
        end
        raise "CPU was overloaded. Couldn't start emulator"
      end

    end
  end
end
