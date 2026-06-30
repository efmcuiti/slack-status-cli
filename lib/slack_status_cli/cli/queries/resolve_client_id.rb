module SlackStatusCli
  module Cli
    module Queries
      # Resolves the Slack App client_id for a profile, pure (no prompting — that
      # stays in the setup orchestrator). Precedence: profile-level
      # `oauth.client_id` -> global `oauth.client_id` -> ENV
      # `SLACK_STATUS_CLIENT_ID`. The resolved value is passed through
      # ReadSecretRef so a `secret:` reference is expanded transparently.
      class ResolveClientId
        extend Callable

        ENV_VAR = "SLACK_STATUS_CLIENT_ID".freeze

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
          config.dig("profiles", profile, "oauth", "client_id")
        end

        def global_value
          config.dig("global", "oauth", "client_id")
        end
      end
    end
  end
end
