require 'spec_helper'

describe Fastlane::Helper::DockerCommander do
  before do
      @docker_commander = Fastlane::Helper::DockerCommander
  end

  describe '#pull_image' do
    it 'pulls the image' do
      expect(Fastlane::Actions).to receive(:sh).with('docker pull bla')
      @docker_commander.pull_image(docker_image_name: "bla")
    end
  end

  describe '#stop_container' do
    it 'stops the container if the container name is available' do
        expect(Fastlane::Actions).to receive(:sh).with('docker stop abcdef123')
        @docker_commander.stop_container(container_name: "abcdef123")
    end

    it 'doesnt stop the container if no container name is available' do
      expect(Fastlane::Actions).not_to receive(:sh)
      @docker_commander.stop_container(container_name: nil)
    end
  end

  describe '#delete_container' do
    it 'deletes the container if the container name is available' do
        expect(Fastlane::Actions).to receive(:sh).with('docker rm abcdef123')
        @docker_commander.delete_container(container_name: "abcdef123")
    end

    it 'doesnt delete the container if no container name is available' do
      expect(Fastlane::Actions).not_to receive(:sh)
      @docker_commander.delete_container(container_name: nil)
    end
  end

  describe '#disconnect_network_bridge' do
    it 'disconnects the network_bridge if the container name is available' do
        expect(Fastlane::Actions).to receive(:sh).with('docker network disconnect -f bridge abcdef123')
        @docker_commander.disconnect_network_bridge(container_name: "abcdef123")
    end

    it 'doesnt disconnect the network_bridge if no container name is available' do
      expect(Fastlane::Actions).not_to receive(:sh)
      @docker_commander.disconnect_network_bridge(container_name: nil)
    end
  end

  describe '#start_container' do
    it 'starts the container with a specified name' do
      expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests --privileged -t -d  --name my-test-image test-image').and_return("abdef\n")
      container_id = @docker_commander.start_container(emulator_args: nil, docker_name: "my-test-image", docker_image: "test-image")
      expect(container_id).to eql "abdef"
    end

    it 'starts the container without the name parameter' do
      expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests --privileged -t -d   test-image').and_return("abd\n")
      container_id = @docker_commander.start_container(emulator_args: nil, docker_name: nil, docker_image: "test-image")
      expect(container_id).to eql "abd"
    end
  end

end
