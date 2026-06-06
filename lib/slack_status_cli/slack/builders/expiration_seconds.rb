module SlackStatusCli
  module Slack
    module Builders
      # Coerces a status-expiration input into an absolute epoch-seconds Integer
      # (or nil when there is nothing to set). Every recognized input is treated
      # as a duration relative to `now:`. Accepts:
      #   - a plain integer / integer string -> seconds from now (now + value)
      #   - a relative duration like "30m" / "2h" -> now + offset
      #   - nil / blank / unrecognized input -> nil
      class ExpirationSeconds
        extend Callable

        UNIT_SECONDS = { "m" => 60, "h" => 60 * 60 }.freeze
        RELATIVE = /\A(\d+)([mh])\z/.freeze
        BARE_SECONDS = /\A\d+\z/.freeze

        def initialize(value:, now: Time.now)
          @value = value
          @now = now
        end

        def call
          return if blank?

          if (match = RELATIVE.match(token))
            now.to_i + (match[1].to_i * UNIT_SECONDS.fetch(match[2]))
          elsif BARE_SECONDS.match?(token)
            now.to_i + token.to_i
          end
        end

        private

        attr_reader :value, :now

        def token
          @token ||= value.to_s.strip
        end

        def blank?
          value.nil? || token.empty?
        end
      end
    end
  end
end
