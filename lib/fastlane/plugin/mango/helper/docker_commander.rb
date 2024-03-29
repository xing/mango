require 'docker'

module Fastlane
  module Helper
    class DockerCommander
      attr_accessor :container_name

      def initialize(container_name)
        @container_name = container_name
      end

      def pull_image(docker_image_name:)
        Actions.sh("docker pull #{docker_image_name}")
      rescue StandardError => e
        prune if e.message =~ /Create more free space in thin pool/
        Actions.sh("docker pull #{docker_image_name}")
      end

      def start_container(emulator_args:, docker_image:, core_amount:)
        retries ||= 0
        docker_name = if container_name
                        "--name #{container_name}"
                      else
                        ''
                      end
        # if core_amount value is defined then limit the container while starting
        core_amount = if core_amount && core_amount > 0
                        "--cpus=#{core_amount}"
                      else
                        ''
                      end

        # Action.sh returns all output that the command produced but we are only
        # interested in the last line, since it contains the id of the created container.
        UI.important("Attaching #{ENV['PWD']} to the docker container")
        Actions.sh("docker run -v $PWD:/root/tests --privileged -t -d #{core_amount} #{emulator_args} #{docker_name} #{docker_image}").chomp
      rescue StandardError => e
        if e.message =~ /Create more free space in thin pool/ && (retries += 1) < 2
          prune
          retry
        end
      end

      def delete_container
        Actions.sh("docker rm -f #{container_name}") if container_name
      rescue StandardError
        sleep 5
        UI.important('Was not able to delete the container after the first attempt, trying again')
        retry
      end

      def disconnect_network_bridge
        UI.important('Disconnecting from the network bridge')
        Actions.sh("docker network disconnect -f bridge #{container_name}") if container_name
      rescue StandardError
        # Do nothing if the network bridge is already gone
      end

      def exec(command:, raise_when_fail: true)
        if container_name
          begin
            Actions.sh("docker exec #{container_name} bash -l -c \"#{command}\"")
          rescue StandardError => e
            raise(e) if raise_when_fail
          end
        else
          raise('Cannot execute docker command because the container name is unknown')
        end
      end

      def cp(file:)
        Actions.sh("docker cp #{file} #{container_name}:/root/tests/.")
      end

      def prune
        Action.sh('docker system prune -f')
      end
    end
  end
end
