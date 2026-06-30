module SlackStatusCli
  module Cli
    module Queries
      # Reads a nested value out of a Hash using a dotted key path
      # ("global.defaults.profile"). Returns nil the moment any intermediate
      # level is missing or is not itself a Hash.
      class DottedGet
        extend Callable

        def initialize(hash:, key:)
          @hash = hash
          @key = key
        end

        def call
          key.to_s.split(".").reduce(hash) do |memo, part|
            break nil unless memo.is_a?(::Hash)

            memo[part]
          end
        end

        private

        attr_reader :hash, :key
      end
    end
  end
end
