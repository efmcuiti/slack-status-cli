module SlackStatusCli
  module Tokens
    module Queries
      # Answers whether a profile has its own explicit, non-empty block under
      # `profiles.<profile>` in the config. Used by ResolveToken to gate the
      # legacy SLACK_SECRET_TOKEN fallback: that fallback only applies to the
      # `default` profile when nothing is explicitly configured, so an empty or
      # absent block must read as "not configured".
      class ProfileExplicitlyConfigured
        extend Callable

        def initialize(config:, profile:)
          @config = config || {}
          @profile = profile
        end

        def call
          block = config.dig("profiles", profile)
          block.is_a?(Hash) && !block.empty?
        end

        private

        attr_reader :config, :profile
      end
    end
  end
end
