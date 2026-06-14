module SlackStatusCli
  module Tokens
    module Queries
      # The token precedence walker. Returns the first non-empty token found,
      # walking: cli_token -> SLACK_STATUS_TOKEN_<PROFILE> env -> the
      # config-driven backend -> the legacy SLACK_SECRET_TOKEN fallback. Raises
      # NotFoundError (carrying NotFoundMessage) when nothing resolves.
      #
      # The legacy SLACK_SECRET_TOKEN fallback is intentionally limited to the
      # `default` profile when no profile block is configured and no backend
      # resolved, so a token belonging to one workspace can never be silently
      # injected for `--profile something-else`.
      class ResolveToken
        extend Callable

        DEFAULT_PROFILE = "default".freeze
        LEGACY_ENV_VAR = "SLACK_SECRET_TOKEN".freeze

        BACKEND_CLASSES = {
          "dashlane" => Backends::Dashlane,
          "keychain" => Backends::Keychain,
          "file" => Backends::File,
          "env" => Backends::Env
        }.freeze

        def initialize(profile:, cli_token: nil, config_path: nil, verbose: false)
          @profile = profile.to_s
          @cli_token = cli_token
          @config_path = config_path || Constants::DEFAULT_CONFIG_PATH
          @verbose = verbose
        end

        def call
          return success(cli_token, "cli:--token") if non_empty?(cli_token)

          env_key = EnvVarName.call(profile: profile)
          return success(ENV[env_key], "env:#{env_key}") if non_empty?(ENV[env_key])

          config = LoadConfig.call(path: config_path)
          profile_configured = ProfileExplicitlyConfigured.call(config: config, profile: profile)

          backend = build_backend(config)
          if backend
            token = backend.read
            return success(token, backend.source_label) if non_empty?(token)
          end

          if legacy_eligible?(profile_configured, backend) && non_empty?(ENV[LEGACY_ENV_VAR])
            return success(ENV[LEGACY_ENV_VAR], "env:#{LEGACY_ENV_VAR}")
          end

          raise Errors::NotFoundError, NotFoundMessage.call(
            profile: profile,
            config_path: config_path,
            tried_backend: backend,
            profile_configured: profile_configured,
            legacy_env_present: non_empty?(ENV[LEGACY_ENV_VAR])
          )
        end

        private

        attr_reader :profile, :cli_token, :config_path, :verbose

        def build_backend(config)
          settings = MergedSettings.call(config: config, profile: profile)
          backend_name = settings["storage_backend"] || infer_default_backend(settings)
          return nil unless backend_name

          klass = BACKEND_CLASSES[backend_name.to_s]
          unless klass
            raise Errors::ConfigError,
                  "Unknown storage_backend '#{backend_name}' (supported: #{BACKEND_CLASSES.keys.join(', ')})"
          end

          klass.new(profile: profile, settings: settings)
        end

        def infer_default_backend(settings)
          return nil if settings.nil? || settings.empty?

          "dashlane" if settings["token_ref"]
        end

        def legacy_eligible?(profile_configured, backend)
          profile == DEFAULT_PROFILE && !profile_configured && backend.nil?
        end

        def success(token, source)
          log_source(source)
          { token: token.to_s.strip, source: source, profile: profile }
        end

        def log_source(source)
          return unless verbose

          warn "[slack-status-cli] token resolved from #{source} (profile=#{profile})"
        end

        def non_empty?(value)
          !value.nil? && !value.to_s.strip.empty?
        end
      end
    end
  end
end
