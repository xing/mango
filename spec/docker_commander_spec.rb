require 'spec_helper'

describe Fastlane::Helper::DockerCommander do
  subject(:docker_commander) { Fastlane::Helper::DockerCommander.new(container_name) }

  describe '#pull_image' do
    let(:container_name) { 'abcdef123' }

    it 'pulls the image' do
      expect(Fastlane::Actions).to receive(:sh).with('docker pull bla')
      docker_commander.pull_image(docker_image_name: 'bla')
    end
  end

  describe '#delete_container' do
    context 'when container name is set' do
      let(:container_name) { 'abcdef123' }

      it 'deletes the container if the container name is available' do
        expect(Fastlane::Actions).to receive(:sh).with('docker rm -f abcdef123')
        docker_commander.delete_container
      end
    end

    context 'when container name is nil' do
      let(:container_name) { nil }

      it 'doesnt delete the container if no container name is available' do
        expect(Fastlane::Actions).not_to receive(:sh)
        docker_commander.delete_container
      end
    end
  end

  describe '#disconnect_network_bridge' do
    context 'when container name is set' do
      let(:container_name) { 'abcdef123' }

      it 'disconnects the network_bridge if the container name is available' do
        expect(Fastlane::Actions).to receive(:sh).with('docker network disconnect -f bridge abcdef123')
        docker_commander.disconnect_network_bridge
      end
    end
    context 'when container name is nil' do
      let(:container_name) { nil }
      it 'doesnt disconnect the network_bridge if no container name is available' do
        expect(Fastlane::Actions).not_to receive(:sh)
        docker_commander.disconnect_network_bridge
      end
    end
  end

  describe '#start_container' do
    context 'when container name is set' do
      let(:container_name) { 'abcdef123' }

      it 'starts the container with a specified name' do
        expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests  --privileged -t -d   --name abcdef123 test-image').and_return("abdef\n")
        container_id = docker_commander.start_container(emulator_args: nil, docker_image: 'test-image', core_amount: nil, docker_with_user: nil)
        expect(container_id).to eql 'abdef'
      end
    end
    context 'when container name is nil' do
      let(:container_name) { nil }
      it 'starts the container without the name parameter' do
        expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests  --privileged -t -d    test-image').and_return("abd\n")
        container_id = docker_commander.start_container(emulator_args: nil, docker_image: 'test-image', core_amount: nil, docker_with_user: nil)
        expect(container_id).to eql 'abd'
      end
    end

    context 'when cpu usage is limited' do
      let(:container_name) { '123' }
      let(:core_amount) { '8' }
      it 'starts the container with the limitation for cpu usage' do
        expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests  --privileged -t -d --cpus=8  --name 123 test-image').and_return("abd\n")
        container_id = docker_commander.start_container(emulator_args: nil, docker_image: 'test-image', core_amount: 8, docker_with_user: nil)
        expect(container_id).to eql 'abd'
      end
    end

    context 'when cpu usage is limitless' do
      let(:container_name) { '123' }
      let(:core_amount) { nil }
      it 'starts the container without limitation' do
        expect(Fastlane::Actions).to receive(:sh).with('docker run -v $PWD:/root/tests  --privileged -t -d   --name 123 test-image').and_return("abd\n")
        container_id = docker_commander.start_container(emulator_args: nil, docker_image: 'test-image', core_amount: nil, docker_with_user: nil)
        expect(container_id).to eql 'abd'
      end
    end
  end

  describe '#docker_exec' do
    context 'when container name is set' do
      let(:container_name) { 'abcdef123' }

      it 'executes commands inside docker if container name is specified' do
        expect(Fastlane::Actions).to receive(:sh).with('docker exec -i abcdef123 bash -l -c "do stuff"')
        docker_commander.exec(command: 'do stuff')
      end
    end
    context 'when container name is nil' do
      let(:container_name) { nil }

      it 'raises if the container name is not specified' do
        expect(Fastlane::Actions).not_to receive(:sh)
        expect do
          docker_commander.exec(command: 'do stuff')
        end.to raise_exception('Cannot execute docker command because the container name is unknown')
      end
    end
  end
end
