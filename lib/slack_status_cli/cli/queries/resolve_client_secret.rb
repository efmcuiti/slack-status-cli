module SlackStatusCli
  module Cli
    module Queries
      # Resolves the Slack App client_secret for a profile, pure (no prompting).
      # Mirrors ResolveClientId's precedence but reads the `oauth.client_secret_ref`
      # key: profile-level -> global -> ENV `SLACK_STATUS_CLIENT_SECRET`. The
      # resolved reference is expanded through ReadSecretRef.
      class ResolveClientSecret
        extend Callable

        ENV_VAR = "SLACK_STATUS_CLIENT_SECRET".freeze

        def initialize(config:, profile:, env: ENV)
          @config = config
          @profile = profile
          @env = env
        end

        def call
          raw = profile_value || global_value || env[ENV_VAR]
          return nil if raw.nil?

          ReadSecretRef.call(value: raw, env: env)
        end

        private

        attr_reader :config, :profile, :env

        def profile_value
          config.dig("profiles", profile, "oauth", "client_secret_ref")
        end

        def global_value
          config.dig("global", "oauth", "client_secret_ref")
        end
      end
    end
  end
end
