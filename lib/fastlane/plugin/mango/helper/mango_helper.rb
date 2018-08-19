require 'docker'
require 'timeout'
require 'os'
require 'net/http'

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
        disconnect_network_bridge if container_name

        create_container

        if is_running_on_emulator && kvm_disabled?
          raise 'Linux requires GPU acceleration for running emulators, but KVM virtualization is not supported by your CPU. Exiting..'
        end
        
        begin
          wait_for_healthy_container false
          check_emulator_connection if is_running_on_emulator
        rescue StandardError
          UI.important("Will retry checking for a healthy docker container after #{sleep_interval} seconds")
          @container.stop
          @container.delete(force: true)
          sleep @sleep_interval
          create_container
          wait_for_healthy_container
          check_emulator_connection if is_running_on_emulator
        end
      end

      def kvm_disabled?
        docker_exec('kvm-ok').include?('KVM acceleration can NOT be used')
      end

      # Stops and remove container
      def clean_container
        @container.stop
        @container.delete(force: true)
      end

      # Executes commands inside docker container
      def docker_exec(command)
        Actions.sh("docker exec -i #{container_name} bash -l -c \"#{command}\"")
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

      # Restarts adb on the separate port and checks if created emulator is connected
      def check_emulator_connection
        UI.success('Checking if emulator is connected to ADB.')

        if emulator_is_healthy?
          UI.success('Emulator connected successfully')
        else
          raise "Something went wrong. Newly created device couldn't connect to the adb"
        end

        disable_animations
        increase_logcat_storage
      end

      def emulator_is_healthy?
        list_devices = docker_exec('adb devices')
        list_devices.include? "\tdevice"
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
          `docker stop #{container_name}` if container_name
          `docker rm #{container_name}` if container_name
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

        docker_name = if container_name
                        "--name #{container_name}"
                      else
                        ''
                      end

        emulator_args = is_running_on_emulator ? "-p #{no_vnc_port}:6080 -e DEVICE='#{device_name}'" : ''

        # Action.sh returns all output that the command produced but we are only
        # interested in the last line, since it contains the id of the created container.
        UI.important("Attaching #{ENV['PWD']} to the docker container")
        output = Actions.sh("docker run -v $PWD:/root/tests --privileged -t -d #{emulator_args} #{docker_name} #{docker_image}").chomp
        output.split("\n").last
      end

      def execute_pre_action
        Actions.sh(@pre_action)
      end

      # Pull the docker images before creating a container
      def pull_from_registry
        docker_image_name = docker_image.gsub(':latest', '')
        Actions.sh(@docker_registry_login) if @docker_registry_login
        Actions.sh("docker pull #{docker_image_name}")
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
          `docker stop #{container_name}` if container_name
          `docker rm #{container_name}` if container_name
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
      def wait_for_healthy_container(will_exit = true)
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
        # We use code "2" as we need something than just standard error code 1, so we can differentiate the next step in CI
        exit 2 if will_exit
        raise 'Fail'
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

      # Disables animation for faster and stable testing
      def disable_animations
        docker_exec('adb shell settings put global window_animation_scale 0.0')
        docker_exec('adb shell settings put global transition_animation_scale 0.0')
        docker_exec('adb shell settings put global animator_duration_scale 0.0')
      end

      # Increases logcat storage
      def increase_logcat_storage
        docker_exec('adb logcat -G 16m')
      end

      def disconnect_network_bridge
        `docker network disconnect -f bridge #{container_name}`
      rescue StandardError
        # Do nothing if the network bridge is already gone
      end
    end
  end
end
