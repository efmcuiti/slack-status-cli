module SlackStatusCli
  module Cli
    module Queries
      # Builds the Slack custom-emoji admin URL from a workspace base URL (the
      # `url` returned by auth.test, e.g. "https://phoenix-hq.slack.com/").
      # Pure: the auth.test lookup that supplies the base URL lives in the
      # orchestrator. Returns nil when given a blank URL so callers can skip the
      # browser step.
      class AdminUrl
        extend Callable

        ADMIN_PATH = "/customize/emoji".freeze

        def initialize(workspace_url:)
          @workspace_url = workspace_url
        end

        def call
          base = workspace_url.to_s.sub(/\/+\z/, "")
          return nil if base.empty?

          "#{base}#{ADMIN_PATH}"
        end

        private

        attr_reader :workspace_url
      end
    end
  end
end
