module SlackStatusCli
  module Cli
    module Queries
      # Resolves the storage backend for a profile, pure (no prompting). A
      # config value always beats the ENV override; nothing configured falls back
      # to :file, the safest local-only default. Precedence: profile-level
      # `storage_backend` -> global `storage_backend` -> ENV `SLACK_STATUS_BACKEND`
      # -> :file. Always returns a Symbol.
      class ResolveBackend
        extend Callable

        ENV_VAR = "SLACK_STATUS_BACKEND".freeze
        DEFAULT = :file

        def initialize(config:, profile:, env: ENV)
          @config = config
          @profile = profile
          @env = env
        end

        def call
          stripped = (profile_value || global_value || env[ENV_VAR]).to_s.strip
          return DEFAULT if stripped.empty?

          stripped.to_sym
        end

        private

        attr_reader :config, :profile, :env

        def profile_value
          config.dig("profiles", profile, "storage_backend")
        end

        def global_value
          config.dig("global", "storage_backend")
        end
      end
    end
  end
end
