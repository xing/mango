require_relative '../helper/docker_commander'

module Fastlane
  module Actions
    class RunDockerizedTaskAction < Action
      def self.run(params)
        UI.important("The mango plugin is working!")
        workspace_dir = params[:workspace_dir]
        ENV['DOCKER_CONFIG'] = "#{ENV['WORKSPACE']}/.docker"
        mango_helper = Fastlane::Helper::MangoHelper.new(params)
        mango_helper.setup_container

        docker_commander = Helper::DockerCommander.new(mango_helper.container_name)

        failure_buffer_timeout = 5
        timeout_command = "timeout #{params[:maximal_run_time] - failure_buffer_timeout}m"

        android_task = params[:android_task]
        if android_task
          UI.success("Starting Android Task.")
          bundle_install = params[:bundle_install] ? '&& bundle install ' : ''

          docker_commander.exec(command: "cd #{workspace_dir} #{bundle_install}&& #{timeout_command} #{android_task} || exit 1")
        end
      ensure
        begin
          post_actions = params[:post_actions]
          if post_actions && !mango_helper.kvm_disabled?
            docker_commander&.exec(command: "cd #{workspace_dir} && #{post_actions}")
          end

          UI.important("Cleaning up #{params[:emulator_name]} container")
          docker_commander.delete_container if mango_helper&.instance_variable_get('@container')
        rescue StandardError => e
          puts e
        end
      end

      def self.description
        "Action that runs Android tasks on a specified Docker image"
      end

      def self.authors
        ["Serghei Moret", "Daniel Hartwich"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.is_supported?(platform)
        platform == :android
      end

      def self.details
        # Optional:
        ""
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :container_name,
                                      env_name: "CONTAINER_NAME",
                                      description: "Name of the docker container. Will be generated randomly if not defined",
                                      optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :no_vnc_port,
                                       env_name: "NO_VNC_PORT",
                                       description: "Port to redirect noVNC. 6080 by default",
                                       default_value: 6080,
                                       optional: false,
                                       type: Integer),

          FastlaneCore::ConfigItem.new(key: :device_name,
                                       env_name: "DEVICE_NAME",
                                       description: "Name of the Android device. Nexus 5X by default",
                                       default_value: 'Nexus 5X',
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :emulator_name,
                                       env_name: "EMULATOR_NAME",
                                       description: "Name of the Android emulator. emulator-5554 by default",
                                       default_value: 'emulator-5554',
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :docker_image,
                                       env_name: "DOCKER_IMAGE",
                                       description: "Name of the Docker image. butomo1989/docker-android-x86-5.1.1 by default",
                                       default_value: 'butomo1989/docker-android-x86-5.1.1',
                                       optional: false,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :container_timeout,
                                      env_name: "CONTAINER_TIMEOUT",
                                      description: "Timeout (in seconds) to get the healthy docker container. 450 (7.5 minutes) by default",
                                      default_value: 450,
                                      optional: false,
                                      type: Integer),

         FastlaneCore::ConfigItem.new(key: :android_task,
                                      env_name: "ANDROID TASK",
                                      description: "A generic Android task you want to execute",
                                      is_string: true,
                                      optional: false),

          FastlaneCore::ConfigItem.new(key: :sdk_path,
                                       env_name: "SDK_PATH",
                                       description: "The path to your Android sdk directory (root). ANDROID_HOME by default",
                                       default_value: ENV['ANDROID_HOME'],
                                       is_string: true,
                                       optional: true),

          FastlaneCore::ConfigItem.new(key: :port_factor,
                                      env_name: "PORT_FACTOR",
                                      description: "Base for calculating a unique port for noVNC. You can pass EXECUTOR_NUMBER from Jenkins for example, this will be unique and not clash in case of several instances running on the same machine",
                                      optional: true,
                                      type: String),

          FastlaneCore::ConfigItem.new(key: :core_amount,
                                       env_name: "CORE_AMOUNT",
                                       default_value: 0,
                                       description: "Define if we want to start docker container with the limitation",
                                       optional: true,
                                       type: Integer),

          FastlaneCore::ConfigItem.new(key: :workspace_dir,
                                       env_name: "WORKSPACE_DIR",
                                       default_value: '/root/tests/',
                                       description: "Path to the workspace to execute commands. If you want to execute your `android_task` from a different directory you have to specify `workspace_dir`",
                                       optional: true,
                                       type: String),

          FastlaneCore::ConfigItem.new(key: :maximal_run_time,
                                       env_name: "MAXIMAL_RUN_TIME",
                                       default_value: 60,
                                       description: "Defines the maximal time of your test run. Defaults to 60 minutes",
                                       optional: true,
                                       type: Integer),

          FastlaneCore::ConfigItem.new(key: :bundle_install,
                                       env_name: "BUNDLE_INSTALL",
                                       default_value: false,
                                       description: "Defines if the Android task must execute bundle install before running a build",
                                       optional: true,
                                       type: Boolean),

          FastlaneCore::ConfigItem.new(key: :is_running_on_emulator,
                                       env_name: "IS_RUNNING_ON_EMULATOR",
                                       default_value: true,
                                       description: "Define if we want to run the emulator in the container",
                                       optional: true,
                                       type: Boolean),

          FastlaneCore::ConfigItem.new(key: :post_actions,
                                      env_name: "POST_ACTIONS",
                                      description: "Actions that will be executed after the main command has been executed",
                                      is_string: true,
                                      optional: true),

          FastlaneCore::ConfigItem.new(key: :pre_action,
                                      env_name: "PRE_ACTION",
                                      description: "Actions that will be executed before the docker image gets pulled",
                                      is_string: true,
                                      optional: true),

          FastlaneCore::ConfigItem.new(key: :docker_registry_login,
                                      env_name: "DOCKER_REGISTRY_LOGIN",
                                      description: "Authenticating yourself to a custom Docker registry",
                                      type: String,
                                      optional: true),

          FastlaneCore::ConfigItem.new(key: :pull_latest_image,
                                      env_name: "PULL_LATEST_IMAGE",
                                      description: "Define if you want to pull the latest image",
                                      type: Boolean,
                                      default_value: false,
                                      optional: true),

          FastlaneCore::ConfigItem.new(key: :environment_variables,
                                      env_name: "ENVIRONMENT_VARIABLES",
                                      description: "Comma seperated list of environment variables which are passed into the docker container",
                                      type: Array,
                                      default_value: [],
                                      optional: true),

          FastlaneCore::ConfigItem.new(key: :vnc_enabled,
                                       env_name: "VNC_ENABLED",
                                       description: "A bool. True for vnc_enabled False for vnc_disabled",
                                       type: Boolean,
                                       default_value: true,
                                       optional: true)
        ]
      end
    end
  end
end
