require 'docker'
require 'os'

module Fastlane
  module Helper
    class DockerCommander

      attr_accessor :container_name

      def initialize(container_name)
        @container_name = container_name
      end

      def pull_image(docker_image_name:)
        Actions.sh("docker pull #{docker_image_name}")
      end

      def start_container(emulator_args:, docker_image:)
        docker_name = if container_name
                        "--name #{container_name}"
                      else
                        ''
                      end

        # Action.sh returns all output that the command produced but we are only
        # interested in the last line, since it contains the id of the created container.
        UI.important("Attaching #{ENV['PWD']} to the docker container")
        Actions.sh("docker run -v $PWD:/root/tests --privileged -t -d #{emulator_args} #{docker_name} #{docker_image}").chomp
      end

      def stop_container
        Actions.sh("docker stop #{container_name}") if container_name
      end

      def delete_container
        Actions.sh("docker rm #{container_name}") if container_name
      end

      def disconnect_network_bridge
        Actions.sh("docker network disconnect -f bridge #{container_name}") if container_name
      rescue StandardError
        # Do nothing if the network bridge is already gone
      end

      def docker_exec(command:)
        if container_name
          Actions.sh("docker exec -i #{container_name} bash -l -c \"#{command}\"")
        else
          raise('Cannot execute docker command because the container name is unknown')
        end
      end
        
    end
  end
end
