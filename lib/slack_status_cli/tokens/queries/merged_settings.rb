module SlackStatusCli
  module Tokens
    module Queries
      # Computes the effective settings for a profile by deep-merging the
      # `global:` defaults under the `profiles.<profile>` overrides (profile wins
      # on collision). Modeled after `git config --global` inheritance. Hashes
      # merge key-wise; every other value (including arrays) is overwritten
      # wholesale by the profile side.
      class MergedSettings
        extend Callable

        def initialize(config:, profile:)
          @config = config || {}
          @profile = profile
        end

        def call
          global = config["global"] || {}
          profile_settings = config.dig("profiles", profile) || {}
          deep_merge(global, profile_settings)
        end

        private

        attr_reader :config, :profile

        def deep_merge(left, right)
          return right.dup if left.nil? || left.empty?
          return left.dup if right.nil? || right.empty?

          left.merge(right) do |_key, left_value, right_value|
            if left_value.is_a?(Hash) && right_value.is_a?(Hash)
              deep_merge(left_value, right_value)
            else
              right_value
            end
          end
        end
      end
    end
  end
end
