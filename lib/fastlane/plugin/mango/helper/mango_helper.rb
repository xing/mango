require 'docker'
require 'timeout'
require 'os'
require 'net/http'
require_relative 'docker_commander'
require_relative 'emulator_commander'

module Fastlane
  module Helper
    class MangoHelper
      attr_reader :container_name, :no_vnc_port, :device_name, :docker_image, :timeout, :port_factor, :maximal_run_time, :sleep_interval, :is_running_on_emulator

      def initialize(params)
        @container_name = params[:container_name]
        @no_vnc_port = params[:no_vnc_port]
        @device_name = params[:device_name]
        @docker_image = params[:docker_image]
        @timeout = params[:container_timeout]
        @sdk_path = params[:sdk_path]
        @port_factor = params[:port_factor].to_i
        @maximal_run_time = params[:maximal_run_time]
        @sleep_interval = 5
        @container = nil
        @adb_path = adb_path
        @is_running_on_emulator = params[:is_running_on_emulator]
        @pre_action = params[:pre_action]
        @docker_registry_login = params[:docker_registry_login]
        @pull_latest_image = params[:pull_latest_image]
      end

      # Setting up the container:
      # 1. Checks if ports are already allocated and kill the ones that do
      # 2. Checks if Container we want to create already exist. If it does, restart it and check that the ports are correct
      # 3. Creates container if there wasn't one already created or the created one has incorrect ports
      # 4. Finally, waits until container is up and running (Healthy) using timeout specified in params
      def setup_container
        assign_unique_vnc_port if port_factor && is_running_on_emulator

        if container_available?
          @container.stop
          @container.delete(force: true)
        end

        handle_ports_allocation if is_running_on_emulator

        execute_pre_action if @pre_action

        pull_from_registry if @pull_latest_image

        # Make sure that network bridge for the current container is not already used
        DockerCommander.disconnect_network_bridge(container_name: container_name)

        create_container

        if is_running_on_emulator && kvm_disabled?
          raise 'Linux requires GPU acceleration for running emulators, but KVM virtualization is not supported by your CPU. Exiting..'
        end

        container_state = wait_for_healthy_container

        if is_running_on_emulator
          connection_state = EmulatorCommander.check_connection(container_name: container_name)
          container_state = connection_state && connection_state
        end

        unless container_state
          UI.important("Will retry checking for a healthy docker container after #{sleep_interval} seconds")
          @container.stop
          @container.delete(force: true)
          sleep @sleep_interval
          create_container

          unless wait_for_healthy_container
            UI.important('Container is unhealthy. Exiting..')
            # We use code "2" as we need something than just standard error code 1, so we can differentiate the next step in CI
            exit 2
          end

          if is_running_on_emulator && !EmulatorCommander.check_connection(container_name: container_name)
            UI.important('Cannot connect to emulator. Exiting..')
            exit 2
          end
        end

        if is_running_on_emulator
          EmulatorCommander.disable_animations(container_name: container_name)
          EmulatorCommander.increase_logcat_storage(container_name: container_name)
        end
      end

      def kvm_disabled?
        begin
          DockerCommander.docker_exec(command: 'kvm-ok > kvm-ok.txt', container_name: container_name)
        rescue StandardError
          # kvm-ok will always throw regardless of the result. therefore we save the output in the file and ignore the error
        end
        DockerCommander.docker_exec(command: 'cat kvm-ok.txt', container_name: container_name).include?('KVM acceleration can NOT be used')
      end

      # Stops and remove container
      def clean_container
        @container.stop
        @container.delete(force: true)
      end

      private

      # Sets path to adb
      def adb_path
        "#{@sdk_path}/platform-tools/adb"
      end

      # assigns vnc port
      def assign_unique_vnc_port
        @no_vnc_port = 6080 + port_factor
        @host_ip_address = `hostname -I | head -n1 | awk '{print $1;}'`.delete!("\n")
        UI.success("Port: #{@no_vnc_port} was chosen for VNC")
        UI.success("Link to VNC: http://#{@host_ip_address}:#{@no_vnc_port}")
      end

      # Creates new container using params
      def create_container
        UI.important("Creating container: #{container_name}")
        print_cpu_load
        begin
          container = create_container_call
          @container_name = container unless container_name
        rescue StandardError
          UI.important("Something went wrong while creating: #{container_name}, will retry in #{@sleep_interval} seconds")
          print_cpu_load
          DockerCommander.stop_container(container_name: container_name)
          DockerCommander.delete_container(container_name: container_name)
          sleep @sleep_interval
          container = create_container_call
          @container_name = container unless container_name
        end
        get_container_instance(container)
      end

      # Gets container instance by container ID
      def get_container_instance(container)
        Docker::Container.all(all: true).each do |cont|
          if cont.id == container
            @container = cont
            break
          end
        end
      end

      # Call to create a container. We don't use Docker API here, as it doesn't support --privileged.
      def create_container_call
        # When CPU is under load we cannot create a healthy container
        wait_cpu_to_idle

        emulator_args = is_running_on_emulator ? "-p #{no_vnc_port}:6080 -e DEVICE='#{device_name}'" : ''

        DockerCommander.start_container(emulator_args: emulator_args, docker_name: container_name, docker_image: docker_image)
      end

      def execute_pre_action
        Actions.sh(@pre_action)
      end

      # Pull the docker images before creating a container
      def pull_from_registry
        docker_image_name = docker_image.gsub(':latest', '')
        Actions.sh(@docker_registry_login) if @docker_registry_login
        DockerCommander.pull_image(docker_image_name: docker_image_name)
      end

      # Checks that chosen ports are not already allocated. If they are, it will stop the allocated container
      def handle_ports_allocation
        vnc_allocated_container = container_of_allocated_port(no_vnc_port)
        if vnc_allocated_container
          UI.important("Port: #{no_vnc_port} was already allocated. Stopping Container.")
          vnc_allocated_container.stop
        end

        if port_open?('0.0.0.0', @no_vnc_port)
          UI.important('Something went wrong. VNC port is still busy')
          sleep @sleep_interval
          DockerCommander.stop_container(container_name: container_name)
          DockerCommander.delete_container(container_name: container_name)
        end
      end

      # Gets container instance of allocated port
      def container_of_allocated_port(port)
        Docker::Container.all.each do |container|
          public_ports = container.info['Ports'].map { |public_port| public_port['PublicPort'] }
          return container if public_ports.include? port
        end
        nil
      end

      def print_cpu_load(load = cpu_load)
        UI.important("CPU load is: #{load}")
      end

      # Checks if container is already available
      def container_available?
        return false unless container_name
        all_containers = Docker::Container.all(all: true)

        all_containers.each do |container|
          if container.info['Names'].first[1..-1] == container_name
            @container = container
            return true
          end
        end
        false
      end

      # Checks if container status is 'healthy'
      def container_is_healthy?
        if @container.json['State']['Health']
          @container.json['State']['Health']['Status'] == 'healthy'
        else
          @container.json['State']['Status'] == 'running'
        end
      end

      # Waits until container is healthy using specified timeout
      def wait_for_healthy_container
        UI.important('Waiting for Container to be in the Healthy state.')

        number_of_tries = timeout / sleep_interval
        number_of_tries.times do
          sleep sleep_interval / 2
          if container_is_healthy?
            UI.success('Your container is ready to work')
            return true
          end

          if @container.json['State']['Health']
            UI.important("Container status: #{@container.json['State']['Health']['Status']}")
          else
            UI.important("Container status: #{@container.json['State']['Status']}")
          end

          sleep sleep_interval
        end
        UI.important("The Container failed to load after '#{timeout}' seconds timeout. Reason: '#{@container.json['State']['Status']}'")
        false
      end

      # Checks if port is already openZ
      def port_open?(server, port)
        http = Net::HTTP.start(server, port, open_timeout: 5, read_timeout: 5)
        response = http.head('/')
        response.code == '200'
      rescue Timeout::Error, SocketError, Errno::ECONNREFUSED
        false
      end

      # Gets load average of Linux machine
      def cpu_load
        load = `cat /proc/loadavg`
        load.split(' ').first.to_f
      end

      # Gets amount of the CPU cores
      def cpu_core_amount
        `cat /proc/cpuinfo | awk '/^processor/{print $3}' | tail -1`
      end

      # For half an hour waiting until CPU load average is less than number of cores*2 (which considers that CPU is ready)
      # Raises when 30 minutes timeout exceeds
      def wait_cpu_to_idle
        if OS.linux?
          30.times do
            load = cpu_load
            return true if load < cpu_core_amount.to_i * 1.5
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
