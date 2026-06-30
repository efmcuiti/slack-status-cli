module SlackStatusCli
  module Cli
    module Commands
      # The mutating sibling of Queries::DottedGet: sets a nested value via a
      # dotted key path, creating intermediate hashes (and replacing any non-hash
      # value blocking the path) as it walks. Mutates and returns the same hash.
      class DottedSet
        extend Callable

        def initialize(hash:, key:, value:)
          @hash = hash
          @key = key
          @value = value
        end

        def call
          parts = key.to_s.split(".")
          leaf = parts.pop
          cursor = parts.reduce(hash) do |memo, part|
            memo[part] = {} unless memo[part].is_a?(::Hash)
            memo[part]
          end
          cursor[leaf] = value
          hash
        end

        private

        attr_reader :hash, :key, :value
      end
    end
  end
end
