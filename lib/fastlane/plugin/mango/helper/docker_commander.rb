require 'docker'
require 'os'

module Fastlane
  module Helper
    class DockerCommander

      def initialize
      end

      def pull_image(docker_image_name:)
        Actions.sh("docker pull #{docker_image_name}")
      end

      def start_container(emulator_args:, docker_name:, docker_image:)
        docker_name = if docker_name
                        "--name #{docker_name}"
                      else
                        ''
                      end

        # Action.sh returns all output that the command produced but we are only
        # interested in the last line, since it contains the id of the created container.
        UI.important("Attaching #{ENV['PWD']} to the docker container")
        output = Actions.sh("docker run -v $PWD:/root/tests --privileged -t -d #{emulator_args} #{docker_name} #{docker_image}").chomp
        output.split("\n").last
      end

      def stop_container(container_name:)
        `docker stop #{container_name}` if container_name
      end

      def delete_container(container_name:)
        `docker rm #{container_name}` if container_name
      end

      private

      # Executes commands inside docker container
      def docker_exec(command)
        Actions.sh("docker exec -i #{container_name} bash -l -c \"#{command}\"")
      end

    end
  end
end
