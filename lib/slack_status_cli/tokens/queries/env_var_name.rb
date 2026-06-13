module SlackStatusCli
  module Tokens
    module Queries
      # Derives the profile-scoped environment variable name a token can be read
      # from, e.g. profile "default" -> "SLACK_STATUS_TOKEN_DEFAULT". The profile
      # is upcased and each non-alphanumeric character is replaced with its own
      # underscore (so "my  work" -> "MY__WORK") to keep names shell-safe. Matches
      # the Env backend's default key derivation, which the backend can still
      # override via settings, so the precedence walker and the backend agree.
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
