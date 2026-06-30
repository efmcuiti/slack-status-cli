module SlackStatusCli
  module Cli
    module Queries
      # Maps a Slack auth.test error code to a user-visible next step shown by
      # `doctor`. Returns nil for codes we have no specific remedy for, so the
      # caller can stay quiet rather than print a generic hint.
      class DoctorHint
        extend Callable

        def initialize(diagnosis:)
          @diagnosis = diagnosis
        end

        def call
          case diagnosis
          when "not_authed", "invalid_auth", "token_revoked"
            "Re-run: ruby slack_status.rb setup --profile <name> --rotate"
          when "missing_scope"
            "Your token is missing `users.profile:write`. Re-run setup and accept the manifest scopes."
          when "account_inactive"
            "The Slack user owning this token is deactivated. Use a different account."
          when "rate_limited"
            "Slack is rate-limiting this token. Retry later."
          end
        end

        private

        attr_reader :diagnosis
      end
    end
  end
end
