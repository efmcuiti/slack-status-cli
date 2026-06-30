module SlackStatusCli
  module Cli
    module Queries
      # Renders a token safe to print: keeps the first `keep` characters and
      # replaces the rest with a length-preserving mask. Returns "" for a nil
      # token and "<redacted>" for a token too short to keep a prefix without
      # exposing the whole thing.
      class RedactedToken
        extend Callable

        REDACTED = "<redacted>".freeze

        def initialize(token:, keep: 4)
          @token = token
          @keep = keep
        end

        def call
          return "" if token.nil?
          return REDACTED if token.length < keep

          "#{token[0, keep]}#{"*" * (token.length - keep)}"
        end

        private

        attr_reader :token, :keep
      end
    end
  end
end
