
# Mango - Fastlane plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-mango) [![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/xing/mango/blob/master/LICENSE)
[![Gem](https://img.shields.io/gem/v/fastlane-plugin-mango.svg?style=flat)](http://rubygems.org/gems/fastlane-plugin-mango)

A fastlane plugin that runs Android tasks on a specified [Docker](https://www.docker.com/) image. Can be used for orchestrating android tasks on a CI syste.

<img src="assets/mango_logo.png" alt="Mango Logo" width="256px" height="256px"/>

Running Android tests, especially [Espresso](https://developer.android.com/training/testing/espresso/) on a continuous integration environment like [Jenkins](https://jenkins.io/) can be a hassle. You need to boot, manage and destroy an [Android Virtual Device (AVD)](https://developer.android.com/studio/run/managing-avds) during the test run. This is why we, the mobile releases team at [XING](https://www.xing.com), built this plugin. It spins up a specified [Docker](https://www.docker.com/) image and runs a given task on it.

Another requirement we had was to run on a clean environment, which is why Mango also helps us to run our unit test and more. For an example check out the [example `Fastfile`](sample-android/fastlane/Fastfile)

## Prerequisites

In order to use this plugin you will need to to have [Docker](https://www.docker.com/) installed on the machine you are using.
Documentation on how to set it up properly on a Linux (ubuntu) machine can be found [here](docs/docker-linux.md).

If you need an Android Virtual Device (AVD) to run your tests (for example Espresso, Calabash or Appium), it's necessary to check that your CPU supports kvm virtualisation. We already experienced that it doesn't fully work on macOS and are using Linux for that.

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-mango`, add it to your project by running:

```bash
fastlane add_plugin mango
```

## Usage

After installing this plugin you have access to one additional action (`mango`) in your `Fastfile`.

So a lane in your `Fastfile` could look similar to this for Espresso tests:
```ruby
desc "Run espresso tests on docker images"
  lane :Espresso_Tests do
     run_dockerized_task(
       container_name: "espresso_container",
       port_factor: options[:port_factor],
       docker_image: "joesss/mango-docker:latest",
       container_timeout: 120,
       android_task: "./gradlew connectedAndroidTest",
       post_actions: "adb logcat -d > logcat.txt",
       pull_latest_image: true          
     )
   end
```

or to this for unit tests or other gradle tasks(some of the variables are optional):
```ruby
desc "Run unit tests on docker images"
  lane :example do
    run_dockerized_task(
      container_name: "emulator_#{options[:port_factor]}",
      port_factor: options[:port_factor],
      docker_image: 'joesss/mango-base:latest',
      android_task: './gradlew testDebug',
      post_actions: 'adb logcat -d > logcat.txt',
      bundle_install: true,
      core_amount: '8',
      workspace_dir: '/root/tests/espresso-tests',
      docker_registry_login: "docker login -u='USER' -p='PASS' some.docker.com",
      pull_latest_image: true,
      pre_action: 'echo $GIT_BRANCH > /root/.branch',
      vnc_enabled: false,
      environment_variables: options[:environment_variables] ? options[:environment_variables].split(' ') : ''
    )
  end
```

Now you can call this new lane by calling `bundle exec fastlane Espresso_Tests`.

The Plugin will start up the given `docker_image`, execute the given `android_task` and afterwards execute the `post_actions`.

## Configuration options
The `mango` action has plenty of options to configure it.

| Option | Description | Default value | Optional | Type |
| - |:-|-:| :-:| -:|
| `container_name`| Name of the docker container. Will be generated randomly if not defined. | - | ✅ | `String` |
| `no_vnc_port` | Port to redirect noVNC. To observe your docker container from your browser while it's running. | 6080 | ❌ | `Integer` |
| `device_name` | Name of the Android device. | Nexus 5X | ❌ | `String` |
| `emulator_name`| Name of the Android emulator. | emulator-5554 | ❌ | `String` |
| `docker_image` | Name of the Docker image, that should be started and used to run your tasks. | butomo1989/docker-android-x86-5.1.1 | ❌ | `String` |
| `container_timeout` | Timeout (in seconds) to get a healthy docker container. Depending on your `docker_image` it may take some time until it's started up and ready to use. | 450 (this equals 7.5 minutes) | ❌ | `Integer` |
| `android_task` | A generic Android task you want to execute. | - | ❌ | `String` |
| `core_amount` | Cpu core amount while starting docker container with limited resource. | - | ✅ | `Integer` |
| `sdk_path` | The path to your Android sdk directory. | `ANDROID_HOME` environment variable | ✅ | `String` |
| `port_factor` | Base for calculating a unique port for noVNC. We recommend to use the `EXECUTOR_NUMBER` from your Jenkins environment. | - | ✅ | `String` |
| `workspace_dir` | Path to the workspace to execute commands. If you want to execute your `android_task` from a different directory you have to specify `workspace_dir`. | `/root/tests/` | ✅ | `String` |
| `maximal_run_time` | Defines the maximal time of your test run in minutes. This can be helpful if you want to kill hanging processes automatically after a certain time. | 60 | ✅ | `Integer` |
| `bundle_install` | Defines if the Android task must execute `bundle install` before running a build. This is useful if you want to execute non-gradle tasks. Like [Calabash](https://github.com/calabash/calabash-android), where you need to update/install your [Ruby](https://www.ruby-lang.org) dependencies. | `true` | ✅ | `Boolean` |
| `is_running_on_emulator` | Define if container boots up an emulator instance inside of it. This will trigger configuration of noVNC, assign necessary ports etc. | `true` | ✅ | `Boolean` |
| `post_actions` | Actions that will be executed after the main command has been executed. | - | ✅ | `String` |
| `pre_action` | Actions that will be executed before the docker image gets pulled | - | ✅ | `String` |
| `docker_registry_login` | Command to authenticate yourself in a custom Docker registry | - | ✅ | `String` |
| `pull_latest_image` | Defines if you want to pull the `:latest` tag of the given `docker_image` | `false` | ✅ | `Boolean` |

## Contributing

🎁 Bug reports and pull requests for new features are most welcome!

👷🏼 We are looking forward to your pull request, we'd love to help!

You can help by doing any of the following:

- Reviewing pull requests
- Bringing ideas for new features
- Answering questions on issues
- Improving documentation

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant code](http://contributor-covenant.org/) of conduct.

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## License

The fastlane plugin is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Example

Check out the [example `Fastfile`](sample-android/fastlane/Fastfile) to see how to use this plugin.
Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

## Run tests for this plugin

To run both the tests and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
