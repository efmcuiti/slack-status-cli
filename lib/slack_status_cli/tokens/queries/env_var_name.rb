module SlackStatusCli
  module Tokens
    module Queries
      # Derives the profile-scoped environment variable name a token can be read
      # from, e.g. profile "default" -> "SLACK_STATUS_TOKEN_DEFAULT". The profile
      # is upcased and every non-alphanumeric character is collapsed to a single
      # underscore so names stay shell-safe. Mirrors the Env backend's own key
      # derivation so the precedence walker and the backend agree.
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
