describe Fastlane::Actions::EmulatorDockerAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The emulator_docker plugin is working!")
      Fastlane::Actions::EmulatorDockerAction.run(nil)
    end
  end
end
