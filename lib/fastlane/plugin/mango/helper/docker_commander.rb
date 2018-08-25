require 'docker'
require 'os'

module Fastlane
  module Helper
    module DockerCommander

      def self.pull_image(docker_image_name:)
        handle_thin_pool_exception do
          Actions.sh("docker pull #{docker_image_name}")
        end
      end

      def self.start_container(emulator_args:, docker_name:, docker_image:)
        docker_name = if docker_name
                        "--name #{docker_name}"
                      else
                        ''
                      end

        # Action.sh returns all output that the command produced but we are only
        # interested in the last line, since it contains the id of the created container.
        UI.important("Attaching #{ENV['PWD']} to the docker container")
        handle_thin_pool_exception do
          Actions.sh("docker run -v $PWD:/root/tests --privileged -t -d #{emulator_args} #{docker_name} #{docker_image}").chomp
        end
      end

      def self.stop_container(container_name:)
        Actions.sh("docker stop #{container_name}") if container_name
      end

      def self.delete_container(container_name:)
        Actions.sh("docker rm #{container_name}") if container_name
      end

      def self.disconnect_network_bridge(container_name: container_name)
        Actions.sh("docker network disconnect -f bridge #{container_name}") if container_name
      rescue StandardError
        # Do nothing if the network bridge is already gone
      end

      def self.prune
        Action.sh('docker system prune -f')
      end

      def self.handle_thin_pool_exception(&block)
        begin
          block.call
        rescue => exception
          if exception.message =~ /Create more free space in thin pool/
            prune
            retry
          else
            raise exception
          end
        end
      end
    end
  end
end