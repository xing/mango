module Fastlane
  module Helper
    module EmulatorLanguage
      def self.set(lang)
        UI.important("Running tests in #{lang}")
        current_locale = Actions.sh('adb shell getprop persist.sys.locale').strip&.gsub('-', '_')

        if current_locale.eql? lang
          UI.important("Current device locale is already #{lang}")
        else
          UI.important("Changing device locale to #{lang}")
          api = Actions.sh('adb shell getprop ro.build.version.sdk').to_i
          if api < 28
            Actions.sh("adb shell am broadcast -a com.android.intent.action.SET_LOCALE --es com.android.intent.extra.LOCALE \"#{lang}\" com.android.customlocale2")
          else
            # On API levels higher than 27 we need to use the appium settings app to set system settings like the locale
            UI.important('Using Appium Settings to set the device locale!')
            language = lang.split('_')[0]
            country = lang.split('_')[1]
            Actions.sh('adb install ../settings_apk/settings_apk-debug.apk')
            Actions.sh('adb shell pm grant io.appium.settings android.permission.CHANGE_CONFIGURATION')
            Actions.sh("adb shell am broadcast -a io.appium.settings.locale -n io.appium.settings/.receivers.LocaleSettingReceiver --es lang #{language} --es country #{country}")
          end
        end
      end
    end
  end
end
