module Fastlane
  module Helper
    module EmulatorLanguage
      def self.set(lang, docker_commander)
        UI.important("Changing device locale to #{lang}")

        language = lang.split('_')[0]
        country = lang.split('_')[1]
        apk_path = File.join(File.dirname(__FILE__), 'settings.apk')
        docker_commander.cp(file: apk_path)
        docker_commander.exec(command: 'adb install /root/tests/settings.apk')
        docker_commander.exec(command: 'adb shell pm grant io.appium.settings android.permission.CHANGE_CONFIGURATION')
        docker_commander.exec(command: "adb shell am broadcast -a io.appium.settings.locale -n io.appium.settings/.receivers.LocaleSettingReceiver --es lang #{language} --es country #{country}")
      end
    end
  end
end
