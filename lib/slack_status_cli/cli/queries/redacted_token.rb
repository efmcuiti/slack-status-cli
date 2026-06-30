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
          # `keep >= length` (not just `>`) so a token no longer than the kept
          # prefix is fully redacted rather than printed in the clear.
          return REDACTED if clamped_keep >= token.length

          "#{token[0, clamped_keep]}#{"*" * (token.length - clamped_keep)}"
        end

        private

        attr_reader :token, :keep

        # Tolerate a nil / non-numeric / negative `keep` so a safe-to-print
        # helper never raises mid-log; anything unparseable masks everything.
        def clamped_keep
          [Integer(keep, exception: false) || 0, 0].max
        end
      end
    end
  end
end
