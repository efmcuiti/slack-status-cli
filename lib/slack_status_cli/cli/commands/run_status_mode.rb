module SlackStatusCli
  module Cli
    module Commands
      # Orchestrates the default status-setting path: resolves a token, installs
      # the Ctrl-C/TERM cleanup handlers, then hands off to Slack's UpdateStatus
      # for the chosen mode. No command at all defaults to :myth; an unrecognized
      # command is intentionally NOT an error — UpdateStatus treats it as a custom
      # freeform status built from the positional args. A token that won't resolve
      # raises a Cli pod Error rather than calling exit.
      class RunStatusMode
        extend Callable

        DEFAULT_PROFILE = "default".freeze
        DEFAULT_MODE = :myth
        NO_ARG_MODE = :musical_myth

        def initialize(
          command:,
          args: [],
          options: {},
          output: $stdout,
          env: ENV,
          resolver: Tokens::Queries::ResolveToken,
          signal_installer: InstallSignalHandlers,
          updater: Slack::Commands::UpdateStatus,
          telemetry: Queries::ResolveTelemetry.call
        )
          @command = command
          @args = args || []
          @options = options || {}
          @output = output
          @env = env
          @resolver = resolver
          @signal_installer = signal_installer
          @updater = updater
          @telemetry = telemetry
        end

        def call
          token = resolve
          signal_installer.call(token: token)
          updater.call(token: token, mode: mode, text: text, emoji: emoji, expiration: expiration, telemetry: telemetry)
        end

        private

        attr_reader :command, :args, :options, :output, :env, :resolver, :signal_installer, :updater, :telemetry

        def mode
          command&.to_sym || DEFAULT_MODE
        end

        # The musical loop derives its own text/emoji/expiration each tick, so any
        # positional args are intentionally ignored for that mode.
        def text
          args[0] unless mode == NO_ARG_MODE
        end

        def emoji
          args[1] unless mode == NO_ARG_MODE
        end

        def expiration
          args[2] unless mode == NO_ARG_MODE
        end

        def resolve
          resolver.call(
            profile: profile,
            cli_token: options[:token],
            config_path: options[:config_path],
            verbose: options[:verbose],
          )[:token]
        rescue Tokens::Errors::NotFoundError => e
          raise Errors::Error, "Could not resolve a Slack token for profile '#{profile}'. #{e.message}"
        end

        def profile
          options[:profile] || env["SLACK_STATUS_PROFILE"] || DEFAULT_PROFILE
        end
      end
    end
  end
end
