module SlackStatusCli
  module Tokens
    module Queries
      # Derives the profile-scoped environment variable name a token can be read
      # from, e.g. profile "default" -> "SLACK_STATUS_TOKEN_DEFAULT". The profile
      # is upcased and any character outside [A-Z0-9_] is replaced with its own
      # underscore (so "my  work" -> "MY__WORK"); existing underscores pass
      # through unchanged, keeping names shell-safe. This is the key the
      # precedence walker checks at the ENV step; it matches the Env
      # backend's *default* key derivation, but the two diverge when the backend
      # reads/writes a custom key via `backend_options.env.var`.
      class EnvVarName
        extend Callable

        def initialize(profile:)
          @profile = profile
        end

        def call
          "SLACK_STATUS_TOKEN_#{sanitized_profile}"
        end

        private

        attr_reader :profile

        def sanitized_profile
          profile.to_s.upcase.gsub(/[^A-Z0-9_]/, "_")
        end
      end
    end
  end
end
